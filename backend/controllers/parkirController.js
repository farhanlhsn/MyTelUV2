const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma');
const { sendParkingNotification } = require('../utils/firebase');
const { uploadFile } = require('../utils/r2FileHandler');

// Get histori parkir untuk user (berdasarkan kendaraan yang dimiliki)
exports.getHistoriParkir = asyncHandler(async (req, res) => {
    const userId = req.user.id_user;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

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
            meta: {
                page,
                limit,
                total: 0,
                total_pages: 0
            }
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
        meta: {
            page,
            limit,
            total: totalCount,
            total_pages: Math.ceil(totalCount / limit)
        }
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

    if (!kapasitas || kapasitas <= 0) {
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

    // Cek apakah nama sudah ada
    const existing = await prisma.$queryRaw`
        SELECT id_parkiran FROM parkiran 
        WHERE nama_parkiran = ${nama_parkiran.trim()} 
        AND "deletedAt" IS NULL
    `;

    if (existing.length > 0) {
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

    // Cek apakah parkiran ada
    const existing = await prisma.$queryRaw`
        SELECT id_parkiran FROM parkiran 
        WHERE id_parkiran = ${parseInt(id)} 
        AND "deletedAt" IS NULL
    `;

    if (existing.length === 0) {
        return res.status(404).json({
            status: "error",
            message: "Parkiran not found"
        });
    }

    // Jika nama berubah, cek unique
    if (nama_parkiran) {
        const nameCheck = await prisma.$queryRaw`
            SELECT id_parkiran FROM parkiran 
            WHERE nama_parkiran = ${nama_parkiran.trim()} 
            AND id_parkiran != ${parseInt(id)}
            AND "deletedAt" IS NULL
        `;

        if (nameCheck.length > 0) {
            return res.status(409).json({
                status: "error",
                message: "Nama parkiran already exists"
            });
        }
    }

    // Build update query dynamically
    let updates = [];
    if (nama_parkiran) updates.push(`nama_parkiran = '${nama_parkiran.trim()}'`);
    if (kapasitas) updates.push(`kapasitas = ${parseInt(kapasitas)}`);
    if (latitude !== undefined && longitude !== undefined) {
        updates.push(`koordinat = point(${parseFloat(longitude)}, ${parseFloat(latitude)})`);
    }
    updates.push(`"updatedAt" = NOW()`);

    if (updates.length > 1) {
        await prisma.$executeRawUnsafe(`
            UPDATE parkiran 
            SET ${updates.join(', ')}
            WHERE id_parkiran = ${parseInt(id)}
        `);
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

    // Debug logging for face image reception
    console.log(`[Edge Entry] Plate: ${plate_text}, Gate: ${gate_type}`);
    console.log(`[Edge Entry] Plate file: ${plateFile ? `${plateFile.originalname} (${plateFile.size} bytes)` : 'NOT RECEIVED'}`);
    console.log(`[Edge Entry] Face file: ${faceFile ? `${faceFile.originalname} (${faceFile.size} bytes)` : 'NOT RECEIVED'}, detected: ${isFaceDetected}`);

    // 1. Validate edge device secret
    const edgeSecret = req.headers['x-edge-secret'];
    if (edgeSecret !== process.env.EDGE_DEVICE_SECRET) {
        return res.status(401).json({
            success: false,
            gate_action: "DENY",
            message: "Unauthorized edge device"
        });
    }

    // 2. Validate required fields
    if (!plate_text || !parkiran_id || !gate_type) {
        return res.status(400).json({
            success: false,
            gate_action: "DENY",
            message: "Missing required fields: plate_text, parkiran_id, gate_type"
        });
    }

    // Normalize plate text (remove spaces, uppercase)
    const normalizedPlate = plate_text.toUpperCase().replace(/\s/g, '');

    // 3. Find registered vehicle by plate number
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
            success: false,
            gate_action: "DENY",
            message: `Kendaraan ${plate_text} tidak terdaftar atau belum terverifikasi`
        });
    }

    // 4. Check parkiran exists and has capacity
    const parkiran = await prisma.$queryRaw`
        SELECT id_parkiran, nama_parkiran, kapasitas, live_kapasitas
        FROM parkiran WHERE id_parkiran = ${parseInt(parkiran_id)} AND "deletedAt" IS NULL
    `;

    if (parkiran.length === 0) {
        return res.status(404).json({
            success: false,
            gate_action: "DENY",
            message: "Lokasi parkiran tidak ditemukan"
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
            } catch (error) {
                console.error('Failed to upload plate image:', error);
            }
        }
    };

    // Async face image upload handling
    const processFaceImageUpload = async (logId) => {
        console.log(`[Face Upload] Starting for log ${logId}, faceFile exists: ${!!faceFile}`);
        if (faceFile) {
            try {
                console.log(`[Face Upload] Uploading ${faceFile.originalname} (${faceFile.size} bytes) to face_captures/`);
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
                console.log(`[Face Upload] SUCCESS for log ${logId}: ${uploadResult.fileUrl} (detected: ${isFaceDetected})`);
            } catch (error) {
                console.error(`[Face Upload] FAILED for log ${logId}:`, error.message);
                console.error(error.stack);
            }
        } else {
            console.log(`[Face Upload] SKIPPED for log ${logId} - no faceFile received`);
        }
    };

    // 5. Process based on gate type
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
                success: false,
                gate_action: "DENY",
                message: `Kendaraan ${plate_text} sudah berada di dalam parkiran`
            });
        }

        // Create entry log and increment capacity
        const [newLog] = await prisma.$transaction([
            prisma.logParkir.create({
                data: {
                    id_kendaraan: kendaraan.id_kendaraan,
                    id_parkiran: parseInt(parkiran_id),
                    id_user: kendaraan.user?.id_user,
                    type: 'MASUK',
                    confidence: confidence ? parseFloat(confidence) : null,
                    image_url: null // Will be updated asynchronously
                }
            }),
            prisma.$executeRaw`
                UPDATE parkiran SET live_kapasitas = live_kapasitas + 1, "updatedAt" = NOW()
                WHERE id_parkiran = ${parseInt(parkiran_id)}
            `
        ]);

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

        return res.status(200).json({
            success: true,
            gate_action: "OPEN",
            message: `Selamat datang ${kendaraan.user?.nama || 'User'}! Kendaraan ${plate_text} masuk.`,
            data: {
                plate_text: normalizedPlate,
                owner: kendaraan.user?.nama,
                parkiran: parkiranData.nama_parkiran,
                slot_tersisa: slotTersisa
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
                success: false,
                gate_action: "DENY",
                message: `Kendaraan ${plate_text} tidak tercatat masuk parkiran`
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
                    confidence: confidence ? parseFloat(confidence) : null,
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

        return res.status(200).json({
            success: true,
            gate_action: "OPEN",
            message: `Sampai jumpa ${kendaraan.user?.nama || 'User'}! Kendaraan ${plate_text} keluar.`,
            data: {
                plate_text: normalizedPlate,
                owner: kendaraan.user?.nama,
                parkiran: parkiranData.nama_parkiran
            }
        });
    }

    return res.status(400).json({
        success: false,
        gate_action: "DENY",
        message: "Invalid gate_type. Use 'MASUK' or 'KELUAR'"
    });
});
