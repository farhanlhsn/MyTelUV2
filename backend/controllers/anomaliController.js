const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma');
const axios = require('axios');
const { logAudit } = require('../utils/auditLogger'); // Opsional, jika Anda menggunakan logger

// URL Service Python (Port 5003 sesuai setup anomaly_detection)
// Gunakan environment variable atau fallback ke localhost
const PYTHON_SERVICE_URL = process.env.ANOMALY_SERVICE_URL || 'http://localhost:5003';

/**
 * @desc    Memicu analisis AI untuk mendeteksi anomali pada kelas tertentu
 * @route   POST /api/anomali/analyze/:id_kelas
 * @access  Private (Dosen/Admin)
 */
exports.analyzeKelasAttendance = asyncHandler(async (req, res) => {
    const { id_kelas } = req.params;
    const { threshold = 0.5, contamination = 0.1 } = req.body;
    const userId = req.user.id_user;
    const userRole = req.user.role;

    // 1. Validasi Input Threshold & Contamination
    const parsedThreshold = parseFloat(threshold);
    if (isNaN(parsedThreshold) || parsedThreshold < 0.1 || parsedThreshold > 1.0) {
        return res.status(400).json({
            status: "error",
            message: "Threshold harus berupa angka antara 0.1 dan 1.0"
        });
    }

    const parsedContamination = parseFloat(contamination);
    if (isNaN(parsedContamination) || parsedContamination < 0.01 || parsedContamination > 0.5) {
        return res.status(400).json({
            status: "error",
            message: "Contamination harus berupa angka antara 0.01 dan 0.5"
        });
    }

    // 2. Validasi Keberadaan Kelas
    const kelas = await prisma.kelas.findUnique({
        where: { id_kelas: parseInt(id_kelas) },
        include: { matakuliah: true }
    });

    if (!kelas) {
        return res.status(404).json({
            status: "error",
            message: "Kelas tidak ditemukan"
        });
    }

    // 3. Validasi Otorisasi (Hanya Admin atau Dosen Pengampu)
    if (userRole === 'DOSEN' && kelas.id_dosen !== userId) {
        return res.status(403).json({
            status: "error",
            message: "Anda tidak memiliki akses untuk menganalisis kelas ini"
        });
    }

    // 4. Mengambil Data Mentah dari Database (Parallel Fetching)
    const [peserta, absensi, sesiList] = await prisma.$transaction([
        // Ambil daftar peserta aktif
        prisma.pesertaKelas.findMany({
            where: { 
                id_kelas: parseInt(id_kelas), 
                deletedAt: null 
            },
            include: { 
                mahasiswa: { 
                    select: { id_user: true, nama: true } 
                } 
            }
        }),
        // Ambil record absensi valid dengan koordinat
        prisma.absensi.findMany({
            where: { 
                id_kelas: parseInt(id_kelas), 
                deletedAt: null 
            },
            select: {
                id_user: true,
                id_sesi_absensi: true,
                koordinat: true,
                createdAt: true // Timestamp penting untuk analisis waktu
            }
        }),
        // Ambil list semua sesi yang valid dengan koordinat
        prisma.sesiAbsensi.findMany({
            where: { 
                id_kelas: parseInt(id_kelas), 
                deletedAt: null,
                mulai: { lte: new Date() }
            },
            select: {
                id_sesi_absensi: true,
                mulai: true,
                selesai: true,
                latitude: true,
                longitude: true
            }
        })
    ]);

    // Jika belum ada data yang cukup
    if (peserta.length === 0) {
        return res.status(400).json({
            status: "error",
            message: "Tidak ada peserta dalam kelas ini untuk dianalisis."
        });
    }

    const totalSesi = sesiList.length;

    // 5. Siapkan Payload untuk dikirim ke Python Service
    const payload = {
        total_sessions: totalSesi === 0 ? 1 : totalSesi, // Hindari division by zero
        threshold: parsedThreshold,
        contamination: parsedContamination,
        students: peserta.map(p => ({
            id_user: p.mahasiswa.id_user,
            nama: p.mahasiswa.nama
        })),
        sessions: sesiList.map(s => ({
            id_sesi: s.id_sesi_absensi,
            mulai: s.mulai.toISOString(),
            selesai: s.selesai.toISOString(),
            latitude: s.latitude,
            longitude: s.longitude
        })),
        attendance: absensi.map(a => {
            // koordinat is of type Point in Postgres/Prisma.
            // Safe parse object {x, y} or array [x, y]
            let lat = null;
            let lng = null;
            if (a.koordinat) {
                if (typeof a.koordinat === 'object') {
                    lat = a.koordinat.y !== undefined ? a.koordinat.y : a.koordinat[1];
                    lng = a.koordinat.x !== undefined ? a.koordinat.x : a.koordinat[0];
                } else if (Array.isArray(a.koordinat)) {
                    lng = a.koordinat[0];
                    lat = a.koordinat[1];
                }
            }
            return {
                id_user: a.id_user,
                id_sesi: a.id_sesi_absensi,
                timestamp: a.createdAt.toISOString(),
                latitude: lat,
                longitude: lng
            };
        })
    };

    try {
        // 6. Request ke Python Microservice
        console.log(`[Anomali] Sending data to ${PYTHON_SERVICE_URL}/detect-anomalies...`);
        const pythonResponse = await axios.post(`${PYTHON_SERVICE_URL}/detect-anomalies`, payload);
        
        const { anomalies } = pythonResponse.data;

        // 7. Simpan Hasil ke Database (Soft Delete laporan lama)
        await prisma.laporanAnomali.updateMany({
            where: { 
                id_kelas: parseInt(id_kelas),
                deletedAt: null
            },
            data: {
                deletedAt: new Date()
            }
        });

        if (anomalies && anomalies.length > 0) {
            // Bulk Insert menggunakan createMany
            const dataToInsert = anomalies.map(item => ({
                id_user: item.id_user,
                id_kelas: parseInt(id_kelas),
                type_anomali: item.type_anomali, // Pastikan string ini match dengan ENUM di Prisma
                deskripsi: item.description || null,
                confidence: item.confidence !== undefined ? parseFloat(item.confidence) : null,
                status: 'OPEN'
            }));

            await prisma.laporanAnomali.createMany({
                data: dataToInsert
            });
        }

        // 7. Audit Log (Opsional)
        if (typeof logAudit === 'function') {
            logAudit({
                action: 'ANOMALY_ANALYSIS',
                performedBy: userId,
                targetUserId: null,
                details: `Analisis kelas ${kelas.nama_kelas} (ID: ${id_kelas}). Ditemukan ${anomalies.length} anomali.`,
                ip: req.ip || (req.headers && req.headers['x-forwarded-for']) || '127.0.0.1'
            });
        }

        // 8. Return Response ke Client (Mobile/Web)
        // Kita kembalikan juga data raw anomalinya agar Frontend bisa langsung menampilkan
        // tanpa perlu fetch ulang ke endpoint GET jika diinginkan.
        res.status(200).json({
            status: "success",
            message: anomalies.length > 0 
                ? `Analisis selesai. Ditemukan ${anomalies.length} potensi anomali.` 
                : "Analisis selesai. Data kehadiran tampak normal.",
            data: anomalies
        });

    } catch (error) {
        console.error("AI Service Error:", error.message);
        
        // Handle jika Python service mati/error
        if (error.code === 'ECONNREFUSED') {
            return res.status(503).json({
                status: "error",
                message: "Layanan AI sedang tidak tersedia. Pastikan Python Service berjalan di port 5003."
            });
        }

        return res.status(500).json({
            status: "error",
            message: "Gagal memproses analisis AI: " + (error.response?.data?.error || error.message)
        });
    }
});

/**
 * @desc    Mengambil riwayat laporan anomali untuk kelas tertentu
 * @route   GET /api/anomali/:id_kelas
 * @access  Private (Dosen/Admin)
 */
exports.getLaporanAnomali = asyncHandler(async (req, res) => {
    const { id_kelas } = req.params;
    const userId = req.user.id_user;
    const userRole = req.user.role;

    // Validasi akses (mirip dengan fungsi analyze)
    const kelas = await prisma.kelas.findUnique({ where: { id_kelas: parseInt(id_kelas) } });
    
    if (!kelas) {
        return res.status(404).json({ status: "error", message: "Kelas tidak ditemukan" });
    }

    if (userRole === 'DOSEN' && kelas.id_dosen !== userId) {
        return res.status(403).json({ status: "error", message: "Akses ditolak" });
    }

    // Ambil data laporan dari database
    const laporan = await prisma.laporanAnomali.findMany({
        where: { 
            id_kelas: parseInt(id_kelas),
            deletedAt: null 
        },
        include: {
            user: {
                select: {
                    id_user: true,
                    nama: true,
                    username: true // NIM
                }
            }
        },
        orderBy: {
            createdAt: 'desc'
        }
    });

    res.status(200).json({
        status: "success",
        data: laporan
    });
});

/**
 * @desc    Dosen/Admin menindaklanjuti laporan anomali (update status & catatan)
 * @route   PUT /api/v1/anomali/:id_anomali
 * @access  Private (Dosen/Admin)
 */
exports.updateLaporanAnomali = asyncHandler(async (req, res) => {
    const { id_anomali } = req.params;
    const { status, catatan_dosen } = req.body;
    const userId = req.user.id_user;
    const userRole = req.user.role;

    // Validate status
    if (status && !['OPEN', 'REVIEWED', 'RESOLVED'].includes(status)) {
        return res.status(400).json({
            status: "error",
            message: "Status tidak valid. Harus OPEN, REVIEWED, atau RESOLVED."
        });
    }

    // Find the anomaly report
    const laporan = await prisma.laporanAnomali.findFirst({
        where: {
            id_anomali: parseInt(id_anomali),
            deletedAt: null
        },
        include: {
            kelas: true
        }
    });

    if (!laporan) {
        return res.status(404).json({
            status: "error",
            message: "Laporan anomali tidak ditemukan"
        });
    }

    // Verify authorization: Admin or assigned Dosen
    if (userRole === 'DOSEN' && laporan.kelas?.id_dosen !== userId) {
        return res.status(403).json({
            status: "error",
            message: "Anda tidak memiliki akses untuk mengubah laporan ini"
        });
    }

    // Update data
    const updateData = {};
    if (status) {
        updateData.status = status;
        if (status === 'RESOLVED') {
            updateData.resolved_at = new Date();
        }
    }
    if (catatan_dosen !== undefined) {
        updateData.catatan_dosen = catatan_dosen ? catatan_dosen.trim() : null;
    }

    const updatedLaporan = await prisma.laporanAnomali.update({
        where: { id_anomali: parseInt(id_anomali) },
        data: updateData
    });

    res.status(200).json({
        status: "success",
        message: "Laporan anomali berhasil diperbarui",
        data: updatedLaporan
    });
});