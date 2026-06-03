const asyncHandler = require('express-async-handler');
const { Parser } = require('json2csv');
const prisma = require('../utils/prisma');
const { sendParkingNotification } = require('../utils/firebase');
const { uploadFile } = require('../utils/r2FileHandler');
const { parsePagination, buildPaginationMeta } = require('../utils/paginationHelper');
const FormData = require('form-data');
const axios = require('axios');
const CircuitBreaker = require('../utils/CircuitBreaker');

const PLATE_SERVICE_URL = process.env.PLATE_API_URL || 'http://localhost:5001';
const PLATE_SERVICE_TIMEOUT = parseInt(process.env.PLATE_SERVICE_TIMEOUT || '10000');

// Initialize Circuit Breaker for Plate Recognition API
const plateApiBreaker = new CircuitBreaker("PlateAPI", {
    failureThreshold: parseInt(process.env.PLATE_CB_FAILURE_THRESHOLD || '5'),
    recoveryTimeout: parseInt(process.env.PLATE_CB_RECOVERY_TIMEOUT || '30000')
});

// Get histori parkir untuk user (berdasarkan kendaraan yang dimiliki)
exports.getHistoriParkir = asyncHandler(async (req, res) => {
    const userId = req.user.id_user;
    const { page, limit, skip } = parsePagination(req.query);

    // Get all user's kendaraan IDs first
    const userKendaraan = await prisma.kendaraan.findMany({
        where: {
            id_user: userId,
            deletedAt: null,
            statusVerif: true // Only verified kendaraan
        },
        select: { id_kendaraan: true }
    });

    const kendaraanIds = userKendaraan.map(k => k.id_kendaraan);

    if (kendaraanIds.length === 0) {
        return res.status(200).json({
            status: "success",
            message: "No parking history found",
            data: [],
            pagination: buildPaginationMeta(0, page, limit)
        });
    }

    // Get total count for pagination
    const totalCount = await prisma.logParkir.count({
        where: {
            id_kendaraan: { in: kendaraanIds }
        }
    });

    // Get parking logs for user's kendaraan
    const logParkir = await prisma.logParkir.findMany({
        where: {
            id_kendaraan: { in: kendaraanIds }
        },
        include: {
            kendaraan: {
                select: {
                    id_kendaraan: true,
                    plat_nomor: true,
                    nama_kendaraan: true
                }
            },
            parkiran: {
                select: {
                    id_parkiran: true,
                    nama_parkiran: true
                }
            }
        },
        orderBy: { timestamp: 'desc' },
        skip: skip,
        take: limit
    });

    res.status(200).json({
        status: "success",
        message: "Parking history retrieved successfully",
        data: logParkir,
        pagination: buildPaginationMeta(totalCount, page, limit)
    });
});

// Get semua parkiran dengan live kapasitas
exports.getAllParkiran = asyncHandler(async (req, res) => {
    const parkiran = await prisma.$queryRaw`
        SELECT 
            id_parkiran,
            nama_parkiran,
            kapasitas,
            live_kapasitas,
            (kapasitas - live_kapasitas) as slot_tersedia,
            koordinat[0] as longitude,
            koordinat[1] as latitude,
            "createdAt",
            "updatedAt"
        FROM parkiran
        WHERE "deletedAt" IS NULL
        ORDER BY nama_parkiran ASC
    `;

    res.status(200).json({
        status: "success",
        message: "All parkiran retrieved successfully",
        data: parkiran
    });
});

// Get analitik parkiran (sama seperti getAllParkiran tapi dengan format berbeda)
exports.getAnalitikParkiran = asyncHandler(async (req, res) => {
    const parkiran = await prisma.$queryRaw`
        SELECT 
            id_parkiran,
            nama_parkiran,
            kapasitas,
            live_kapasitas,
            (kapasitas - live_kapasitas) as slot_tersedia,
            ROUND((live_kapasitas::numeric / NULLIF(kapasitas, 0)) * 100, 2) as persentase_terisi
        FROM parkiran
        WHERE "deletedAt" IS NULL
        ORDER BY nama_parkiran ASC
    `;

    // Calculate total stats
    const totalKapasitas = parkiran.reduce((sum, p) => sum + Number(p.kapasitas), 0);
    const totalTerisi = parkiran.reduce((sum, p) => sum + Number(p.live_kapasitas), 0);
    const totalTersedia = totalKapasitas - totalTerisi;

    res.status(200).json({
        status: "success",
        message: "Parking analytics retrieved successfully",
        data: {
            parkiran: parkiran,
            summary: {
                total_kapasitas: totalKapasitas,
                total_terisi: totalTerisi,
                total_tersedia: totalTersedia,
                persentase_terisi: totalKapasitas > 0 ?
                    Math.round((totalTerisi / totalKapasitas) * 100 * 100) / 100 : 0
            }
        }
    });
});

// Create lokasi parkiran baru (Admin only)
exports.createParkiran = asyncHandler(async (req, res) => {
    const { nama_parkiran, kapasitas, latitude, longitude } = req.body;

    // Validasi input
    if (!nama_parkiran || nama_parkiran.trim() === '') {
        return res.status(400).json({
            status: "error",
            message: "Nama parkiran is required"
        });
    }

    if (kapasitas === undefined || isNaN(Number(kapasitas)) || parseInt(kapasitas) <= 0) {
        return res.status(400).json({
            status: "error",
            message: "Kapasitas must be a positive number"
        });
    }

    if (latitude === undefined || longitude === undefined) {
        return res.status(400).json({
            status: "error",
            message: "Latitude and longitude are required"
        });
    }

    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);
    if (isNaN(lat) || lat < -90 || lat > 90) {
        return res.status(400).json({
            status: "error",
            message: "Latitude must be a valid number between -90 and 90"
        });
    }
    if (isNaN(lng) || lng < -180 || lng > 180) {
        return res.status(400).json({
            status: "error",
            message: "Longitude must be a valid number between -180 and 180"
        });
    }

    // Cek apakah nama sudah ada (menggunakan Prisma Client)
    const existing = await prisma.parkiran.findFirst({
        where: {
            nama_parkiran: nama_parkiran.trim(),
            deletedAt: null
        }
    });

    if (existing) {
        return res.status(409).json({
            status: "error",
            message: "Nama parkiran already exists"
        });
    }

    // Insert dengan raw query karena field koordinat adalah tipe Point
    await prisma.$executeRaw`
        INSERT INTO parkiran (nama_parkiran, kapasitas, live_kapasitas, koordinat, "createdAt", "updatedAt")
        VALUES (
            ${nama_parkiran.trim()}, 
            ${parseInt(kapasitas)}, 
            0, 
            point(${parseFloat(longitude)}, ${parseFloat(latitude)}),
            NOW(),
            NOW()
        )
    `;

    // Ambil data yang baru dibuat
    const newParkiran = await prisma.$queryRaw`
        SELECT 
            id_parkiran,
            nama_parkiran,
            kapasitas,
            live_kapasitas,
            "createdAt",
            "updatedAt"
        FROM parkiran
        WHERE nama_parkiran = ${nama_parkiran.trim()}
        AND "deletedAt" IS NULL
        ORDER BY "createdAt" DESC
        LIMIT 1
    `;

    res.status(201).json({
        status: "success",
        message: "Lokasi parkiran created successfully",
        data: newParkiran[0]
    });
});

// Update lokasi parkiran (Admin only)
exports.updateParkiran = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { nama_parkiran, kapasitas, latitude, longitude } = req.body;

    if (isNaN(parseInt(id))) {
        return res.status(400).json({
            status: "error",
            message: "Invalid ID format"
        });
    }

    // Cek apakah parkiran ada (menggunakan Prisma Client)
    const existing = await prisma.parkiran.findFirst({
        where: {
            id_parkiran: parseInt(id),
            deletedAt: null
        }
    });

    if (!existing) {
        return res.status(404).json({
            status: "error",
            message: "Parkiran not found"
        });
    }

    // Jika nama berubah, cek unique (menggunakan Prisma Client)
    if (nama_parkiran) {
        const nameCheck = await prisma.parkiran.findFirst({
            where: {
                nama_parkiran: nama_parkiran.trim(),
                id_parkiran: { not: parseInt(id) },
                deletedAt: null
            }
        });

        if (nameCheck) {
            return res.status(409).json({
                status: "error",
                message: "Nama parkiran already exists"
            });
        }
    }

    if (kapasitas !== undefined) {
        if (isNaN(Number(kapasitas)) || parseInt(kapasitas) <= 0) {
            return res.status(400).json({
                status: "error",
                message: "Kapasitas must be a positive number"
            });
        }
    }

    if (latitude !== undefined || longitude !== undefined) {
        if (latitude === undefined || longitude === undefined) {
            return res.status(400).json({
                status: "error",
                message: "Latitude and longitude are required"
            });
        }
        const lat = parseFloat(latitude);
        const lng = parseFloat(longitude);
        if (isNaN(lat) || lat < -90 || lat > 90) {
            return res.status(400).json({
                status: "error",
                message: "Latitude must be a valid number between -90 and 90"
            });
        }
        if (isNaN(lng) || lng < -180 || lng > 180) {
            return res.status(400).json({
                status: "error",
                message: "Longitude must be a valid number between -180 and 180"
            });
        }
    }

    // Update data standard dengan Prisma update (safe & typed)
    const dataToUpdate = {};
    if (nama_parkiran) dataToUpdate.nama_parkiran = nama_parkiran.trim();
    if (kapasitas !== undefined) dataToUpdate.kapasitas = parseInt(kapasitas);

    if (Object.keys(dataToUpdate).length > 0) {
        await prisma.parkiran.update({
            where: { id_parkiran: parseInt(id) },
            data: dataToUpdate
        });
    }

    // Update koordinat secara aman dengan parameterized $executeRaw jika disediakan
    if (latitude !== undefined && longitude !== undefined) {
        await prisma.$executeRaw`
            UPDATE parkiran 
            SET koordinat = point(${parseFloat(longitude)}, ${parseFloat(latitude)}),
                "updatedAt" = NOW()
            WHERE id_parkiran = ${parseInt(id)}
        `;
    } else {
        await prisma.$executeRaw`
            UPDATE parkiran 
            SET "updatedAt" = NOW()
            WHERE id_parkiran = ${parseInt(id)}
        `;
    }

    // Ambil data yang diupdate
    const updatedParkiran = await prisma.$queryRaw`
        SELECT 
            id_parkiran,
            nama_parkiran,
            kapasitas,
            live_kapasitas,
            "createdAt",
            "updatedAt"
        FROM parkiran
        WHERE id_parkiran = ${parseInt(id)}
    `;

    res.status(200).json({
        status: "success",
        message: "Lokasi parkiran updated successfully",
        data: updatedParkiran[0]
    });
});

// Delete lokasi parkiran (soft delete, Admin only)
exports.deleteParkiran = asyncHandler(async (req, res) => {
    const { id } = req.params;

    // Cek apakah parkiran ada
    const existing = await prisma.$queryRaw`
        SELECT id_parkiran, nama_parkiran FROM parkiran 
        WHERE id_parkiran = ${parseInt(id)} 
        AND "deletedAt" IS NULL
    `;

    if (existing.length === 0) {
        return res.status(404).json({
            status: "error",
            message: "Parkiran not found"
        });
    }

    // Soft delete
    await prisma.$executeRaw`
        UPDATE parkiran 
        SET "deletedAt" = NOW(), "updatedAt" = NOW()
        WHERE id_parkiran = ${parseInt(id)}
    `;

    res.status(200).json({
        status: "success",
        message: `Lokasi parkiran "${existing[0].nama_parkiran}" deleted successfully`
    });
});

// Process parking entry/exit from edge device
// POST /api/parkir/edge-entry
// Supports multipart/form-data for image upload
exports.processEdgeEntry = asyncHandler(async (req, res) => {
    const { plate_text, confidence, parkiran_id, gate_type, face_detected } = req.body;

    // Handle files from multer.fields() - req.files is an object with field names as keys
    const plateFile = req.files?.image?.[0];
    const faceFile = req.files?.face_image?.[0];
    const isFaceDetected = face_detected === 'true';

    // 1. Validate edge device secret
    const edgeSecret = req.headers['x-edge-secret'];
    if (edgeSecret !== process.env.EDGE_DEVICE_SECRET) {
        return res.status(401).json({
            status: "error",
            message: "Unauthorized edge device",
            data: { gate_action: "DENY" }
        });
    }

    // 2. OCR Fallback: If plate_text is missing but we have a plate image, call AI Service
    let recognizedPlate = plate_text;
    let ocrConfidence = confidence;

    if (!recognizedPlate && plateFile) {
        try {
            const form = new FormData();
            form.append('image', plateFile.buffer, {
                filename: plateFile.originalname || 'plate.jpg',
                contentType: plateFile.mimetype || 'image/jpeg'
            });

            const apiHeaders = {
                ...form.getHeaders(),
                'X-API-Key': process.env.PLATE_API_KEY || ''
            };
            if (req.headers['x-test-mode']) {
                apiHeaders['X-Test-Mode'] = req.headers['x-test-mode'];
            }

            const response = await plateApiBreaker.fire(async () => {
                return await axios.post(`${PLATE_SERVICE_URL}/api/recognize-plate`, form, {
                    headers: apiHeaders,
                    timeout: PLATE_SERVICE_TIMEOUT
                });
            });

            if (response.data && response.data.success) {
                recognizedPlate = response.data.plate_text;
                ocrConfidence = response.data.confidence;
            } else {
                recognizedPlate = 'UNKNOWN';
                ocrConfidence = 0.0;
            }
        } catch (error) {
            console.error('Failed to recognize plate via AI service:', error.message);
            recognizedPlate = 'UNKNOWN';
            ocrConfidence = 0.0;
        }
    }

    // 3. Validate required fields
    if (!recognizedPlate || !parkiran_id || !gate_type) {
        return res.status(400).json({
            status: "error",
            message: "Missing required fields: plate_text, parkiran_id, gate_type",
            data: { gate_action: "DENY" }
        });
    }

    // Normalize plate text (remove spaces, uppercase)
    const normalizedPlate = recognizedPlate.toUpperCase().replace(/\s/g, '');

    // 4. Find registered vehicle by plate number
    const kendaraan = await prisma.kendaraan.findFirst({
        where: {
            plat_nomor: normalizedPlate,
            statusVerif: true,
            deletedAt: null
        },
        include: { user: { select: { id_user: true, nama: true } } }
    });

    if (!kendaraan) {
        return res.status(404).json({
            status: "error",
            message: `Kendaraan ${recognizedPlate} tidak terdaftar atau belum terverifikasi`,
            data: { gate_action: "DENY" }
        });
    }

    // 5. Check parkiran exists and has capacity
    const parkiran = await prisma.$queryRaw`
        SELECT id_parkiran, nama_parkiran, kapasitas, live_kapasitas
        FROM parkiran WHERE id_parkiran = ${parseInt(parkiran_id)} AND "deletedAt" IS NULL
    `;

    if (parkiran.length === 0) {
        return res.status(404).json({
            status: "error",
            message: "Lokasi parkiran tidak ditemukan",
            data: { gate_action: "DENY" }
        });
    }

    const parkiranData = parkiran[0];

    // Async image upload handling for plate image
    const processPlateImageUpload = async (logId) => {
        if (plateFile) {
            try {
                const uploadResult = await uploadFile(
                    plateFile.buffer,
                    plateFile.originalname,
                    plateFile.mimetype,
                    'parkir_logs'
                );

                // Update log with image URL
                await prisma.logParkir.update({
                    where: { id_log_parkir: logId },
                    data: { image_url: uploadResult.fileUrl }
                });
                console.log(`Plate image uploaded for log ${logId}: ${uploadResult.fileUrl}`);

                // Active learning trigger for low-confidence OCR
                if (ocrConfidence < 0.75 || recognizedPlate === 'UNKNOWN') {
                    console.log("[Active Learning] Low-confidence OCR recorded. Queued for model retraining at R2: " + uploadResult.fileUrl);
                }
            } catch (error) {
                console.error('Failed to upload plate image:', error);
            }
        }
    };

    // Async face image upload handling
    const processFaceImageUpload = async (logId) => {
        if (faceFile) {
            try {
                const uploadResult = await uploadFile(
                    faceFile.buffer,
                    faceFile.originalname,
                    faceFile.mimetype,
                    'face_captures'  // Separate folder for face images
                );

                // Update log with face image URL and face_detected flag
                await prisma.logParkir.update({
                    where: { id_log_parkir: logId },
                    data: {
                        face_image_url: uploadResult.fileUrl,
                        face_detected: isFaceDetected
                    }
                });
                console.log(`Face image uploaded for log ${logId}: ${uploadResult.fileUrl} (detected: ${isFaceDetected})`);
            } catch (error) {
                console.error('Failed to upload face image:', error);
            }
        }
    };

    // 6. Process based on gate type
    if (gate_type === 'MASUK') {
        // Check capacity
        if (Number(parkiranData.live_kapasitas) >= Number(parkiranData.kapasitas)) {
            return res.status(400).json({
                success: false,
                gate_action: "DENY",
                message: `Parkiran ${parkiranData.nama_parkiran} penuh`
            });
        }

        // Check if vehicle already inside
        const lastLog = await prisma.logParkir.findFirst({
            where: { id_kendaraan: kendaraan.id_kendaraan },
            orderBy: { timestamp: 'desc' }
        });

        if (lastLog && lastLog.type === 'MASUK') {
            return res.status(400).json({
                status: "error",
                message: `Kendaraan ${recognizedPlate} sudah berada di dalam parkiran`,
                data: { gate_action: "DENY" }
            });
        }

        // Atomic capacity check + increment (prevents race condition)
        const parsedParkiranId = parseInt(parkiran_id);
        const updateResult = await prisma.$executeRaw`
            UPDATE parkiran
            SET live_kapasitas = live_kapasitas + 1, "updatedAt" = NOW()
            WHERE id_parkiran = ${parsedParkiranId}
            AND live_kapasitas < kapasitas
            AND "deletedAt" IS NULL
        `;

        if (updateResult === 0) {
            return res.status(400).json({
                status: "error",
                message: `Parkiran ${parkiranData.nama_parkiran} penuh`,
                data: { gate_action: "DENY" }
            });
        }

        const newLog = await prisma.logParkir.create({
            data: {
                id_kendaraan: kendaraan.id_kendaraan,
                id_parkiran: parsedParkiranId,
                id_user: kendaraan.user?.id_user,
                type: 'MASUK',
                confidence: ocrConfidence ? parseFloat(ocrConfidence) : null,
                image_url: null // Will be updated asynchronously
            }
        });

        // Trigger async uploads without awaiting (plate + face images)
        processPlateImageUpload(newLog.id_log_parkir);
        processFaceImageUpload(newLog.id_log_parkir);

        const slotTersisa = Number(parkiranData.kapasitas) - Number(parkiranData.live_kapasitas) - 1;

        // Send push notification
        if (kendaraan.user?.id_user) {
            sendParkingNotification(
                kendaraan.user.id_user,
                'MASUK',
                { plat_nomor: normalizedPlate, nama_kendaraan: kendaraan.nama_kendaraan },
                parkiranData.nama_parkiran
            ).catch(err => console.error('Notification error:', err));
        }

        // Emit WebSocket update
        const io = req.app.get('io');
        if (io) {
            io.emit('parking_update', {
                id_parkiran: parsedParkiranId,
                live_kapasitas: parkiranData.live_kapasitas + 1,
                kapasitas: parkiranData.kapasitas
            });
        }

        return res.status(200).json({
            status: "success",
            message: `Selamat datang ${kendaraan.user?.nama || 'User'}! Kendaraan ${recognizedPlate} masuk.`,
            data: {
                gate_action: "OPEN",
                plate_text: normalizedPlate,
                owner: kendaraan.user?.nama,
                parkiran: parkiranData.nama_parkiran,
                slot_tersisa: slotTersisa,
                ocr_confidence: ocrConfidence
            }
        });

    } else if (gate_type === 'KELUAR') {
        // Check if vehicle is inside
        const lastLog = await prisma.logParkir.findFirst({
            where: { id_kendaraan: kendaraan.id_kendaraan },
            orderBy: { timestamp: 'desc' }
        });

        if (!lastLog || lastLog.type === 'KELUAR') {
            return res.status(400).json({
                status: "error",
                message: `Kendaraan ${recognizedPlate} tidak tercatat masuk di parkiran ini`,
                data: { gate_action: "DENY" }
            });
        }

        // Create exit log and decrement capacity
        const [newLog] = await prisma.$transaction([
            prisma.logParkir.create({
                data: {
                    id_kendaraan: kendaraan.id_kendaraan,
                    id_parkiran: parseInt(parkiran_id),
                    id_user: kendaraan.user?.id_user,
                    type: 'KELUAR',
                    confidence: ocrConfidence ? parseFloat(ocrConfidence) : null,
                    image_url: null // Will be updated asynchronously
                }
            }),
            prisma.$executeRaw`
                UPDATE parkiran SET live_kapasitas = GREATEST(0, live_kapasitas - 1), "updatedAt" = NOW()
                WHERE id_parkiran = ${parseInt(parkiran_id)}
            `
        ]);

        // Trigger async uploads without awaiting (plate + face images)
        processPlateImageUpload(newLog.id_log_parkir);
        processFaceImageUpload(newLog.id_log_parkir);

        // Send push notification
        if (kendaraan.user?.id_user) {
            sendParkingNotification(
                kendaraan.user.id_user,
                'KELUAR',
                { plat_nomor: normalizedPlate, nama_kendaraan: kendaraan.nama_kendaraan },
                parkiranData.nama_parkiran
            ).catch(err => console.error('Notification error:', err));
        }

        // Emit WebSocket update
        const io = req.app.get('io');
        if (io) {
            const newLiveKapasitas = Math.max(0, parkiranData.live_kapasitas - 1);
            io.emit('parking_update', {
                id_parkiran: parseInt(parkiran_id),
                live_kapasitas: newLiveKapasitas,
                kapasitas: parkiranData.kapasitas
            });
        }

        return res.status(200).json({
            status: "success",
            message: `Sampai jumpa ${kendaraan.user?.nama || 'User'}! Kendaraan ${recognizedPlate} keluar.`,
            data: {
                gate_action: "OPEN",
                plate_text: normalizedPlate,
                owner: kendaraan.user?.nama,
                parkiran: parkiranData.nama_parkiran,
                ocr_confidence: ocrConfidence
            }
        });
    }

    return res.status(400).json({
        status: "error",
        message: "Invalid gate_type. Use 'MASUK' or 'KELUAR'",
        data: { gate_action: "DENY" }
    });
});

// Reconcile live_kapasitas berdasarkan log aktual (Admin only)
exports.reconcileKapasitas = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const parsedId = parseInt(id);

    // Hitung kendaraan yang masih di dalam berdasarkan log
    // (kendaraan yang terakhir MASUK dan belum KELUAR di parkiran ini)
    const result = await prisma.$queryRaw`
        SELECT COUNT(DISTINCT lp.id_kendaraan) as actual_count
        FROM log_parkir lp
        INNER JOIN (
            SELECT id_kendaraan, MAX(timestamp) as last_ts
            FROM log_parkir
            WHERE id_parkiran = ${parsedId}
            GROUP BY id_kendaraan
        ) latest ON lp.id_kendaraan = latest.id_kendaraan AND lp.timestamp = latest.last_ts
        WHERE lp.id_parkiran = ${parsedId} AND lp.type = 'MASUK'
    `;

    const actualCount = Number(result[0]?.actual_count || 0);

    await prisma.$executeRaw`
        UPDATE parkiran SET live_kapasitas = ${actualCount}, "updatedAt" = NOW()
        WHERE id_parkiran = ${parsedId}
    `;

    // Emit WebSocket update
    const io = req.app.get('io');
    if (io) {
        // Fetch kapasitas to send complete data
        const parkiran = await prisma.parkiran.findUnique({
            where: { id_parkiran: parsedId },
            select: { kapasitas: true }
        });
        if (parkiran) {
            io.emit('parking_update', {
                id_parkiran: parsedId,
                live_kapasitas: actualCount,
                kapasitas: parkiran.kapasitas
            });
        }
    }

    res.status(200).json({
        status: "success",
        message: `Kapasitas direconcile: ${actualCount} kendaraan di dalam`,
        data: { live_kapasitas: actualCount }
    });
});

// Export log parkir sebagai CSV (Admin only)
// GET /api/v1/parkir/export?parkiran_id=&from=&to=
exports.exportParkirLogs = asyncHandler(async (req, res) => {
    const { parkiran_id, from, to } = req.query;

    const where = {};
    if (parkiran_id) where.id_parkiran = parseInt(parkiran_id);
    if (from || to) {
        where.timestamp = {};
        if (from) where.timestamp.gte = new Date(from);
        if (to)   where.timestamp.lte = new Date(to);
    }

    const logs = await prisma.logParkir.findMany({
        where,
        include: {
            kendaraan: { select: { plat_nomor: true, nama_kendaraan: true } },
            user:      { select: { nama: true, username: true } },
            parkiran:  { select: { nama_parkiran: true } }
        },
        orderBy: { timestamp: 'desc' }
    });

    if (logs.length === 0) {
        return res.status(404).json({
            status: "error",
            message: "Tidak ada data log parkir untuk filter yang diberikan"
        });
    }

    const fields = [
        { label: 'ID Log',        value: 'id_log_parkir' },
        { label: 'Timestamp',     value: row => new Date(row.timestamp).toISOString() },
        { label: 'Tipe',          value: 'type' },
        { label: 'Plat Nomor',    value: row => row.kendaraan?.plat_nomor  ?? '-' },
        { label: 'Kendaraan',     value: row => row.kendaraan?.nama_kendaraan ?? '-' },
        { label: 'User',          value: row => row.user?.nama ?? '-' },
        { label: 'Username',      value: row => row.user?.username ?? '-' },
        { label: 'Parkiran',      value: row => row.parkiran?.nama_parkiran ?? '-' },
        { label: 'Confidence',    value: row => row.confidence ?? '' },
        { label: 'Image URL',     value: row => row.image_url ?? '' },
        { label: 'Face URL',      value: row => row.face_image_url ?? '' },
    ];

    const parser = new Parser({ fields });
    const csv = parser.parse(logs);

    const filename = `log_parkir_${Date.now()}.csv`;
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.status(200).send('\uFEFF' + csv); // BOM for Excel UTF-8 compatibility
});

// Manual gate override (Admin only)
// POST /api/v1/parkir/:id/override
exports.manualOverride = asyncHandler(async (req, res) => {
    const { id } = req.params;             // parkiran_id
    const { plat_nomor, gate_type } = req.body;
    const adminId = req.user.id_user;

    if (!plat_nomor || !gate_type) {
        return res.status(400).json({
            status: "error",
            message: "plat_nomor dan gate_type (MASUK/KELUAR) wajib diisi"
        });
    }

    const normalizedPlate = plat_nomor.toUpperCase().replace(/\s/g, '');
    const parsedParkiranId = parseInt(id);

    // Cek parkiran
    const parkiranRows = await prisma.$queryRaw`
        SELECT id_parkiran, nama_parkiran, kapasitas, live_kapasitas
        FROM parkiran WHERE id_parkiran = ${parsedParkiranId} AND "deletedAt" IS NULL
    `;
    if (parkiranRows.length === 0) {
        return res.status(404).json({ status: "error", message: "Parkiran tidak ditemukan" });
    }
    const parkiranData = parkiranRows[0];

    // Cari kendaraan (boleh belum terverifikasi untuk override manual)
    const kendaraan = await prisma.kendaraan.findFirst({
        where: { plat_nomor: normalizedPlate, deletedAt: null },
        include: { user: { select: { id_user: true, nama: true } } }
    });

    if (!kendaraan) {
        return res.status(404).json({
            status: "error",
            message: `Kendaraan dengan plat ${normalizedPlate} tidak ditemukan`
        });
    }

    if (gate_type === 'MASUK') {
        const updateResult = await prisma.$executeRaw`
            UPDATE parkiran
            SET live_kapasitas = live_kapasitas + 1, "updatedAt" = NOW()
            WHERE id_parkiran = ${parsedParkiranId}
            AND live_kapasitas < kapasitas AND "deletedAt" IS NULL
        `;
        if (updateResult === 0) {
            return res.status(400).json({
                status: "error",
                message: `Parkiran ${parkiranData.nama_parkiran} penuh`
            });
        }
    } else if (gate_type === 'KELUAR') {
        await prisma.$executeRaw`
            UPDATE parkiran SET live_kapasitas = GREATEST(0, live_kapasitas - 1), "updatedAt" = NOW()
            WHERE id_parkiran = ${parsedParkiranId}
        `;
    } else {
        return res.status(400).json({
            status: "error",
            message: "gate_type harus 'MASUK' atau 'KELUAR'"
        });
    }

    const newLog = await prisma.logParkir.create({
        data: {
            id_kendaraan: kendaraan.id_kendaraan,
            id_parkiran:  parsedParkiranId,
            id_user:      kendaraan.user?.id_user,
            type:         gate_type,
            confidence:   null,
            image_url:    null
        }
    });

    // Emit WebSocket update
    const io = req.app.get('io');
    if (io) {
        const updatedRows = await prisma.$queryRaw`
            SELECT live_kapasitas FROM parkiran WHERE id_parkiran = ${parsedParkiranId}
        `;
        io.emit('parking_update', {
            id_parkiran:   parsedParkiranId,
            live_kapasitas: Number(updatedRows[0]?.live_kapasitas ?? 0),
            kapasitas:     Number(parkiranData.kapasitas)
        });
    }

    return res.status(200).json({
        status: "success",
        message: `Override berhasil: ${normalizedPlate} dicatat ${gate_type} oleh admin`,
        data: {
            id_log_parkir: newLog.id_log_parkir,
            plat_nomor:    normalizedPlate,
            gate_type,
            parkiran:      parkiranData.nama_parkiran,
            override_by:   adminId
        }
    });
});
