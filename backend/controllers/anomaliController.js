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
    const userId = req.user.id_user;
    const userRole = req.user.role;

    // 1. Validasi Keberadaan Kelas
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

    // 2. Validasi Otorisasi (Hanya Admin atau Dosen Pengampu)
    if (userRole === 'DOSEN' && kelas.id_dosen !== userId) {
        return res.status(403).json({
            status: "error",
            message: "Anda tidak memiliki akses untuk menganalisis kelas ini"
        });
    }

    // 3. Mengambil Data Mentah dari Database (Parallel Fetching)
    // Kita butuh: Data Peserta, Riwayat Absensi, dan Jumlah Sesi yang sudah berlalu
    const [peserta, absensi, totalSesi] = await prisma.$transaction([
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
        // Ambil record absensi valid
        prisma.absensi.findMany({
            where: { 
                id_kelas: parseInt(id_kelas), 
                deletedAt: null 
            },
            select: {
                id_user: true,
                id_sesi_absensi: true,
                createdAt: true // Timestamp penting untuk analisis waktu
            }
        }),
        // Hitung sesi yang sudah selesai/lewat tanggalnya
        prisma.sesiAbsensi.count({
            where: { 
                id_kelas: parseInt(id_kelas), 
                deletedAt: null,
                // Kita anggap sesi valid untuk dihitung jika waktu mulai sudah lewat
                mulai: { lte: new Date() } 
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

    // 4. Siapkan Payload untuk dikirim ke Python Service
    const payload = {
        total_sessions: totalSesi === 0 ? 1 : totalSesi, // Hindari division by zero
        students: peserta.map(p => ({
            id_user: p.mahasiswa.id_user,
            nama: p.mahasiswa.nama
        })),
        attendance: absensi.map(a => ({
            id_user: a.id_user,
            id_sesi: a.id_sesi_absensi,
            timestamp: a.createdAt.toISOString()
        }))
    };

    try {
        // 5. Request ke Python Microservice
        console.log(`[Anomali] Sending data to ${PYTHON_SERVICE_URL}/detect-anomalies...`);
        const pythonResponse = await axios.post(`${PYTHON_SERVICE_URL}/detect-anomalies`, payload);
        
        const { anomalies } = pythonResponse.data;

        // 6. Simpan Hasil ke Database
        // Hapus laporan lama untuk kelas ini agar data selalu fresh (Re-analysis strategy)
        await prisma.laporanAnomali.deleteMany({
            where: { id_kelas: parseInt(id_kelas) }
        });

        if (anomalies && anomalies.length > 0) {
            // Bulk Insert menggunakan createMany
            const dataToInsert = anomalies.map(item => ({
                id_user: item.id_user,
                id_kelas: parseInt(id_kelas),
                type_anomali: item.type_anomali, // Pastikan string ini match dengan ENUM di Prisma
                // Note: Schema saat ini belum ada field 'deskripsi' atau 'confidence', 
                // jika schema diupdate, tambahkan di sini.
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
                ip: req.ip || req.headers['x-forwarded-for']
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