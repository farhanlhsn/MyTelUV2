/**
 * Unit Testing - Anomaly Controller
 * 
 * @author MyTelUV2 Team
 * @date 2026-05-18
 */

jest.mock('../utils/prisma', () => ({
    kelas: { findUnique: jest.fn() },
    pesertaKelas: { findMany: jest.fn() },
    absensi: { findMany: jest.fn() },
    sesiAbsensi: { findMany: jest.fn(), count: jest.fn() },
    laporanAnomali: { findFirst: jest.fn(), findMany: jest.fn(), count: jest.fn(), updateMany: jest.fn(), createMany: jest.fn(), update: jest.fn() },
    systemSetting: { findUnique: jest.fn(), upsert: jest.fn() },
    $transaction: jest.fn(),
    $queryRaw: jest.fn(),
}));

// The Python anomaly service is called through the dedicated client (utils/pythonClient), not the global axios
jest.mock('../utils/pythonClient', () => ({ pythonClient: { post: jest.fn() } }));

const prisma = require('../utils/prisma');
const { pythonClient } = require('../utils/pythonClient');
const anomaliController = require('../controllers/anomaliController');
const { globalAnomalyQueue } = require('../utils/TaskQueue');

const POLA_WAKTU_WARNING = 'Layanan analisis pola waktu tidak tersedia';

// $transaction: the batch of reads (array form) resolves to `reads`; the save (callback form) runs
// against the same mock client, with `inTransaction` set while the callback runs
let inTransaction = false;
const mockTransactions = (reads) => prisma.$transaction.mockImplementation(async (arg) => {
    if (typeof arg !== 'function') return reads;
    inTransaction = true;
    try {
        return await arg(prisma);
    } finally {
        inTransaction = false;
    }
});

// In-memory laporan_anomali table behind findMany/updateMany/createMany; every write records
// whether it ran inside the save transaction
const fakeLaporanTable = (rows = []) => {
    const table = rows.map((r) => ({ deletedAt: null, catatan_dosen: null, deskripsi: null, confidence: null, ...r }));
    const writes = [];
    let nextId = 100;
    const matches = (row, where = {}) => Object.entries(where).every(([field, cond]) => {
        if (cond && typeof cond === 'object' && Array.isArray(cond.in)) return cond.in.includes(row[field]);
        return row[field] === cond;
    });

    prisma.laporanAnomali.findMany.mockImplementation(async ({ where } = {}) =>
        table.filter((r) => matches(r, where)).map((r) => ({ ...r })));
    prisma.laporanAnomali.updateMany.mockImplementation(async ({ where, data }) => {
        writes.push({ op: 'updateMany', where, data, inTransaction });
        const hit = table.filter((r) => matches(r, where));
        hit.forEach((r) => Object.assign(r, data));
        return { count: hit.length };
    });
    prisma.laporanAnomali.createMany.mockImplementation(async ({ data }) => {
        writes.push({ op: 'createMany', data, inTransaction });
        data.forEach((d) => table.push({ id_anomali: nextId++, deletedAt: null, catatan_dosen: null, ...d }));
        return { count: data.length };
    });
    return { table, writes };
};

// The breaker is a module singleton: start every test with a closed circuit and no counted failures
const resetAnomalyBreaker = () => Object.assign(anomaliController.anomalyApiBreaker || {}, {
    state: 'CLOSED', failureCount: 0, successCount: 0, lastStateChanged: Date.now()
});

const createMockReq = (body = {}, user = { id_user: 1, role: 'DOSEN' }, params = {}, query = {}, headers = {}) => ({
    body,
    user,
    params,
    query,
    headers
});

const createMockRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

describe('Anomaly Controller Tests', () => {

    beforeEach(() => {
        jest.clearAllMocks();
        // reset (not only clear): no queued once-values or fake tables leak between tests
        Object.values(prisma.laporanAnomali).forEach((fn) => fn.mockReset());
        prisma.$transaction.mockReset();
        prisma.laporanAnomali.findMany.mockResolvedValue([]);
        pythonClient.post.mockReset();
        resetAnomalyBreaker();
    });

    describe('analyzeKelasAttendance', () => {
        test('should fail if class is not found', async () => {
            const req = createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 999 });
            const res = createMockRes();

            prisma.kelas.findUnique.mockResolvedValue(null);

            await anomaliController.analyzeKelasAttendance(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                message: 'Kelas tidak ditemukan'
            }));
        });

        test('should fail if user is unauthorized Dosen', async () => {
            const req = createMockReq({}, { id_user: 2, role: 'DOSEN' }, { id_kelas: 1 });
            const res = createMockRes();

            prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1 });

            await anomaliController.analyzeKelasAttendance(req, res);

            expect(res.status).toHaveBeenCalledWith(403);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                message: 'Anda tidak memiliki akses untuk menganalisis kelas ini'
            }));
        });

        test('should analyze class attendance successfully', async () => {
            const req = createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 });
            const res = createMockRes();

            prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1 });
            prisma.systemSetting.findUnique.mockResolvedValue(null); // Will fallback to default thresholds
            
            const mockPeserta = [
                { mahasiswa: { id_user: 10, nama: 'Student A' } },
                { mahasiswa: { id_user: 11, nama: 'Student B' } }
            ];
            const mockAbsensi = [
                { id_user: 10, id_sesi_absensi: 1, createdAt: new Date() }
            ];
            // A session that has ended (only ended or closed sessions count)
            const mockSesi = [
                { id_sesi_absensi: 1, mulai: new Date(Date.now() - 3 * 60 * 60 * 1000), selesai: new Date(Date.now() - 60 * 60 * 1000), status: false }
            ];

            mockTransactions([mockPeserta, mockAbsensi, mockSesi]);
            // An OPEN report of Student A, who now attends: replaced (soft-deleted)
            fakeLaporanTable([{ id_anomali: 1, id_user: 10, id_kelas: 1, type_anomali: 'TIDAK_HADIR_BERULANG', status: 'OPEN' }]);

            await anomaliController.analyzeKelasAttendance(req, res);

            expect(prisma.$transaction).toHaveBeenCalled();
            expect(prisma.laporanAnomali.updateMany).toHaveBeenCalled();
            expect(prisma.laporanAnomali.createMany).toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('never reports KEHADIRAN_GANDA (impossible under uq_absensi_user_sesi)', async () => {
            const req = createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 });
            const res = createMockRes();
            prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1 });
            prisma.systemSetting.findUnique.mockResolvedValue(null);
            const sesi = { id_sesi_absensi: 1, mulai: new Date('2026-09-02T01:00:00Z'), selesai: new Date('2026-09-02T03:00:00Z'), status: false };
            // Two rows for one session (cannot exist in the database any more)
            mockTransactions([
                [{ mahasiswa: { id_user: 10, nama: 'Student A' } }],
                [{ id_user: 10, id_sesi_absensi: 1, status: 'HADIR' }, { id_user: 10, id_sesi_absensi: 1, status: 'HADIR' }],
                [sesi]
            ]);
            fakeLaporanTable();

            await anomaliController.analyzeKelasAttendance(req, res);

            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json.mock.calls[0][0].data.map((a) => a.type_anomali)).not.toContain('KEHADIRAN_GANDA');
        });

        /**
         * TIDAK_HADIR_BERULANG follows the attendance statuses: HADIR/TELAT present, IZIN/SAKIT excused
         * (out of the denominator), ALPHA or no record absent; only closed sessions on/after enrollment count
         */
        describe('TIDAK_HADIR_BERULANG uses attendance statuses', () => {
            const closed = (id, day) => ({
                id_sesi_absensi: id,
                status: false,
                mulai: new Date(`2026-09-${day}T01:00:00Z`),
                selesai: new Date(`2026-09-${day}T03:00:00Z`)
            });
            const SESSIONS = [closed(1, '02'), closed(2, '09'), closed(3, '16'), closed(4, '23')];
            const peserta = (id, createdAt = new Date('2026-09-01T00:00:00Z')) => ({
                id_mahasiswa: id, createdAt, mahasiswa: { id_user: id, nama: `Mahasiswa ${id}` }
            });
            const row = (id_user, id_sesi_absensi, status) => ({
                id_user, id_sesi_absensi, status, createdAt: new Date('2026-09-02T01:05:00Z')
            });

            const analyze = async (pesertaList, absensiList, sesiList = SESSIONS, thresholdSetting = null) => {
                prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1, nama_kelas: 'A' });
                prisma.systemSetting.findUnique.mockResolvedValue(thresholdSetting); // null: default threshold 50%
                mockTransactions([pesertaList, absensiList, sesiList]);
                fakeLaporanTable();

                const res = createMockRes();
                await anomaliController.analyzeKelasAttendance(
                    createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 }), res
                );
                expect(res.status).toHaveBeenCalledWith(200);
                return res.json.mock.calls[0][0].data.filter((a) => a.type_anomali === 'TIDAK_HADIR_BERULANG');
            };

            test('the attendance query reads each record status', async () => {
                await analyze([peserta(10)], []);

                const [sql] = prisma.$queryRaw.mock.calls[0];
                expect(sql.join('?')).toMatch(/status/);
            });

            test('ALPHA records set by a dosen are not attendance', async () => {
                // 1 present of 4: 25%, although the student has 3 records
                const anomalies = await analyze([peserta(10)], [row(10, 1, 'ALPHA'), row(10, 2, 'ALPHA'), row(10, 3, 'HADIR')]);

                expect(anomalies).toHaveLength(1);
                expect(anomalies[0]).toMatchObject({ id_user: 10 });
                expect(anomalies[0].description).toContain('Kehadiran rendah: 25%');
            });

            test('IZIN/SAKIT leave the denominator; TELAT is present', async () => {
                const anomalies = await analyze([peserta(10), peserta(11)], [
                    // 1 present of 4 sessions minus 1 excused: 33%
                    row(10, 1, 'HADIR'), row(10, 2, 'IZIN'), row(10, 3, 'ALPHA'), row(10, 4, 'ALPHA'),
                    // 2 present of 4 minus 2 excused: 100% (50%, an anomaly, if excused counted as absent)
                    row(11, 1, 'HADIR'), row(11, 2, 'TELAT'), row(11, 3, 'IZIN'), row(11, 4, 'SAKIT')
                ]);

                expect(anomalies.map((a) => a.id_user)).toEqual([10]);
                expect(anomalies[0].description).toContain('Kehadiran rendah: 33%');
            });

            test('only closed sessions held on/after the enrollment count', async () => {
                const running = {
                    id_sesi_absensi: 5,
                    status: true,
                    mulai: new Date(Date.now() - 60 * 60 * 1000),
                    selesai: new Date(Date.now() + 60 * 60 * 1000)
                };
                // Enrolled after sessions 1 and 2; present at 3 and 4; session 5 still running: 100%
                const anomalies = await analyze(
                    [peserta(10, new Date('2026-09-10T00:00:00Z'))],
                    [row(10, 3, 'HADIR'), row(10, 4, 'TELAT')],
                    [...SESSIONS, running]
                );

                expect(anomalies).toEqual([]);
            });

            test('a student with nothing to count yet is not flagged', async () => {
                const anomalies = await analyze([peserta(10, new Date('2026-09-30T00:00:00Z'))], []);

                expect(anomalies).toEqual([]);
            });

            test('nothing to count is never an anomaly, even with a 100% threshold', async () => {
                const anomalies = await analyze(
                    // 10: enrolled after every session; 11: excused at every session
                    [peserta(10, new Date('2026-09-30T00:00:00Z')), peserta(11)],
                    [row(11, 1, 'IZIN'), row(11, 2, 'SAKIT'), row(11, 3, 'IZIN'), row(11, 4, 'SAKIT')],
                    SESSIONS,
                    { key: 'anomaly_threshold_jarang_hadir', value: '100' }
                );

                expect(anomalies).toEqual([]);
            });
        });

        /**
         * Re-analysis replaces only OPEN reports. A REVIEWED/RESOLVED report (with the dosen's catatan)
         * is never changed or deleted. It blocks a new OPEN report with the same (id_user, id_kelas, type)
         * while there is no new evidence: reviewed (updatedAt) at/after the end of the student's latest
         * countable session. `data` holds only the anomalies that are active OPEN reports after saving.
         */
        describe('re-analysis keeps REVIEWED/RESOLVED reports', () => {
            // after the end of the latest session (2026-09-09T03:00Z) / between the two sessions
            const AFTER_LATEST_SESSION = new Date('2026-09-10T00:00:00Z');
            const BEFORE_LATEST_SESSION = new Date('2026-09-05T00:00:00Z');
            const closed = (id, day) => ({
                id_sesi_absensi: id, status: false,
                mulai: new Date(`2026-09-${day}T01:00:00Z`), selesai: new Date(`2026-09-${day}T03:00:00Z`)
            });
            const SESSIONS = [closed(1, '02'), closed(2, '09')];
            const enrolled = new Date('2026-09-01T00:00:00Z');
            const PESERTA = [10, 11, 12].map((id) => ({
                id_mahasiswa: id, createdAt: enrolled, mahasiswa: { id_user: id, nama: `Mahasiswa ${id}` }
            }));
            // 10 and 11 never attend (TIDAK_HADIR_BERULANG); 12 attends both sessions
            const ABSENSI = [
                { id_user: 12, id_sesi_absensi: 1, status: 'HADIR' },
                { id_user: 12, id_sesi_absensi: 2, status: 'HADIR' }
            ];

            const reanalyze = async (existingReports) => {
                prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1, nama_kelas: 'A' });
                prisma.systemSetting.findUnique.mockResolvedValue(null);
                mockTransactions([PESERTA, ABSENSI, SESSIONS]);
                const fake = fakeLaporanTable(existingReports);

                const res = createMockRes();
                await anomaliController.analyzeKelasAttendance(
                    createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 }), res
                );
                expect(res.status).toHaveBeenCalledWith(200);
                return { ...fake, res, body: res.json.mock.calls[0][0] };
            };
            const active = (table, id_user, type_anomali) =>
                table.filter((r) => r.id_user === id_user && r.type_anomali === type_anomali && r.deletedAt === null);

            test('a RESOLVED report reviewed after the latest session keeps its status and catatan, and no OPEN duplicate is added', async () => {
                const resolved = {
                    id_anomali: 1, id_user: 10, id_kelas: 1, type_anomali: 'TIDAK_HADIR_BERULANG', status: 'RESOLVED',
                    catatan_dosen: 'Sudah konfirmasi: sakit, ada surat dokter', deskripsi: 'Kehadiran rendah: 0%', confidence: 1,
                    updatedAt: AFTER_LATEST_SESSION
                };
                const { table } = await reanalyze([resolved]);

                expect(active(table, 10, 'TIDAK_HADIR_BERULANG')).toEqual([{ ...resolved, deletedAt: null }]);
            });

            test('a review that a newer countable session outdates does not block: new OPEN report, reviewed one untouched', async () => {
                const resolved = {
                    id_anomali: 1, id_user: 10, id_kelas: 1, type_anomali: 'TIDAK_HADIR_BERULANG', status: 'RESOLVED',
                    catatan_dosen: 'Sudah ditegur', deskripsi: 'Kehadiran rendah: 0%', confidence: 1,
                    // reviewed after session 1; session 2 (2026-09-09) is new evidence, still absent
                    updatedAt: BEFORE_LATEST_SESSION
                };
                const { table, body } = await reanalyze([resolved]);

                const reports = active(table, 10, 'TIDAK_HADIR_BERULANG');
                expect(reports).toHaveLength(2);
                expect(reports).toContainEqual({ ...resolved, deletedAt: null });
                expect(reports).toContainEqual(expect.objectContaining({ status: 'OPEN', id_kelas: 1, catatan_dosen: null }));
                expect(body.data.map((a) => a.id_user)).toContain(10);
            });

            test('the response lists only active OPEN anomalies; ones a review blocks come back in ditinjau', async () => {
                const { body } = await reanalyze([{
                    id_anomali: 1, id_user: 10, id_kelas: 1, type_anomali: 'TIDAK_HADIR_BERULANG', status: 'RESOLVED',
                    catatan_dosen: 'x', updatedAt: AFTER_LATEST_SESSION
                }]);

                // 10 and 11 are both detected; 10 is covered by the review
                expect(body.data.map((a) => a.id_user)).toEqual([11]);
                expect(body.data[0]).not.toHaveProperty('sudah_ditinjau');
                expect(body.ditinjau).toEqual([expect.objectContaining({
                    id_user: 10, type_anomali: 'TIDAK_HADIR_BERULANG', sudah_ditinjau: true
                })]);
                expect(body.message).toBe('Analisis selesai. Ditemukan 1 potensi anomali.');
            });

            test('nothing new and everything reviewed: no "normal" message, no active anomalies', async () => {
                const reviewedAfter = (id_anomali, id_user) => ({
                    id_anomali, id_user, id_kelas: 1, type_anomali: 'TIDAK_HADIR_BERULANG', status: 'REVIEWED', updatedAt: AFTER_LATEST_SESSION
                });
                const { body } = await reanalyze([reviewedAfter(1, 10), reviewedAfter(2, 11)]);

                expect(body.data).toEqual([]);
                expect(body.ditinjau.map((a) => a.id_user)).toEqual([10, 11]);
                expect(body.message).toBe('Analisis selesai. Tidak ada anomali baru (2 anomali sudah ditinjau).');
            });

            test('an OPEN report a dosen reviews while the analysis runs is not overwritten and is reported as ditinjau', async () => {
                const { table, body } = await (async () => {
                    prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1, nama_kelas: 'A' });
                    prisma.systemSetting.findUnique.mockResolvedValue(null);
                    mockTransactions([PESERTA, ABSENSI, SESSIONS]);
                    // the table already has it REVIEWED, the analysis still read it as OPEN
                    const fake = fakeLaporanTable([{
                        id_anomali: 3, id_user: 11, id_kelas: 1, type_anomali: 'TIDAK_HADIR_BERULANG', status: 'REVIEWED',
                        catatan_dosen: 'Baru saja ditinjau', deskripsi: 'lama', updatedAt: AFTER_LATEST_SESSION
                    }]);
                    prisma.laporanAnomali.findMany.mockResolvedValueOnce([
                        { id_anomali: 3, id_user: 11, type_anomali: 'TIDAK_HADIR_BERULANG', status: 'OPEN', updatedAt: BEFORE_LATEST_SESSION }
                    ]);
                    const res = createMockRes();
                    await anomaliController.analyzeKelasAttendance(createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 }), res);
                    return { ...fake, body: res.json.mock.calls[0][0] };
                })();

                expect(table.find((r) => r.id_anomali === 3)).toMatchObject({ status: 'REVIEWED', deskripsi: 'lama', deletedAt: null });
                expect(body.data.map((a) => a.id_user)).toEqual([10]);
                expect(body.ditinjau.map((a) => a.id_user)).toEqual([11]);
            });

            test('a REVIEWED report that is no longer detected is kept', async () => {
                const reviewed = {
                    id_anomali: 2, id_user: 12, id_kelas: 1, type_anomali: 'TIDAK_HADIR_BERULANG', status: 'REVIEWED',
                    catatan_dosen: 'Dipantau', deskripsi: 'Kehadiran rendah: 0%', confidence: 1, updatedAt: BEFORE_LATEST_SESSION
                };
                const { table } = await reanalyze([reviewed]);

                expect(active(table, 12, 'TIDAK_HADIR_BERULANG')).toEqual([{ ...reviewed, deletedAt: null }]);
            });

            test('OPEN reports are replaced: refreshed when detected again, removed when not, new ones created', async () => {
                const { table } = await reanalyze([
                    // still detected: refreshed in place (same id, catatan kept)
                    { id_anomali: 3, id_user: 11, id_kelas: 1, type_anomali: 'TIDAK_HADIR_BERULANG', status: 'OPEN', catatan_dosen: 'Hubungi wali', deskripsi: 'lama', confidence: 0.2 },
                    // no longer detected: soft-deleted
                    { id_anomali: 4, id_user: 12, id_kelas: 1, type_anomali: 'TIDAK_HADIR_BERULANG', status: 'OPEN' }
                ]);

                expect(active(table, 11, 'TIDAK_HADIR_BERULANG')).toEqual([expect.objectContaining({
                    id_anomali: 3, status: 'OPEN', catatan_dosen: 'Hubungi wali', deskripsi: 'Kehadiran rendah: 0% (Ambang batas: 50%)', confidence: 1
                })]);
                expect(active(table, 12, 'TIDAK_HADIR_BERULANG')).toEqual([]);
                expect(table.find((r) => r.id_anomali === 4).deletedAt).toEqual(expect.any(Date));
                expect(active(table, 10, 'TIDAK_HADIR_BERULANG')).toEqual([expect.objectContaining({ status: 'OPEN', id_kelas: 1 })]);
            });

            test('every write runs inside one transaction and only touches OPEN reports', async () => {
                const { writes } = await reanalyze([
                    { id_anomali: 1, id_user: 10, id_kelas: 1, type_anomali: 'TIDAK_HADIR_BERULANG', status: 'RESOLVED', catatan_dosen: 'x', updatedAt: BEFORE_LATEST_SESSION },
                    { id_anomali: 4, id_user: 12, id_kelas: 1, type_anomali: 'TIDAK_HADIR_BERULANG', status: 'OPEN' }
                ]);

                expect(writes.length).toBeGreaterThan(0);
                expect(writes.every((w) => w.inTransaction)).toBe(true);
                // updates are guarded by status OPEN, so a report a dosen just reviewed is never overwritten
                writes.filter((w) => w.op === 'updateMany').forEach((w) => expect(w.where.status).toBe('OPEN'));
                expect(prisma.laporanAnomali.update).not.toHaveBeenCalled();
            });
        });

        /**
         * POLA_WAKTU_TIDAK_WAJAR comes from the Python anomaly service (IsolationForest on check-in times).
         * Only real check-ins (HADIR/TELAT with a check-in, not entered by a dosen) of countable sessions are
         * sent; every other rule result of the service is ignored. When the service is unavailable the rule
         * is skipped and the response carries a warning.
         */
        describe('POLA_WAKTU_TIDAK_WAJAR via the Python anomaly service', () => {
            const closed = (id, day) => ({
                id_sesi_absensi: id, status: false,
                mulai: new Date(`2026-09-${day}T01:00:00Z`), selesai: new Date(`2026-09-${day}T03:00:00Z`)
            });
            const RUNNING = { id_sesi_absensi: 9, status: true, mulai: new Date(Date.now() - 60 * 60 * 1000), selesai: new Date(Date.now() + 60 * 60 * 1000) };
            const SESSIONS = [closed(1, '02'), closed(2, '09'), closed(3, '16'), RUNNING];
            const enrolled = new Date('2026-09-01T00:00:00Z');
            const PESERTA = [10, 11, 12].map((id) => ({
                id_mahasiswa: id, createdAt: enrolled, mahasiswa: { id_user: id, nama: `Mahasiswa ${id}` }
            }));
            const checkIn = (id_user, id_sesi_absensi, status, createdAt) => ({ id_user, id_sesi_absensi, status, createdAt: new Date(createdAt), check_in: true });
            // a status the dosen entered without a check-in (no location): createdAt is not a check-in time
            const byDosen = (id_user, id_sesi_absensi, status) => ({ id_user, id_sesi_absensi, status, createdAt: new Date('2026-09-20T09:00:00Z'), check_in: false });
            const ABSENSI = [
                // 10: three real check-ins (the TELAT ones near the end of the session) -> 100%
                checkIn(10, 1, 'HADIR', '2026-09-02T01:05:00Z'),
                checkIn(10, 2, 'TELAT', '2026-09-09T02:50:00Z'),
                checkIn(10, 3, 'TELAT', '2026-09-16T02:55:00Z'),
                // 11: a check-in, a check-in the dosen turned into ALPHA, an IZIN -> 1 of 2 = 50%
                checkIn(11, 1, 'HADIR', '2026-09-02T01:10:00Z'),
                checkIn(11, 2, 'ALPHA', '2026-09-09T01:10:00Z'),
                byDosen(11, 3, 'IZIN'),
                // 12: HADIR entered by the dosen, then two check-ins -> 100%
                byDosen(12, 1, 'HADIR'),
                checkIn(12, 2, 'HADIR', '2026-09-09T01:02:00Z'),
                checkIn(12, 3, 'HADIR', '2026-09-16T01:03:00Z'),
                // check-in into the running session: not countable yet
                checkIn(10, 9, 'HADIR', new Date().toISOString())
            ];

            const ORIGINAL_KEY = process.env.ANOMALY_API_KEY;
            beforeEach(() => { process.env.ANOMALY_API_KEY = 'anomaly-test-key'; });
            afterEach(() => {
                if (ORIGINAL_KEY === undefined) delete process.env.ANOMALY_API_KEY;
                else process.env.ANOMALY_API_KEY = ORIGINAL_KEY;
            });

            const analyze = async (absensiList = ABSENSI, existingReports = []) => {
                prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1, nama_kelas: 'A' });
                prisma.systemSetting.findUnique.mockResolvedValue(null);
                mockTransactions([PESERTA, absensiList, SESSIONS]);
                const fake = fakeLaporanTable(existingReports);
                const res = createMockRes();
                await anomaliController.analyzeKelasAttendance(
                    createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 }), res
                );
                expect(res.status).toHaveBeenCalledWith(200);
                return { body: res.json.mock.calls[0][0], ...fake };
            };

            test('sends the real check-ins of countable sessions with the API key and keeps only POLA_WAKTU_TIDAK_WAJAR', async () => {
                pythonClient.post.mockResolvedValueOnce({
                    data: {
                        success: true,
                        count: 4,
                        anomalies: [
                            { id_user: 10, type_anomali: 'POLA_WAKTU_TIDAK_WAJAR', confidence: 0.67, description: 'Pola check-in tidak wajar (2/3)' },
                            { id_user: 10, type_anomali: 'KEHADIRAN_GANDA', confidence: 1, description: 'ganda' },
                            { id_user: 11, type_anomali: 'TIDAK_HADIR_BERULANG', confidence: 1, description: 'status-blind' },
                            { id_user: 999, type_anomali: 'POLA_WAKTU_TIDAK_WAJAR', confidence: 1, description: 'bukan peserta' }
                        ]
                    }
                });

                const { body, table } = await analyze();

                expect(pythonClient.post).toHaveBeenCalledTimes(1);
                const [url, payload, config] = pythonClient.post.mock.calls[0];
                expect(url).toMatch(/\/detect-anomalies$/);
                expect(config.headers['X-API-Key']).toBe('anomaly-test-key');
                expect(config.timeout).toEqual(expect.any(Number));
                expect(payload.students).toEqual([{ id_user: 10 }, { id_user: 11 }, { id_user: 12 }]);
                expect(payload.attendance).toEqual([
                    { id_user: 10, id_sesi: 1, timestamp: '2026-09-02T01:05:00.000Z' },
                    { id_user: 10, id_sesi: 2, timestamp: '2026-09-09T02:50:00.000Z' },
                    { id_user: 10, id_sesi: 3, timestamp: '2026-09-16T02:55:00.000Z' },
                    { id_user: 11, id_sesi: 1, timestamp: '2026-09-02T01:10:00.000Z' },
                    { id_user: 12, id_sesi: 2, timestamp: '2026-09-09T01:02:00.000Z' },
                    { id_user: 12, id_sesi: 3, timestamp: '2026-09-16T01:03:00.000Z' }
                ]);
                expect(payload.sessions).toEqual([
                    { id_sesi: 1, mulai: '2026-09-02T01:00:00.000Z', selesai: '2026-09-02T03:00:00.000Z' },
                    { id_sesi: 2, mulai: '2026-09-09T01:00:00.000Z', selesai: '2026-09-09T03:00:00.000Z' },
                    { id_sesi: 3, mulai: '2026-09-16T01:00:00.000Z', selesai: '2026-09-16T03:00:00.000Z' }
                ]);
                expect(payload.total_sessions).toBe(3);
                // the service's own (status-blind) absence rule must never fire
                expect(payload.threshold).toBe(0);

                expect(body).not.toHaveProperty('warnings');
                const pola = body.data.filter((a) => a.type_anomali === 'POLA_WAKTU_TIDAK_WAJAR');
                expect(pola).toEqual([{
                    id_user: 10, nama: 'Mahasiswa 10', type_anomali: 'POLA_WAKTU_TIDAK_WAJAR',
                    confidence: 0.67, description: 'Pola check-in tidak wajar (2/3)'
                }]);
                expect(body.data.map((a) => a.type_anomali)).not.toContain('KEHADIRAN_GANDA');
                // 11's status-aware rate is 1/2 = 50% -> flagged by the backend rule, not by the service result
                expect(body.data.filter((a) => a.id_user === 11).map((a) => a.description)).toEqual(['Kehadiran rendah: 50% (Ambang batas: 50%)']);
                expect(table.filter((r) => r.type_anomali === 'POLA_WAKTU_TIDAK_WAJAR').map((r) => r.id_user)).toEqual([10]);
            });

            test('a student already flagged TIDAK_HADIR_BERULANG gets no POLA_WAKTU_TIDAK_WAJAR report', async () => {
                pythonClient.post.mockResolvedValueOnce({
                    data: { success: true, count: 1, anomalies: [{ id_user: 11, type_anomali: 'POLA_WAKTU_TIDAK_WAJAR', confidence: 1, description: 'x' }] }
                });

                const { body } = await analyze();

                expect(body.data.filter((a) => a.id_user === 11).map((a) => a.type_anomali)).toEqual(['TIDAK_HADIR_BERULANG']);
            });

            test('service failure: 200 with the other rules and a warning', async () => {
                const errorSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
                const failure = Object.assign(new Error('connect ECONNREFUSED anomaly:5003'), { code: 'ECONNREFUSED' });
                pythonClient.post.mockRejectedValueOnce(failure);

                try {
                    const { body, table } = await analyze();

                    expect(body.status).toBe('success');
                    expect(body.warnings).toEqual([POLA_WAKTU_WARNING]);
                    expect(body.data.map((a) => a.type_anomali)).toEqual(['TIDAK_HADIR_BERULANG']);
                    expect(table.map((r) => r.type_anomali)).toEqual(['TIDAK_HADIR_BERULANG']);
                    expect(JSON.stringify(body)).not.toMatch(/ECONNREFUSED/);
                } finally {
                    errorSpy.mockRestore();
                }
            });

            test('service outage keeps the OPEN POLA_WAKTU_TIDAK_WAJAR reports as they are (the rule was not evaluated)', async () => {
                const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
                const openPola = {
                    id_anomali: 7, id_user: 10, id_kelas: 1, type_anomali: 'POLA_WAKTU_TIDAK_WAJAR', status: 'OPEN',
                    catatan_dosen: 'Cek rekaman CCTV', deskripsi: 'Pola check-in tidak wajar (2/3)', confidence: 0.67
                };
                pythonClient.post.mockRejectedValueOnce(Object.assign(new Error('timeout of 10000ms exceeded'), { code: 'ECONNABORTED' }));

                try {
                    const { body, table } = await analyze(ABSENSI, [openPola]);

                    expect(body.warnings).toEqual([POLA_WAKTU_WARNING]);
                    expect(table.find((r) => r.id_anomali === 7)).toEqual({ ...openPola, deletedAt: null });
                } finally {
                    warnSpy.mockRestore();
                }
            });

            test('when the service answers, an OPEN POLA_WAKTU_TIDAK_WAJAR report it no longer finds is replaced', async () => {
                pythonClient.post.mockResolvedValueOnce({ data: { success: true, count: 0, anomalies: [] } });

                const { table } = await analyze(ABSENSI, [{
                    id_anomali: 7, id_user: 10, id_kelas: 1, type_anomali: 'POLA_WAKTU_TIDAK_WAJAR', status: 'OPEN'
                }]);

                expect(table.find((r) => r.id_anomali === 7).deletedAt).toEqual(expect.any(Date));
            });

            test('an invalid service response counts as a failure', async () => {
                const errorSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
                pythonClient.post.mockResolvedValueOnce({ data: { success: false, error: 'Internal server error' } });

                try {
                    const { body } = await analyze();

                    expect(body.warnings).toEqual([POLA_WAKTU_WARNING]);
                } finally {
                    errorSpy.mockRestore();
                }
            });

            test('open circuit breaker: the service is not called and the response carries the warning', async () => {
                const errorSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
                anomaliController.anomalyApiBreaker.forceState('OPEN');

                try {
                    const { body } = await analyze();

                    expect(pythonClient.post).not.toHaveBeenCalled();
                    expect(body.warnings).toEqual([POLA_WAKTU_WARNING]);
                } finally {
                    errorSpy.mockRestore();
                }
            });

            test('without a student with two check-ins the service is not called', async () => {
                const { body } = await analyze([checkIn(10, 1, 'HADIR', '2026-09-02T01:05:00Z')]);

                expect(pythonClient.post).not.toHaveBeenCalled();
                expect(body).not.toHaveProperty('warnings');
            });
        });
    });

    describe('getLaporanAnomali', () => {
        test('is paginated (limit capped at 100) and selects the NIM', async () => {
            prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1 });
            prisma.$transaction.mockResolvedValueOnce([[{ id_anomali: 1 }], 250]);
            const res = createMockRes();

            await anomaliController.getLaporanAnomali(
                createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: '1' }, { page: '2', limit: '1000' }), res
            );

            expect(res.status).toHaveBeenCalledWith(200);
            const [findArgs] = prisma.laporanAnomali.findMany.mock.calls[0];
            expect(findArgs).toMatchObject({ where: { id_kelas: 1, deletedAt: null }, skip: 100, take: 100 });
            expect(findArgs.include.user.select).toMatchObject({ nim_nip: true });
            expect(prisma.laporanAnomali.count).toHaveBeenCalledWith({ where: { id_kelas: 1, deletedAt: null } });
            expect(res.json).toHaveBeenCalledWith({
                status: 'success',
                data: [{ id_anomali: 1 }],
                pagination: expect.objectContaining({ total: 250, page: 2, limit: 100, totalPages: 3 })
            });
        });
    });

    describe('updateLaporanAnomali', () => {
        test('should fail if status is invalid', async () => {
            const req = createMockReq({ status: 'INVALID' }, { id_user: 1, role: 'DOSEN' }, { id_anomali: 1 });
            const res = createMockRes();

            await anomaliController.updateLaporanAnomali(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
        });

        test('should fail if anomaly report not found', async () => {
            const req = createMockReq({ status: 'REVIEWED' }, { id_user: 1, role: 'DOSEN' }, { id_anomali: 999 });
            const res = createMockRes();

            prisma.laporanAnomali.findFirst.mockResolvedValue(null);

            await anomaliController.updateLaporanAnomali(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
        });

        test('should update status and notes successfully', async () => {
            const req = createMockReq({ status: 'RESOLVED', catatan_dosen: 'Verified medical checkup' }, { id_user: 1, role: 'DOSEN' }, { id_anomali: 1 });
            const res = createMockRes();

            const mockLaporan = {
                id_anomali: 1,
                id_kelas: 10,
                kelas: { id_dosen: 1 }
            };

            prisma.laporanAnomali.findFirst.mockResolvedValue(mockLaporan);
            prisma.laporanAnomali.update.mockResolvedValue({ id_anomali: 1, status: 'RESOLVED', catatan_dosen: 'Verified medical checkup' });

            await anomaliController.updateLaporanAnomali(req, res);

            expect(prisma.laporanAnomali.update).toHaveBeenCalledWith(expect.objectContaining({
                where: { id_anomali: 1 },
                data: expect.objectContaining({
                    status: 'RESOLVED',
                    catatan_dosen: 'Verified medical checkup'
                })
            }));
            expect(res.status).toHaveBeenCalledWith(200);
        });
    });

    describe('5xx responses never leak error.message', () => {
        const leaky = new Error('connect ECONNREFUSED db.internal.example:5432 password=hunter2');
        let errorSpy;

        beforeEach(() => {
            errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
        });

        afterEach(() => errorSpy.mockRestore());

        const expectGeneric500 = (res) => {
            expect(res.status).toHaveBeenCalledWith(500);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Terjadi kesalahan pada server'
            });
            expect(JSON.stringify(res.json.mock.calls)).not.toMatch(/ECONNREFUSED|hunter2/);
            expect(errorSpy).toHaveBeenCalled(); // the real error is logged, not returned
        };

        test('analyzeKelasAttendance (sync) when saving the analysis fails', async () => {
            const req = createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 });
            const res = createMockRes();

            prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1 });
            prisma.systemSetting.findUnique.mockResolvedValue(null);
            const reads = [[{ mahasiswa: { id_user: 10, nama: 'Student A' } }], [], []];
            // the reads succeed, the save transaction fails
            prisma.$transaction.mockImplementation(async (arg) => {
                if (typeof arg === 'function') throw leaky;
                return reads;
            });
            prisma.laporanAnomali.updateMany.mockRejectedValue(leaky);

            await anomaliController.analyzeKelasAttendance(req, res);

            expectGeneric500(res);
        });

        test('updateAnomalySettings when the database write fails', async () => {
            const req = createMockReq({ threshold_jarang_hadir: 50 }, { id_user: 1, role: 'ADMIN' });
            const res = createMockRes();
            prisma.systemSetting.upsert.mockRejectedValueOnce(leaky);

            await anomaliController.updateAnomalySettings(req, res);

            expectGeneric500(res);
        });

        test('getJobStatus replaces the raw error of a FAILED job', async () => {
            const statusSpy = jest.spyOn(globalAnomalyQueue, 'getJobStatus').mockReturnValue({
                id: 'anomaly_kelas_1_100',
                status: 'FAILED',
                progress: 100,
                ownerId: 5,
                error: leaky.message
            });
            try {
                const req = createMockReq({}, { id_user: 5, role: 'DOSEN' }, { jobId: 'anomaly_kelas_1_100' });
                const res = createMockRes();

                await anomaliController.getJobStatus(req, res);

                expect(res.status).toHaveBeenCalledWith(200);
                const { data } = res.json.mock.calls[0][0];
                expect(data.status).toBe('FAILED');
                expect(data.error).toBe('Terjadi kesalahan pada server');
                expect(JSON.stringify(data)).not.toMatch(/ECONNREFUSED|hunter2/);
            } finally {
                statusSpy.mockRestore();
            }
        });
    });

    describe('async analysis jobs: ownership', () => {
        let statusSpy;

        const job = {
            id: 'anomaly_kelas_1_100',
            status: 'COMPLETED',
            progress: 100,
            ownerId: 5,
            result: [{ id_user: 10, nama: 'Student A', type_anomali: 'TIDAK_HADIR_BERULANG' }]
        };

        afterEach(() => {
            if (statusSpy) statusSpy.mockRestore();
            statusSpy = undefined;
        });

        test('analyzeKelasAttendance (async) stores the requesting user as the job owner', async () => {
            const addJobSpy = jest.spyOn(globalAnomalyQueue, 'addJob').mockImplementation(() => ({}));
            try {
                const req = createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 }, { async: 'true' });
                const res = createMockRes();

                prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1 });
                prisma.$transaction.mockResolvedValue([[{ mahasiswa: { id_user: 10, nama: 'Student A' } }], [], []]);

                await anomaliController.analyzeKelasAttendance(req, res);

                expect(res.status).toHaveBeenCalledWith(202);
                expect(addJobSpy).toHaveBeenCalledWith(expect.any(String), expect.any(Function), 1);
            } finally {
                addJobSpy.mockRestore();
            }
        });

        test('the async job result carries the anomalies and the warnings', async () => {
            const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
            const addJobSpy = jest.spyOn(globalAnomalyQueue, 'addJob').mockImplementation(() => ({}));
            try {
                const req = createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 }, { async: 'true' });
                prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1, nama_kelas: 'A' });
                prisma.systemSetting.findUnique.mockResolvedValue(null);
                const sesi = (id) => ({ id_sesi_absensi: id, status: false, mulai: new Date(`2026-09-0${id}T01:00:00Z`), selesai: new Date(`2026-09-0${id}T03:00:00Z`) });
                const checkIn = (id) => ({ id_user: 10, id_sesi_absensi: id, status: 'HADIR', createdAt: new Date(`2026-09-0${id}T01:05:00Z`), check_in: true });
                mockTransactions([[{ mahasiswa: { id_user: 10, nama: 'Student A' } }], [checkIn(1), checkIn(2)], [sesi(1), sesi(2)]]);
                fakeLaporanTable();
                anomaliController.anomalyApiBreaker.forceState('OPEN');

                await anomaliController.analyzeKelasAttendance(req, createMockRes());
                const job = addJobSpy.mock.calls[0][1];

                await expect(job()).resolves.toEqual({ anomalies: [], ditinjau: [], warnings: [POLA_WAKTU_WARNING] });
            } finally {
                addJobSpy.mockRestore();
                warnSpy.mockRestore();
            }
        });

        test('TaskQueue.addJob records the owner on the job', async () => {
            const { TaskQueue } = require('../utils/TaskQueue');
            const queue = new TaskQueue(1);

            const info = queue.addJob('job-with-owner', async () => 'done', 7);

            // Let the queued job complete, then drain processNext's follow-up callback before teardown.
            await new Promise(resolve => setImmediate(resolve));
            await new Promise(resolve => setImmediate(resolve));

            expect(info.ownerId).toBe(7);
            expect(queue.getJobStatus('job-with-owner')).toMatchObject({ ownerId: 7, status: 'COMPLETED', result: 'done' });
            expect(queue.activeWorkers).toBe(0);
            expect(queue.queue).toHaveLength(0);
        });

        test('getJobStatus returns the job to its owner without leaking ownerId', async () => {
            statusSpy = jest.spyOn(globalAnomalyQueue, 'getJobStatus').mockReturnValue(job);
            const req = createMockReq({}, { id_user: 5, role: 'DOSEN' }, { jobId: job.id });
            const res = createMockRes();

            await anomaliController.getJobStatus(req, res);

            expect(res.status).toHaveBeenCalledWith(200);
            const payload = res.json.mock.calls[0][0];
            expect(payload.data).toMatchObject({ id: job.id, status: 'COMPLETED' });
            expect(payload.data).not.toHaveProperty('ownerId');
        });

        test('getJobStatus returns 404 for a different DOSEN', async () => {
            statusSpy = jest.spyOn(globalAnomalyQueue, 'getJobStatus').mockReturnValue(job);
            const req = createMockReq({}, { id_user: 6, role: 'DOSEN' }, { jobId: job.id });
            const res = createMockRes();

            await anomaliController.getJobStatus(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
            expect(JSON.stringify(res.json.mock.calls[0][0])).not.toContain('Student A');
        });

        test('getJobStatus lets an ADMIN read any job', async () => {
            statusSpy = jest.spyOn(globalAnomalyQueue, 'getJobStatus').mockReturnValue(job);
            const req = createMockReq({}, { id_user: 1, role: 'ADMIN' }, { jobId: job.id });
            const res = createMockRes();

            await anomaliController.getJobStatus(req, res);

            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('getJobStatus returns 404 for an unknown job', async () => {
            statusSpy = jest.spyOn(globalAnomalyQueue, 'getJobStatus').mockReturnValue(null);
            const req = createMockReq({}, { id_user: 5, role: 'DOSEN' }, { jobId: 'nope' });
            const res = createMockRes();

            await anomaliController.getJobStatus(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
        });

        test('a job without an owner is only visible to ADMIN', async () => {
            statusSpy = jest.spyOn(globalAnomalyQueue, 'getJobStatus').mockReturnValue({ ...job, ownerId: null });
            const dosenRes = createMockRes();
            await anomaliController.getJobStatus(createMockReq({}, { id_user: 5, role: 'DOSEN' }, { jobId: job.id }), dosenRes);
            expect(dosenRes.status).toHaveBeenCalledWith(404);

            const adminRes = createMockRes();
            await anomaliController.getJobStatus(createMockReq({}, { id_user: 1, role: 'ADMIN' }, { jobId: job.id }), adminRes);
            expect(adminRes.status).toHaveBeenCalledWith(200);
        });
    });
});
