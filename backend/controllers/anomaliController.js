const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma');
const { pythonClient } = require('../utils/pythonClient');
const { pythonServiceHeaders } = require('../utils/pythonServiceHeaders');
const { logAudit } = require('../utils/auditLogger'); // Opsional, jika Anda menggunakan logger
const CircuitBreaker = require('../utils/CircuitBreaker');
const { globalAnomalyQueue } = require('../utils/TaskQueue');
const { GENERIC_SERVER_ERROR } = require('../utils/serverError');
const {
    isCountableSession,
    absensiStatus,
    isPresentStatus,
    summarizeKehadiran,
    parsePagination,
    buildPaginationResponse
} = require('../utils/akademikHelpers');

// URL Service Python (Port 5003 sesuai setup anomaly_detection)
// Gunakan environment variable atau fallback ke localhost
const ANOMALY_SERVICE_URL = (process.env.ANOMALY_SERVICE_URL || 'http://localhost:5003').replace(/\/+$/, '');
const ANOMALY_SERVICE_TIMEOUT_MS = Number.parseInt(process.env.ANOMALY_SERVICE_TIMEOUT_MS, 10) || 10000;

// Initialize Circuit Breaker for Anomaly Detection API
const anomalyApiBreaker = new CircuitBreaker("AnomalyAPI", {
    failureThreshold: parseInt(process.env.ANOMALY_CB_FAILURE_THRESHOLD || '3'),
    recoveryTimeout: parseInt(process.env.ANOMALY_CB_RECOVERY_TIMEOUT || '30000')
});

const POLA_WAKTU_UNAVAILABLE_WARNING = 'Layanan analisis pola waktu tidak tersedia';

/**
 * POLA_WAKTU_TIDAK_WAJAR from the Python anomaly service (`POST /detect-anomalies`: late-in-session rule
 * plus IsolationForest on check-in timing). The service is used for this rule only:
 * - it gets the real check-ins only: HADIR/TELAT rows that have a check-in (`check_in`: a location was
 *   recorded; a status entered by a dosen has none and its createdAt is not a check-in time), in sessions
 *   that count for that student (closed, on/after the enrollment);
 * - `threshold: 0` keeps the service's own status-blind TIDAK_HADIR_BERULANG rule from firing (a rate is
 *   never < 0), so it never hides a POLA_WAKTU result behind it; KEHADIRAN_GANDA and any other type it
 *   returns are ignored.
 * The service flags a student from 2 check-ins on, so without such a student it is not called.
 *
 * @returns {Promise<{anomalies: object[], available: boolean}>} available=false when the breaker is open,
 *          the call failed or the answer was not `{success: true, anomalies: [...]}`.
 */
const detectPolaWaktu = async ({ peserta, absensi, sesiList, now }) => {
    const pesertaById = new Map(peserta.map(p => [p.mahasiswa.id_user, p]));
    const sesiById = new Map(sesiList.map(s => [s.id_sesi_absensi, s]));
    const closedSessions = sesiList.filter(s => isCountableSession(s, null, now));

    const attendance = absensi
        .filter(a => {
            const p = pesertaById.get(a.id_user);
            const sesi = sesiById.get(a.id_sesi_absensi);
            return p && sesi && a.check_in === true && isPresentStatus(absensiStatus(a))
                && isCountableSession(sesi, p.createdAt, now);
        })
        .map(a => ({ id_user: a.id_user, id_sesi: a.id_sesi_absensi, timestamp: new Date(a.createdAt).toISOString() }));

    const checkInsByUser = new Map();
    attendance.forEach(a => checkInsByUser.set(a.id_user, (checkInsByUser.get(a.id_user) || 0) + 1));
    if (![...checkInsByUser.values()].some(count => count >= 2)) {
        return { anomalies: [], available: true };
    }

    const payload = {
        students: peserta.map(p => ({ id_user: p.mahasiswa.id_user })),
        attendance,
        sessions: closedSessions.map(s => ({
            id_sesi: s.id_sesi_absensi,
            mulai: new Date(s.mulai).toISOString(),
            selesai: new Date(s.selesai).toISOString()
        })),
        total_sessions: Math.max(1, closedSessions.length),
        threshold: 0
    };

    let result;
    try {
        result = await anomalyApiBreaker.fire(async () => {
            const response = await pythonClient.post(`${ANOMALY_SERVICE_URL}/detect-anomalies`, payload, {
                headers: pythonServiceHeaders('anomaly', { 'Content-Type': 'application/json' }),
                timeout: ANOMALY_SERVICE_TIMEOUT_MS
            });
            const data = response && response.data;
            if (!data || data.success !== true || !Array.isArray(data.anomalies)) {
                throw new Error('Invalid response from the anomaly service');
            }
            return data.anomalies;
        });
    } catch (error) {
        console.warn('[Anomali] POLA_WAKTU_TIDAK_WAJAR skipped, anomaly service unavailable:', error.message);
        return { anomalies: [], available: false };
    }

    const anomalies = result
        .filter(a => a && a.type_anomali === 'POLA_WAKTU_TIDAK_WAJAR' && pesertaById.has(Number(a.id_user)))
        .map(a => {
            const confidence = Number(a.confidence);
            return {
                id_user: Number(a.id_user),
                nama: pesertaById.get(Number(a.id_user)).mahasiswa.nama,
                type_anomali: 'POLA_WAKTU_TIDAK_WAJAR',
                confidence: Number.isFinite(confidence) ? Math.min(1.0, Math.max(0.0, confidence)) : null,
                description: typeof a.description === 'string' ? a.description : null
            };
        });
    return { anomalies, available: true };
};

const reportKey = (idUser, type) => `${idUser}_${type}`;

/**
 * Saves the result of a (re-)analysis of a class in one transaction. Only OPEN reports are replaced:
 * - a detected anomaly with an active REVIEWED/RESOLVED report of the same (id_user, id_kelas, type) is
 *   "sudah ditinjau" while there is no new evidence: the newest such report was reviewed (updatedAt)
 *   at/after the end (selesai) of the student's latest countable session. It gets no OPEN report;
 * - otherwise the OPEN report with that key is refreshed in place (deskripsi, confidence; its id and
 *   catatan_dosen stay) or a new OPEN report is created;
 * - OPEN reports that are no longer detected are soft-deleted, except those of a rule that was skipped
 *   (`skippedTypes`, e.g. the AI service was down): not evaluated is not "no longer detected";
 * - REVIEWED/RESOLVED reports are never changed, whether detected again or not.
 * The class row is locked first, so two analyses of the same class run one after the other. Every update
 * is guarded by `status: 'OPEN'`, so a report a dosen reviews meanwhile is not overwritten (that anomaly
 * then counts as sudah ditinjau).
 *
 * @param {number} idKelas
 * @param {object[]} anomalies - detected anomalies ({id_user, type_anomali, description, confidence, ...})
 * @param {object} [options]
 * @param {Map<number, number>} [options.latestSessionEnd] - id_user -> end (ms) of the latest countable session
 * @param {string[]} [options.skippedTypes] - rule types that were not evaluated in this run
 * @returns {Promise<{active: object[], ditinjau: object[]}>} active: anomalies that are active OPEN reports
 *          after saving; ditinjau: anomalies covered by a review, flagged `sudah_ditinjau: true`
 */
const saveAnalysisResult = (idKelas, anomalies, { latestSessionEnd = new Map(), skippedTypes = [] } = {}) => prisma.$transaction(async (tx) => {
    await tx.$queryRaw`SELECT id_kelas FROM kelas WHERE id_kelas = ${idKelas} FOR UPDATE`;

    const existing = await tx.laporanAnomali.findMany({
        where: { id_kelas: idKelas, deletedAt: null },
        select: { id_anomali: true, id_user: true, type_anomali: true, status: true, updatedAt: true },
        orderBy: { createdAt: 'desc' }
    });

    const reviewedAtByKey = new Map(); // newest review time (ms) of a REVIEWED/RESOLVED report per key
    const openByKey = new Map(); // newest OPEN report per key
    for (const report of existing) {
        const key = reportKey(report.id_user, report.type_anomali);
        if (report.status !== 'OPEN') {
            const reviewedAt = new Date(report.updatedAt).getTime();
            if (!reviewedAtByKey.has(key) || reviewedAt > reviewedAtByKey.get(key)) reviewedAtByKey.set(key, reviewedAt);
        } else if (!openByKey.has(key)) {
            openByKey.set(key, report);
        }
    }

    // A review covers the anomaly until a countable session ends after it (new evidence)
    const coveredByReview = (item) => {
        const reviewedAt = reviewedAtByKey.get(reportKey(item.id_user, item.type_anomali));
        if (reviewedAt === undefined) return false;
        const latestEnd = latestSessionEnd.get(item.id_user);
        return latestEnd === undefined || reviewedAt >= latestEnd;
    };

    const active = [];
    const ditinjau = [];
    const keptOpenIds = new Set();
    const toCreate = [];
    for (const item of anomalies) {
        if (coveredByReview(item)) {
            ditinjau.push({ ...item, sudah_ditinjau: true });
            continue;
        }

        const fields = {
            deskripsi: item.description || null,
            confidence: item.confidence !== undefined && item.confidence !== null ? parseFloat(item.confidence) : null
        };
        const open = openByKey.get(reportKey(item.id_user, item.type_anomali));
        if (open) {
            const { count } = await tx.laporanAnomali.updateMany({
                where: { id_anomali: open.id_anomali, status: 'OPEN', deletedAt: null },
                data: fields
            });
            keptOpenIds.add(open.id_anomali);
            // count 0: a dosen reviewed it after we read it
            if (count > 0) active.push(item);
            else ditinjau.push({ ...item, sudah_ditinjau: true });
        } else {
            toCreate.push({ id_user: item.id_user, id_kelas: idKelas, type_anomali: item.type_anomali, ...fields, status: 'OPEN' });
            active.push(item);
        }
    }

    const staleOpenIds = existing
        .filter(report => report.status === 'OPEN'
            && !keptOpenIds.has(report.id_anomali)
            && !skippedTypes.includes(report.type_anomali))
        .map(report => report.id_anomali);
    if (staleOpenIds.length > 0) {
        await tx.laporanAnomali.updateMany({
            where: { id_anomali: { in: staleOpenIds }, status: 'OPEN', deletedAt: null },
            data: { deletedAt: new Date() }
        });
    }

    if (toCreate.length > 0) {
        await tx.laporanAnomali.createMany({ data: toCreate });
    }

    return { active, ditinjau };
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
        // Ambil record absensi valid (with the attendance status: HADIR/TELAT/IZIN/SAKIT/ALPHA). check_in:
        // the row comes from a check-in (it has a location); a status entered by a dosen has none
        prisma.$queryRaw`SELECT id_user, id_sesi_absensi, "createdAt", status::text AS status, (koordinat IS NOT NULL) AS check_in FROM absensi WHERE id_kelas = ${parseInt(id_kelas)} AND "deletedAt" IS NULL`,
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
                selesai: true,
                status: true
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

    const isAsync = req.query.async === 'true';

    const runAnalysisTask = async () => {
        // Fetch threshold from database dynamically with safety fallbacks
        let thresholdJarangHadirVal = 50; // default 50%
        try {
            const settingJarangHadir = await prisma.systemSetting.findUnique({
                where: { key: 'anomaly_threshold_jarang_hadir' }
            });
            if (settingJarangHadir) thresholdJarangHadirVal = parseFloat(settingJarangHadir.value);
        } catch (e) {
            console.warn("Failed to fetch anomaly_threshold_jarang_hadir from DB, using default 50:", e.message);
        }
        const thresholdJarangHadir = thresholdJarangHadirVal / 100;

        const anomalies = [];
        const warnings = [];

        // Rule 1: TIDAK_HADIR_BERULANG (Jarang Hadir)
        // Per student, over the closed sessions held on/after their enrollment: HADIR/TELAT present,
        // IZIN/SAKIT excused (left out of the rate), ALPHA or no record absent
        const now = new Date();
        const statusByUserSesi = new Map();
        absensi.forEach(a => {
            statusByUserSesi.set(`${a.id_user}_${a.id_sesi_absensi}`, absensiStatus(a));
        });

        // id_user -> end (ms) of the latest countable session: a review older than that has new evidence
        const latestSessionEnd = new Map();

        for (const p of peserta) {
            const uid = p.mahasiswa.id_user;
            const nama = p.mahasiswa.nama;
            const countable = sesiList.filter(s => isCountableSession(s, p.createdAt, now));
            countable.forEach(s => {
                const end = new Date(s.selesai).getTime();
                if (!latestSessionEnd.has(uid) || end > latestSessionEnd.get(uid)) latestSessionEnd.set(uid, end);
            });
            const rekap = summarizeKehadiran(countable
                .map(s => statusByUserSesi.get(`${uid}_${s.id_sesi_absensi}`) || null));
            // Nothing to count yet (no closed session since enrollment, or all excused): never an anomaly,
            // whatever the threshold
            if (rekap.dihitung === 0) continue;
            const attendanceRate = rekap.hadir / rekap.dihitung;

            if (attendanceRate <= thresholdJarangHadir) {
                const confidence = thresholdJarangHadir > 0 ? 1.0 - (attendanceRate / thresholdJarangHadir) : 1.0;
                anomalies.push({
                    id_user: uid,
                    nama: nama,
                    type_anomali: 'TIDAK_HADIR_BERULANG',
                    confidence: Math.min(1.0, Math.max(0.0, parseFloat(confidence.toFixed(2)))),
                    description: `Kehadiran rendah: ${(attendanceRate * 100).toFixed(0)}% (Ambang batas: ${(thresholdJarangHadir * 100).toFixed(0)}%)`
                });
            }
        }

        // (KEHADIRAN_GANDA is not checked: uq_absensi_user_sesi allows one record per student and session.
        // The enum value stays for the reports created before.)

        // Rule 2: POLA_WAKTU_TIDAK_WAJAR from the Python anomaly service. A student already flagged
        // TIDAK_HADIR_BERULANG gets no POLA_WAKTU report (chronic absence first, as in the service).
        const polaWaktu = await detectPolaWaktu({ peserta, absensi, sesiList, now });
        // A skipped rule was not evaluated: its OPEN reports must stay as they are
        const skippedTypes = [];
        if (!polaWaktu.available) {
            warnings.push(POLA_WAKTU_UNAVAILABLE_WARNING);
            skippedTypes.push('POLA_WAKTU_TIDAK_WAJAR');
        }
        const jarangHadir = new Set(anomalies.map(a => a.id_user));
        anomalies.push(...polaWaktu.anomalies.filter(a => !jarangHadir.has(a.id_user)));

        // Simpan hasil: only OPEN reports are replaced, REVIEWED/RESOLVED ones are kept
        const { active, ditinjau } = await saveAnalysisResult(parseInt(id_kelas), anomalies, { latestSessionEnd, skippedTypes });

        // Audit Log
        if (typeof logAudit === 'function') {
            logAudit({
                action: 'ANOMALY_ANALYSIS',
                performedBy: userId,
                targetUserId: null,
                details: `Analisis kelas ${kelas.nama_kelas} (ID: ${id_kelas}). Ditemukan ${active.length} anomali aktif, ${ditinjau.length} sudah ditinjau.`,
                ip: req.ip || (req.headers && req.headers['x-forwarded-for']) || '127.0.0.1'
            });
        }

        // anomalies: the active OPEN reports of this run; ditinjau: detected but covered by a review
        return { anomalies: active, ditinjau, warnings };
    };

    const resultMessage = (active, ditinjau) => {
        if (active.length > 0) return `Analisis selesai. Ditemukan ${active.length} potensi anomali.`;
        if (ditinjau.length > 0) return `Analisis selesai. Tidak ada anomali baru (${ditinjau.length} anomali sudah ditinjau).`;
        return "Analisis selesai. Data kehadiran tampak normal.";
    };

    if (isAsync) {
        const jobId = `anomaly_kelas_${id_kelas}_${Date.now()}`;
        globalAnomalyQueue.addJob(jobId, runAnalysisTask, userId);
        
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
        const { anomalies, ditinjau, warnings } = await runAnalysisTask();

        res.status(200).json({
            status: "success",
            message: resultMessage(anomalies, ditinjau),
            // only the anomalies that are active OPEN reports after this analysis
            data: anomalies,
            // detected again but covered by a REVIEWED/RESOLVED report (each has sudah_ditinjau: true)
            ...(ditinjau.length > 0 ? { ditinjau } : {}),
            // e.g. the POLA_WAKTU_TIDAK_WAJAR rule was skipped because the AI service is unavailable
            ...(warnings.length > 0 ? { warnings } : {})
        });

    } catch (error) {
        console.error("Local Rule Service Error:", error.message);
        return res.status(500).json({
            status: "error",
            message: GENERIC_SERVER_ERROR
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

    // Ambil data laporan dari database (paginated: ?page=&limit=, limit 1..100, default 10)
    const { page, limit, skip } = parsePagination(req.query);
    const where = {
        id_kelas: parseInt(id_kelas),
        deletedAt: null
    };
    const [laporan, total] = await prisma.$transaction([
        prisma.laporanAnomali.findMany({
            where,
            include: {
                user: {
                    select: {
                        id_user: true,
                        nama: true,
                        username: true,
                        nim_nip: true // NIM
                    }
                }
            },
            orderBy: {
                createdAt: 'desc'
            },
            skip,
            take: limit
        }),
        prisma.laporanAnomali.count({ where })
    ]);

    res.status(200).json({
        status: "success",
        data: laporan,
        pagination: buildPaginationResponse(total, page, limit)
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

    // Only the user who started the job (or an ADMIN) may read it. Anyone else gets the same 404 as
    // an unknown id, so job ids cannot be probed and another dosen's analysis result stays private.
    if (!job || (req.user.role !== 'ADMIN' && job.ownerId !== req.user.id_user)) {
        return res.status(404).json({
            status: "error",
            message: "Pekerjaan analisis tidak ditemukan atau sudah dibersihkan dari memori."
        });
    }

    const { ownerId, ...publicJob } = job;

    // A failed job's error is the raw exception message of the analysis (database / driver details).
    // TaskQueue already logged it; the client only learns that the job failed.
    if (publicJob.error) {
        publicJob.error = GENERIC_SERVER_ERROR;
    }

    res.status(200).json({
        status: "success",
        data: publicJob
    });
});

/**
 * @desc    Mengambil konfigurasi threshold anomali
 * @route   GET /api/v1/anomali/settings
 * @access  Private (Admin)
 */
exports.getAnomalySettings = asyncHandler(async (req, res) => {
    try {
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
    } catch (error) {
        res.status(200).json({
            status: "success",
            data: {
                threshold_jarang_hadir: 50,
                threshold_kehadiran_ganda: 10,
                warning: "Table 'system_settings' is missing. Using default values."
            }
        });
    }
});

/**
 * @desc    Memperbarui konfigurasi threshold anomali
 * @route   PUT /api/v1/anomali/settings
 * @access  Private (Admin)
 */
exports.updateAnomalySettings = asyncHandler(async (req, res) => {
    const { threshold_jarang_hadir, threshold_kehadiran_ganda } = req.body;

    try {
        if (threshold_jarang_hadir !== undefined) {
            const val = parseInt(threshold_jarang_hadir);
            if (isNaN(val) || val < 0 || val > 100) {
                return res.status(400).json({
                    status: "error",
                    message: "Ambang batas jarang hadir harus berupa angka antara 0 dan 100"
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
                    message: "Ambang batas kehadiran ganda harus berupa angka antara 0 dan 100"
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
            message: "Konfigurasi ambang batas anomali berhasil diperbarui"
        });
    } catch (error) {
        console.error("Failed to update anomaly settings:", error.message);
        return res.status(500).json({
            status: "error",
            message: GENERIC_SERVER_ERROR
        });
    }
});

// The AnomalyAPI circuit breaker (state for monitoring; tests reset it between cases)
exports.anomalyApiBreaker = anomalyApiBreaker;
