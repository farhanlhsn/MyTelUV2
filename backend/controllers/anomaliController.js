const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma');
const axios = require('axios');
const { logAudit } = require('../utils/auditLogger'); // Opsional, jika Anda menggunakan logger
const CircuitBreaker = require('../utils/CircuitBreaker');
const { globalAnomalyQueue } = require('../utils/TaskQueue');

// URL Service Python (Port 5003 sesuai setup anomaly_detection)
// Gunakan environment variable atau fallback ke localhost
const ANOMALY_SERVICE_URL = (process.env.ANOMALY_SERVICE_URL || 'http://localhost:5003').replace(/\/+$/, '');
const ANOMALY_SERVICE_TIMEOUT_MS = Number.parseInt(process.env.ANOMALY_SERVICE_TIMEOUT_MS, 10) || 10000;

// Initialize Circuit Breaker for Anomaly Detection API
const anomalyApiBreaker = new CircuitBreaker("AnomalyAPI", {
    failureThreshold: parseInt(process.env.ANOMALY_CB_FAILURE_THRESHOLD || '3'),
    recoveryTimeout: parseInt(process.env.ANOMALY_CB_RECOVERY_TIMEOUT || '30000')
});

/**
 * @desc    Memicu analisis AI untuk mendeteksi anomali pada kelas tertentu
 * @route   POST /api/anomali/analyze/:id_kelas
 * @access  Private (Dosen/Admin)
 */
exports.analyzeKelasAttendance = asyncHandler(async (req, res) => {
    const { id_kelas } = req.params;
    const userId = req.user.id_user;
    const userRole = req.user.role;

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
        // Ambil record absensi valid
        prisma.$queryRaw`SELECT id_user, id_sesi_absensi, "createdAt" FROM absensi WHERE id_kelas = ${parseInt(id_kelas)} AND "deletedAt" IS NULL`,
        // Ambil list semua sesi yang valid
        prisma.sesiAbsensi.findMany({
            where: { 
                id_kelas: parseInt(id_kelas), 
                deletedAt: null,
                mulai: { lte: new Date() }
            },
            select: {
                id_sesi_absensi: true,
                mulai: true,
                selesai: true
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
    const isAsync = req.query.async === 'true';

    const runAnalysisTask = async () => {
        // Fetch threshold from database dynamically
        const settingJarangHadir = await prisma.systemSetting.findUnique({
            where: { key: 'anomaly_threshold_jarang_hadir' }
        });
        const thresholdJarangHadirVal = settingJarangHadir ? parseFloat(settingJarangHadir.value) : 50; // default 50%
        const thresholdJarangHadir = thresholdJarangHadirVal / 100;

        const settingKehadiranGanda = await prisma.systemSetting.findUnique({
            where: { key: 'anomaly_threshold_kehadiran_ganda' }
        });
        const thresholdKehadiranGandaVal = settingKehadiranGanda ? parseFloat(settingKehadiranGanda.value) : 10; // default 10%
        const thresholdKehadiranGanda = thresholdKehadiranGandaVal / 100;

        const anomalies = [];

        // Rule 1: TIDAK_HADIR_BERULANG (Jarang Hadir)
        const attendanceCounts = {};
        absensi.forEach(a => {
            attendanceCounts[a.id_user] = (attendanceCounts[a.id_user] || 0) + 1;
        });

        for (const p of peserta) {
            const uid = p.mahasiswa.id_user;
            const jumlahHadir = attendanceCounts[uid] || 0;
            const attendanceRate = totalSesi > 0 ? (jumlahHadir / totalSesi) : 1.0;

            if (attendanceRate <= thresholdJarangHadir) {
                const confidence = thresholdJarangHadir > 0 ? 1.0 - (attendanceRate / thresholdJarangHadir) : 1.0;
                anomalies.push({
                    id_user: uid,
                    type_anomali: 'TIDAK_HADIR_BERULANG',
                    confidence: Math.min(1.0, Math.max(0.0, parseFloat(confidence.toFixed(2)))),
                    description: `Kehadiran rendah: ${(attendanceRate * 100).toFixed(0)}% (Threshold: ${(thresholdJarangHadir * 100).toFixed(0)}%)`
                });
            }
        }

        // Rule 2: KEHADIRAN_GANDA
        const userSesiCounts = {};
        absensi.forEach(a => {
            const key = `${a.id_user}_${a.id_sesi_absensi}`;
            userSesiCounts[key] = (userSesiCounts[key] || 0) + 1;
        });

        const duplicateSessionsByUser = {};
        Object.keys(userSesiCounts).forEach(key => {
            if (userSesiCounts[key] > 1) {
                const [uid, _] = key.split('_');
                duplicateSessionsByUser[uid] = (duplicateSessionsByUser[uid] || 0) + 1;
            }
        });

        Object.keys(duplicateSessionsByUser).forEach(uidStr => {
            const uid = parseInt(uidStr);
            const dupCount = duplicateSessionsByUser[uidStr];
            const dupRate = totalSesi > 0 ? (dupCount / totalSesi) : 0;

            if (dupRate >= thresholdKehadiranGanda) {
                const confidence = thresholdKehadiranGanda > 0 ? dupRate / thresholdKehadiranGanda : 1.0;
                anomalies.push({
                    id_user: uid,
                    type_anomali: 'KEHADIRAN_GANDA',
                    confidence: Math.min(1.0, Math.max(0.0, parseFloat(confidence.toFixed(2)))),
                    description: `Terdeteksi multiple check-in pada ${dupCount} sesi (${(dupRate * 100).toFixed(0)}% dari total sesi, Threshold: ${(thresholdKehadiranGanda * 100).toFixed(0)}%).`
                });
            }
        });

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
            const dataToInsert = anomalies.map(item => ({
                id_user: item.id_user,
                id_kelas: parseInt(id_kelas),
                type_anomali: item.type_anomali,
                deskripsi: item.description || null,
                confidence: item.confidence !== undefined ? parseFloat(item.confidence) : null,
                status: 'OPEN'
            }));

            await prisma.laporanAnomali.createMany({
                data: dataToInsert
            });
        }

        // Audit Log
        if (typeof logAudit === 'function') {
            logAudit({
                action: 'ANOMALY_ANALYSIS',
                performedBy: userId,
                targetUserId: null,
                details: `Analisis kelas ${kelas.nama_kelas} (ID: ${id_kelas}). Ditemukan ${anomalies.length} anomali.`,
                ip: req.ip || (req.headers && req.headers['x-forwarded-for']) || '127.0.0.1'
            });
        }

        return anomalies;
    };

    if (isAsync) {
        const jobId = `anomaly_kelas_${id_kelas}_${Date.now()}`;
        globalAnomalyQueue.addJob(jobId, runAnalysisTask);
        
        return res.status(202).json({
            status: "success",
            message: "Analisis anomali telah dijadwalkan di latar belakang.",
            data: {
                jobId,
                status: "QUEUED"
            }
        });
    }

    try {
        const anomalies = await runAnalysisTask();

        res.status(200).json({
            status: "success",
            message: anomalies.length > 0 
                ? `Analisis selesai. Ditemukan ${anomalies.length} potensi anomali.` 
                : "Analisis selesai. Data kehadiran tampak normal.",
            data: anomalies
        });

    } catch (error) {
        console.error("Local Rule Service Error:", error.message);
        return res.status(500).json({
            status: "error",
            message: "Gagal memproses analisis: " + error.message
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

/**
 * @desc    Mengambil status pekerjaan background asinkron
 * @route   GET /api/anomali/job-status/:jobId
 * @access  Private (Dosen/Admin)
 */
exports.getJobStatus = asyncHandler(async (req, res) => {
    const { jobId } = req.params;
    const job = globalAnomalyQueue.getJobStatus(jobId);
    
    if (!job) {
        return res.status(404).json({
            status: "error",
            message: "Pekerjaan analisis tidak ditemukan atau sudah dibersihkan dari memori."
        });
    }
    
    res.status(200).json({
        status: "success",
        data: job
    });
});

/**
 * @desc    Mengambil konfigurasi threshold anomali
 * @route   GET /api/v1/anomali/settings
 * @access  Private (Admin)
 */
exports.getAnomalySettings = asyncHandler(async (req, res) => {
    const settingJarangHadir = await prisma.systemSetting.findUnique({
        where: { key: 'anomaly_threshold_jarang_hadir' }
    });
    const settingKehadiranGanda = await prisma.systemSetting.findUnique({
        where: { key: 'anomaly_threshold_kehadiran_ganda' }
    });

    res.status(200).json({
        status: "success",
        data: {
            threshold_jarang_hadir: settingJarangHadir ? parseInt(settingJarangHadir.value) : 50,
            threshold_kehadiran_ganda: settingKehadiranGanda ? parseInt(settingKehadiranGanda.value) : 10
        }
    });
});

/**
 * @desc    Memperbarui konfigurasi threshold anomali
 * @route   PUT /api/v1/anomali/settings
 * @access  Private (Admin)
 */
exports.updateAnomalySettings = asyncHandler(async (req, res) => {
    const { threshold_jarang_hadir, threshold_kehadiran_ganda } = req.body;

    if (threshold_jarang_hadir !== undefined) {
        const val = parseInt(threshold_jarang_hadir);
        if (isNaN(val) || val < 0 || val > 100) {
            return res.status(400).json({
                status: "error",
                message: "Threshold jarang hadir harus berupa angka antara 0 dan 100"
            });
        }
        await prisma.systemSetting.upsert({
            where: { key: 'anomaly_threshold_jarang_hadir' },
            update: { value: String(val) },
            create: { key: 'anomaly_threshold_jarang_hadir', value: String(val) }
        });
    }

    if (threshold_kehadiran_ganda !== undefined) {
        const val = parseInt(threshold_kehadiran_ganda);
        if (isNaN(val) || val < 0 || val > 100) {
            return res.status(400).json({
                status: "error",
                message: "Threshold kehadiran ganda harus berupa angka antara 0 dan 100"
            });
        }
        await prisma.systemSetting.upsert({
            where: { key: 'anomaly_threshold_kehadiran_ganda' },
            update: { value: String(val) },
            create: { key: 'anomaly_threshold_kehadiran_ganda', value: String(val) }
        });
    }

    res.status(200).json({
        status: "success",
        message: "Konfigurasi threshold anomali berhasil diperbarui"
    });
});