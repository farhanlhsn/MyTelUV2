/**
 * Unit Testing - Akademik Controller (Partial)
 * 
 * @author MyTelUV2 Team
 * @date 2026-01-04
 */

// Mock dependencies
jest.mock('../utils/prisma', () => ({
    matakuliah: { findFirst: jest.fn(), create: jest.fn(), findMany: jest.fn(), count: jest.fn(), update: jest.fn() },
    kelas: { findFirst: jest.fn(), findMany: jest.fn(), count: jest.fn(), update: jest.fn() },
    user: { findFirst: jest.fn(), findMany: jest.fn() },
    semester: { findFirst: jest.fn() },
    pesertaKelas: {
        findFirst: jest.fn(), findMany: jest.fn(), findUnique: jest.fn(), create: jest.fn(), update: jest.fn(), count: jest.fn(),
        updateMany: jest.fn(), createMany: jest.fn()
    },
    jadwalPengganti: { findMany: jest.fn(), create: jest.fn() },
    sesiAbsensi: { findFirst: jest.fn(), findMany: jest.fn(), create: jest.fn(), count: jest.fn() },
    absensi: { findFirst: jest.fn(), findMany: jest.fn(), count: jest.fn(), groupBy: jest.fn() },
    $transaction: jest.fn(),
    $queryRaw: jest.fn(),
    $executeRaw: jest.fn(),
}));

jest.mock('../utils/akademikHelpers', () => ({
    // Session / attendance-status rules are the real ones
    ...jest.requireActual('../utils/akademikHelpers'),
    parsePagination: jest.fn().mockReturnValue({ page: 1, limit: 10, skip: 0 }),
    buildPaginationResponse: jest.fn().mockImplementation((total, page, limit) => ({ total, page, limit })),
    isDosenAuthorizedForKelas: jest.fn(),
    haversineDistance: jest.fn(),
}));

jest.mock('../utils/firebase', () => ({
    sendAbsensiNotification: jest.fn().mockResolvedValue(undefined),
    sendJadwalPenggantiNotification: jest.fn().mockResolvedValue(undefined),
}));

// Import modules
const prisma = require('../utils/prisma');
const { sendJadwalPenggantiNotification } = require('../utils/firebase');
const akademikController = require('../controllers/akademikController');

// Interactive transactions run the callback with the client itself; array transactions resolve every query
const runTransactionWithPrisma = async (arg) => (typeof arg === 'function' ? arg(prisma) : Promise.all(arg));

// Tagged-template raw calls whose SQL text contains `needle`
const rawCalls = (mockFn, needle) =>
    mockFn.mock.calls.filter(([strings]) => Array.isArray(strings) && strings.join('?').includes(needle));

// 01:30 WIB on Wednesday 14 October 2026 — still Tuesday 13 October in UTC
const AFTER_MIDNIGHT_WIB = new Date('2026-10-13T18:30:00Z');
const useFakeNow = (now) => jest.useFakeTimers({
    now,
    doNotFake: ['nextTick', 'setImmediate', 'clearImmediate', 'queueMicrotask', 'setTimeout', 'clearTimeout', 'setInterval', 'clearInterval']
});

// Helper
const createMockReq = (body = {}, user = { id_user: 1, role: 'ADMIN' }, query = {}, params = {}) => ({
    body,
    user,
    query,
    params
});

const createMockRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

describe('Akademik Controller Tests', () => {

    beforeEach(() => {
        jest.clearAllMocks();
        prisma.$transaction.mockImplementation(runTransactionWithPrisma);
    });

    afterEach(() => {
        jest.useRealTimers();
    });

    /**
     * CREATE MATAKULIAH
     */
    describe('createMatakuliah', () => {
        const validBody = { nama_matakuliah: 'Test MK', kode_matakuliah: 'IF123' };

        test('should create matakuliah successfully', async () => {
            prisma.matakuliah.findFirst.mockResolvedValue(null);
            prisma.matakuliah.create.mockResolvedValue({ id_matakuliah: 1, ...validBody });

            const req = createMockReq(validBody);
            const res = createMockRes();

            await akademikController.createMatakuliah(req, res);

            expect(prisma.matakuliah.create).toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(201);
        });

        test('should fail if kode exists', async () => {
            prisma.matakuliah.findFirst.mockResolvedValue({ id_matakuliah: 1 });
            const req = createMockReq(validBody);
            const res = createMockRes();

            await akademikController.createMatakuliah(req, res);

            expect(res.status).toHaveBeenCalledWith(409);
        });
    });

    /**
     * CREATE KELAS
     */
    describe('createKelas', () => {
        const validBody = {
            id_matakuliah: 1,
            id_dosen: 5,
            jam_mulai: '08:00:00',
            jam_berakhir: '10:00:00',
            nama_kelas: 'A',
            ruangan: '101',
            hari: 1
        };

        const mockCreateDeps = ({ conflicts = [], insertedId = 1 } = {}) => {
            prisma.semester.findFirst.mockResolvedValue({ id_semester: 1, nama_semester: 'Genap 2026/2027' });
            prisma.matakuliah.findFirst.mockResolvedValue({ id_matakuliah: 1 });
            prisma.user.findFirst.mockResolvedValue({ id_user: 5, role: 'DOSEN' });
            prisma.$queryRaw.mockReset()
                .mockResolvedValueOnce(conflicts) // conflict check
                .mockResolvedValueOnce([{ id_kelas: insertedId }]); // INSERT ... RETURNING id_kelas
            prisma.kelas.findFirst.mockReset().mockResolvedValue({ id_kelas: insertedId, kapasitas: 50 });
        };

        const insertCall = () => rawCalls(prisma.$queryRaw, 'INSERT INTO kelas')[0];

        test('should create kelas successfully', async () => {
            mockCreateDeps();

            const req = createMockReq(validBody);
            const res = createMockRes();

            await akademikController.createKelas(req, res);

            expect(insertCall()).toBeDefined();
            expect(res.status).toHaveBeenCalledWith(201);
        });

        test('returns the row it inserted (by the created id, not the latest row)', async () => {
            mockCreateDeps({ insertedId: 42 });

            const req = createMockReq(validBody);
            const res = createMockRes();

            await akademikController.createKelas(req, res);

            expect(prisma.kelas.findFirst).toHaveBeenCalledWith(expect.objectContaining({
                where: { id_kelas: 42 }
            }));
            expect(prisma.kelas.findFirst).not.toHaveBeenCalledWith(expect.objectContaining({
                orderBy: { createdAt: 'desc' }
            }));
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                data: expect.objectContaining({ id_kelas: 42 })
            }));
        });

        test('honours kapasitas from the request', async () => {
            mockCreateDeps();

            const res = createMockRes();
            await akademikController.createKelas(createMockReq({ ...validBody, kapasitas: 30 }), res);

            expect(res.status).toHaveBeenCalledWith(201);
            expect(insertCall().slice(1)).toContain(30);
        });

        test('defaults kapasitas to 50 when omitted', async () => {
            mockCreateDeps();

            await akademikController.createKelas(createMockReq(validBody), createMockRes());

            expect(insertCall().slice(1)).toContain(50);
        });

        test.each([
            ['equal to', '10:00:00', '10:00:00'],
            ['before', '10:00:00', '08:00:00']
        ])('rejects jam_berakhir %s jam_mulai with 400', async (_label, jamMulai, jamBerakhir) => {
            mockCreateDeps();

            const res = createMockRes();
            await akademikController.createKelas(createMockReq({ ...validBody, jam_mulai: jamMulai, jam_berakhir: jamBerakhir }), res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Jam berakhir harus setelah jam mulai'
            });
            expect(insertCall()).toBeUndefined();
        });

        test('compares times numerically, so 9:00:00 is before 10:00:00', async () => {
            mockCreateDeps();

            const res = createMockRes();
            await akademikController.createKelas(createMockReq({ ...validBody, jam_mulai: '9:00:00', jam_berakhir: '10:00:00' }), res);

            expect(res.status).toHaveBeenCalledWith(201);
        });

        test('rejects a hari outside 1 (Senin) .. 7 (Minggu)', async () => {
            mockCreateDeps();

            const res = createMockRes();
            await akademikController.createKelas(createMockReq({ ...validBody, hari: 8 }), res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(insertCall()).toBeUndefined();
        });

        test('the conflict check covers the dosen and the room in the same semester, and runs with the insert in one transaction', async () => {
            mockCreateDeps();

            await akademikController.createKelas(createMockReq({ ...validBody, ruangan: ' 101 ' }), createMockRes());

            const conflictCall = rawCalls(prisma.$queryRaw, 'FROM kelas')[0];
            const sql = conflictCall[0].join('?');
            expect(sql).toMatch(/id_dosen/);
            expect(sql).toMatch(/ruangan/);
            expect(sql).toMatch(/id_semester/);
            expect(conflictCall.slice(1)).toEqual(expect.arrayContaining([5, '101', 1]));
            expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function));
        });

        test('a room clash is reported in Indonesian', async () => {
            mockCreateDeps({ conflicts: [{ id_kelas: 99, nama_kelas: 'Z', id_dosen: 77, ruangan: '101' }] });

            const res = createMockRes();
            await akademikController.createKelas(createMockReq(validBody), res);

            expect(res.status).toHaveBeenCalledWith(409);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: expect.stringContaining('Ruangan')
            });
            expect(insertCall()).toBeUndefined();
        });

        test('should fail if conflict detected', async () => {
            prisma.semester.findFirst.mockResolvedValue({ id_semester: 1, nama_semester: 'Genap 2026/2027' });
            prisma.matakuliah.findFirst.mockResolvedValue({ id_matakuliah: 1 });
            prisma.user.findFirst.mockResolvedValue({ id_user: 5, role: 'DOSEN' });
            prisma.$queryRaw.mockResolvedValue([{ id_kelas: 99 }]); // Conflict found

            const req = createMockReq(validBody);
            const res = createMockRes();

            await akademikController.createKelas(req, res);

            expect(res.status).toHaveBeenCalledWith(409);
        });

        test('should fail if invali time format', async () => {
            prisma.semester.findFirst.mockResolvedValue({ id_semester: 1, nama_semester: 'Genap 2026/2027' });
            prisma.matakuliah.findFirst.mockResolvedValue({ id_matakuliah: 1 });
            prisma.user.findFirst.mockResolvedValue({ id_user: 5, role: 'DOSEN' });

            const req = createMockReq({ ...validBody, jam_mulai: 'invalid' });
            const res = createMockRes();

            await akademikController.createKelas(req, res);
            expect(res.status).toHaveBeenCalledWith(400);
        });
    });

    /**
     * DELETE MATAKULIAH
     */
    describe('deleteMatakuliah', () => {
        test('should delete matakuliah if no active kelas', async () => {
            const req = createMockReq({}, {}, {}, { id: 1 });
            const res = createMockRes();

            prisma.matakuliah.findFirst.mockResolvedValue({
                id_matakuliah: 1,
                kelas: [] // Empty
            });

            await akademikController.deleteMatakuliah(req, res);

            expect(prisma.matakuliah.update).toHaveBeenCalledWith({
                where: { id_matakuliah: 1 },
                data: expect.anything()
            });
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('should fail if has active kelas', async () => {
            const req = createMockReq({}, {}, {}, { id: 1 });
            const res = createMockRes();

            prisma.matakuliah.findFirst.mockResolvedValue({
                id_matakuliah: 1,
                kelas: [{ id_kelas: 1 }] // Has class
            });

            await akademikController.deleteMatakuliah(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
        });
    });

    /**
     * EXTRA ACADEMIC LOGIC (CAPACITY, OVERLAP, DROP DEADLINE)
     */
    describe('daftarKelas & dropKelas Checks', () => {
        beforeEach(() => {
            jest.clearAllMocks();
        });

        // The class row as read (and locked) inside the enrollment transaction
        const lockedKelas = (overrides = {}) => ({
            kapasitas: 5, hari: 1, deletedAt: null, jam_mulai: '08:00:00', jam_berakhir: '10:00:00', ...overrides
        });

        describe('Class Capacity Check (BF20)', () => {
            test('should block registration if capacity limit reached', async () => {
                prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 1, kapasitas: 5, hari: 1 });
                prisma.$queryRaw.mockReset().mockResolvedValue([lockedKelas()]);
                prisma.pesertaKelas.count.mockResolvedValue(5); // Maximum capacity reached

                const req = createMockReq({ id_kelas: 1 });
                const res = createMockRes();

                await akademikController.daftarKelas(req, res);

                expect(res.status).toHaveBeenCalledWith(400);
                expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                    status: 'error',
                    message: expect.stringContaining('Kelas sudah penuh')
                }));
            });

            test('should allow registration if capacity is still available', async () => {
                prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 1, kapasitas: 5, hari: 1 });
                prisma.pesertaKelas.count.mockResolvedValue(3); // Still available
                prisma.$queryRaw.mockReset()
                    .mockResolvedValueOnce([lockedKelas()]) // locked class row
                    .mockResolvedValueOnce([]); // No schedule conflict
                prisma.pesertaKelas.findUnique.mockResolvedValue(null); // Not already enrolled
                prisma.pesertaKelas.create.mockResolvedValue({ id_peserta_kelas: 1 });

                const req = createMockReq({ id_kelas: 1 });
                const res = createMockRes();

                await akademikController.daftarKelas(req, res);

                expect(res.status).toHaveBeenCalledWith(201);
                expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                    status: 'success'
                }));
            });

            test('compares against the kapasitas read under the row lock, not the earlier read', async () => {
                // Read before the transaction: 50; changed to 5 by an admin before the lock was taken
                prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 1, kapasitas: 50, hari: 1 });
                prisma.$queryRaw.mockReset().mockResolvedValue([lockedKelas({ kapasitas: 5 })]);
                prisma.pesertaKelas.count.mockResolvedValue(5);

                const res = createMockRes();
                await akademikController.daftarKelas(createMockReq({ id_kelas: 1 }), res);

                expect(res.status).toHaveBeenCalledWith(400);
                expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                    message: expect.stringContaining('Kelas sudah penuh')
                }));
                const [lock] = rawCalls(prisma.$queryRaw, 'FOR UPDATE');
                expect(lock[0].join('?')).toMatch(/SELECT kapasitas/);
                expect(prisma.pesertaKelas.create).not.toHaveBeenCalled();
            });

            test('a class deleted before the lock was taken is 404', async () => {
                prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 1, kapasitas: 5, hari: 1 });
                prisma.$queryRaw.mockReset().mockResolvedValue([lockedKelas({ deletedAt: new Date() })]);
                prisma.pesertaKelas.count.mockResolvedValue(0);

                const res = createMockRes();
                await akademikController.daftarKelas(createMockReq({ id_kelas: 1 }), res);

                expect(res.status).toHaveBeenCalledWith(404);
                expect(prisma.pesertaKelas.create).not.toHaveBeenCalled();
            });
        });

        describe('Schedule Conflict Check (BF18)', () => {
            test('should block registration if class day and time overlap', async () => {
                prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 1, kapasitas: 50, hari: 1 });
                prisma.pesertaKelas.count.mockResolvedValue(10); // Under capacity
                
                // Target class times and queryRaw conflict response
                prisma.$queryRaw.mockReset()
                    .mockResolvedValueOnce([lockedKelas({ kapasitas: 50 })]) // locked class row with its times
                    .mockResolvedValueOnce([{ id_kelas: 99, nama_kelas: 'Bentrok A' }]); // conflict search

                const req = createMockReq({ id_kelas: 1 });
                const res = createMockRes();

                await akademikController.daftarKelas(req, res);

                expect(res.status).toHaveBeenCalledWith(409);
                expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                    status: 'error',
                    message: expect.stringContaining('Jadwal bentrok')
                }));
            });
        });

        describe('Drop Deadline Check (BF21)', () => {
            test('should block dropping class if drop deadline has passed', async () => {
                const pastDeadline = new Date();
                pastDeadline.setDate(pastDeadline.getDate() - 2); // 2 days in the past
                
                prisma.semester.findFirst.mockResolvedValue({
                    id_semester: 1,
                    is_active: true,
                    drop_deadline: pastDeadline
                });

                const req = createMockReq({}, { id_user: 1, role: 'MAHASISWA' }, {}, { id: 1 });
                const res = createMockRes();

                await akademikController.dropKelas(req, res);

                expect(res.status).toHaveBeenCalledWith(400);
                expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                    status: 'error',
                    message: expect.stringContaining('drop deadline')
                }));
            });

            test('should allow dropping class if drop deadline is in the future', async () => {
                const futureDeadline = new Date();
                futureDeadline.setDate(futureDeadline.getDate() + 5); // 5 days in the future

                prisma.semester.findFirst.mockResolvedValue({
                    id_semester: 1,
                    is_active: true,
                    drop_deadline: futureDeadline
                });
                prisma.pesertaKelas.findUnique.mockResolvedValue({ id_kelas: 1, id_mahasiswa: 1, deletedAt: null });
                prisma.pesertaKelas.update.mockResolvedValue({ id_kelas: 1, deletedAt: new Date() });

                const req = createMockReq({}, { id_user: 1, role: 'MAHASISWA' }, {}, { id: 1 });
                const res = createMockRes();

                await akademikController.dropKelas(req, res);

                expect(res.status).toHaveBeenCalledWith(200);
                expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                    status: 'success',
                    message: 'Dropped class successfully'
                }));
            });
        });
    });

    /**
     * CLASS DATA OWNERSHIP (IDOR): roster and jadwal pengganti
     */
    describe('class roster and jadwal pengganti access', () => {
        const kelas = { id_kelas: 5, id_dosen: 2 };
        const mahasiswa = { id_user: 10, role: 'MAHASISWA' };
        const ownDosen = { id_user: 2, role: 'DOSEN' };
        const otherDosen = { id_user: 3, role: 'DOSEN' };
        const admin = { id_user: 1, role: 'ADMIN' };

        beforeEach(() => {
            prisma.kelas.findFirst.mockReset().mockResolvedValue(kelas);
            prisma.pesertaKelas.findFirst.mockReset();
            prisma.pesertaKelas.findMany.mockReset().mockResolvedValue([]);
            prisma.jadwalPengganti.findMany.mockReset().mockResolvedValue([]);
        });

        describe('getPesertaKelas', () => {
            const call = async (user) => {
                const req = createMockReq({}, user, {}, { id: '5' });
                const res = createMockRes();
                await akademikController.getPesertaKelas(req, res);
                return res;
            };

            test('MAHASISWA who is not enrolled gets 403 and no roster', async () => {
                prisma.pesertaKelas.findFirst.mockResolvedValue(null);

                const res = await call(mahasiswa);

                expect(res.status).toHaveBeenCalledWith(403);
                expect(prisma.pesertaKelas.findMany).not.toHaveBeenCalled();
            });

            test('MAHASISWA enrollment is checked for the active enrollment of that class', async () => {
                prisma.pesertaKelas.findFirst.mockResolvedValue({ id_peserta_kelas: 1 });

                await call(mahasiswa);

                expect(prisma.pesertaKelas.findFirst).toHaveBeenCalledWith(expect.objectContaining({
                    where: expect.objectContaining({ id_kelas: 5, id_mahasiswa: 10, deletedAt: null })
                }));
            });

            test('enrolled MAHASISWA gets the roster', async () => {
                prisma.pesertaKelas.findFirst.mockResolvedValue({ id_peserta_kelas: 1 });

                const res = await call(mahasiswa);

                expect(res.status).toHaveBeenCalledWith(200);
                expect(prisma.pesertaKelas.findMany).toHaveBeenCalled();
            });

            test('DOSEN of another class gets 403', async () => {
                const res = await call(otherDosen);

                expect(res.status).toHaveBeenCalledWith(403);
                expect(prisma.pesertaKelas.findMany).not.toHaveBeenCalled();
            });

            test('error messages are in Indonesian', async () => {
                const dosenRes = await call(otherDosen);
                expect(dosenRes.json).toHaveBeenCalledWith({
                    status: 'error',
                    message: 'Anda hanya dapat melihat peserta kelas yang Anda ajar'
                });

                prisma.kelas.findFirst.mockResolvedValue(null);
                const missingRes = await call(admin);
                expect(missingRes.status).toHaveBeenCalledWith(404);
                expect(missingRes.json).toHaveBeenCalledWith({
                    status: 'error',
                    message: 'Kelas tidak ditemukan'
                });
            });

            test('own DOSEN and ADMIN get the roster', async () => {
                expect((await call(ownDosen)).status).toHaveBeenCalledWith(200);
                expect((await call(admin)).status).toHaveBeenCalledWith(200);
            });
        });

        describe('getJadwalPenggantiByKelas', () => {
            const call = async (user) => {
                const req = createMockReq({}, user, {}, { id: '5' });
                const res = createMockRes();
                await akademikController.getJadwalPenggantiByKelas(req, res);
                return res;
            };

            test('MAHASISWA who is not enrolled gets 403', async () => {
                prisma.pesertaKelas.findFirst.mockResolvedValue(null);

                const res = await call(mahasiswa);

                expect(res.status).toHaveBeenCalledWith(403);
                expect(prisma.jadwalPengganti.findMany).not.toHaveBeenCalled();
            });

            test('enrolled MAHASISWA gets the schedule changes', async () => {
                prisma.pesertaKelas.findFirst.mockResolvedValue({ id_peserta_kelas: 1 });

                const res = await call(mahasiswa);

                expect(res.status).toHaveBeenCalledWith(200);
                expect(prisma.jadwalPengganti.findMany).toHaveBeenCalled();
            });

            test('DOSEN of another class gets 403', async () => {
                const res = await call(otherDosen);

                expect(res.status).toHaveBeenCalledWith(403);
                expect(prisma.jadwalPengganti.findMany).not.toHaveBeenCalled();
            });

            test('own DOSEN and ADMIN get the schedule changes', async () => {
                expect((await call(ownDosen)).status).toHaveBeenCalledWith(200);
                expect((await call(admin)).status).toHaveBeenCalledWith(200);
            });

            test('unknown class is 404', async () => {
                prisma.kelas.findFirst.mockResolvedValue(null);

                const res = await call(admin);

                expect(res.status).toHaveBeenCalledWith(404);
                expect(prisma.jadwalPengganti.findMany).not.toHaveBeenCalled();
            });

            test('upcoming=true starts at 00:00 WIB today, so earlier-today overrides stay listed', async () => {
                useFakeNow(AFTER_MIDNIGHT_WIB);

                const req = createMockReq({}, admin, { upcoming: 'true' }, { id: '5' });
                await akademikController.getJadwalPenggantiByKelas(req, createMockRes());

                expect(prisma.jadwalPengganti.findMany).toHaveBeenCalledWith(expect.objectContaining({
                    where: expect.objectContaining({ tanggal_asli: { gte: new Date('2026-10-13T17:00:00.000Z') } })
                }));
            });
        });
    });

    /**
     * ASIA/JAKARTA "TODAY", WEEK AND DAY OF WEEK (UTC+7, 00:00-07:00 WIB is the previous UTC day)
     */
    describe('Jakarta day boundaries', () => {
        const admin = { id_user: 1, role: 'ADMIN' };

        beforeEach(() => {
            prisma.$queryRaw.mockReset().mockResolvedValue([]);
            prisma.kelas.findMany.mockReset();
            prisma.jadwalPengganti.findMany.mockReset().mockResolvedValue([]);
        });

        describe('getKelasHariIni', () => {
            const kelasRow = (overrides) => ({
                id_kelas: 1, nama_kelas: 'A', hari: 3, ruangan: 'R1', matakuliah: {}, dosen: {},
                _count: { peserta: 0 }, sesiAbsensi: [], jadwalPengganti: [], ...overrides
            });

            test('at 01:30 WIB on Wednesday it uses hari 3 and the Jakarta day range', async () => {
                useFakeNow(AFTER_MIDNIGHT_WIB);
                prisma.kelas.findMany.mockResolvedValue([kelasRow()]);

                const res = createMockRes();
                await akademikController.getKelasHariIni(createMockReq({}, admin), res);

                expect(prisma.kelas.findMany.mock.calls[0][0].where.OR).toContainEqual({ hari: 3 });
                expect(prisma.jadwalPengganti.findMany).toHaveBeenCalledWith(expect.objectContaining({
                    where: expect.objectContaining({
                        tanggal_ganti: {
                            gte: new Date('2026-10-13T17:00:00.000Z'),
                            lte: new Date('2026-10-14T16:59:59.999Z')
                        }
                    })
                }));
                const body = res.json.mock.calls[0][0];
                expect(body.meta).toMatchObject({ current_day: 3, day_name: 'Rabu', current_time: '01:30:00' });
                expect(body.data.map((k) => k.id_kelas)).toEqual([1]);
            });

            test('overrides are matched against the Jakarta calendar day', async () => {
                useFakeNow(AFTER_MIDNIGHT_WIB);
                prisma.jadwalPengganti.findMany.mockResolvedValue([{ id_kelas: 3 }]);
                prisma.kelas.findMany.mockResolvedValue([
                    kelasRow({ id_kelas: 1 }),
                    // Cancelled for Wednesday 14/10 (date-only value stored as midnight UTC)
                    kelasRow({
                        id_kelas: 2,
                        jadwalPengganti: [{ status: 'LIBUR', tanggal_asli: new Date('2026-10-14T00:00:00Z'), tanggal_ganti: null }]
                    }),
                    // Friday class moved to 03:00 WIB on Wednesday 14/10 (still 13/10 in UTC)
                    kelasRow({
                        id_kelas: 3,
                        hari: 5,
                        jadwalPengganti: [{
                            status: 'GANTI_JADWAL',
                            tanggal_asli: new Date('2026-10-16T00:00:00Z'),
                            tanggal_ganti: new Date('2026-10-13T20:00:00Z'),
                            ruangan_ganti: 'Lab'
                        }]
                    })
                ]);

                const res = createMockRes();
                await akademikController.getKelasHariIni(createMockReq({}, admin), res);

                const { data } = res.json.mock.calls[0][0];
                expect(data.map((k) => k.id_kelas)).toEqual([1, 3]);
                expect(data[1].ruangan).toBe('Lab');
            });
        });

        describe('getKelasWithHari', () => {
            test('uses the Monday-Sunday week in Jakarta and puts a moved class on its Jakarta weekday', async () => {
                useFakeNow(AFTER_MIDNIGHT_WIB);
                prisma.kelas.findMany.mockResolvedValue([{
                    id_kelas: 4, nama_kelas: 'B', hari: 2, ruangan: 'R1', matakuliah: {}, dosen: {}, _count: { peserta: 0 },
                    jadwalPengganti: [{
                        id_jadwal_pengganti: 1,
                        status: 'GANTI_JADWAL',
                        tanggal_asli: new Date('2026-10-13T00:00:00Z'),
                        // 01:00 WIB on Friday 16/10, still Thursday 15/10 in UTC
                        tanggal_ganti: new Date('2026-10-15T18:00:00Z'),
                        ruangan_ganti: 'R9',
                        alasan: 'Rapat'
                    }]
                }]);

                const res = createMockRes();
                await akademikController.getKelasWithHari(createMockReq({}, admin), res);

                const overrideWhere = prisma.kelas.findMany.mock.calls[0][0].include.jadwalPengganti.where;
                expect(overrideWhere.OR[0].tanggal_asli).toEqual({
                    gte: new Date('2026-10-11T17:00:00.000Z'),
                    lte: new Date('2026-10-18T16:59:59.999Z')
                });
                const grouped = res.json.mock.calls[0][0].data;
                expect(grouped.Jumat.map((k) => k.id_kelas)).toEqual([4]);
                expect(grouped.Kamis).toEqual([]);
            });
        });

        describe('getAbsensiKelas date filter', () => {
            beforeEach(() => {
                prisma.kelas.findFirst.mockReset().mockResolvedValue({ id_kelas: 1, id_dosen: 5 });
                prisma.absensi.findMany.mockReset().mockResolvedValue([]);
                prisma.absensi.count.mockReset().mockResolvedValue(0);
            });

            test('a date covers that whole Jakarta day', async () => {
                const req = createMockReq({}, admin, { date: '2026-10-14' }, { id: '1' });
                await akademikController.getAbsensiKelas(req, createMockRes());

                expect(prisma.absensi.findMany).toHaveBeenCalledWith(expect.objectContaining({
                    where: expect.objectContaining({
                        createdAt: {
                            gte: new Date('2026-10-13T17:00:00.000Z'),
                            lte: new Date('2026-10-14T16:59:59.999Z')
                        }
                    })
                }));
            });

            test('an invalid date is a 400', async () => {
                const res = createMockRes();
                await akademikController.getAbsensiKelas(createMockReq({}, admin, { date: 'kemarin' }, { id: '1' }), res);

                expect(res.status).toHaveBeenCalledWith(400);
                expect(prisma.absensi.findMany).not.toHaveBeenCalled();
            });
        });
    });

    /**
     * RAW LIMITS ARE CLAMPED (paginationHelper caps at 100)
     */
    describe('list limits are clamped', () => {
        const admin = { id_user: 1, role: 'ADMIN' };

        beforeEach(() => {
            prisma.kelas.findFirst.mockReset().mockResolvedValue({ id_kelas: 1, id_dosen: 5 });
            prisma.absensi.findMany.mockReset().mockResolvedValue([]);
            prisma.absensi.count.mockReset().mockResolvedValue(0);
            prisma.sesiAbsensi.findMany.mockReset().mockResolvedValue([]);
            prisma.sesiAbsensi.count.mockReset().mockResolvedValue(0);
            prisma.pesertaKelas.count.mockReset().mockResolvedValue(0);
        });

        test('getAbsensiKelas caps limit at 100', async () => {
            const res = createMockRes();
            await akademikController.getAbsensiKelas(createMockReq({}, admin, { limit: '100000', page: '-3' }, { id: '1' }), res);

            expect(prisma.absensi.findMany).toHaveBeenCalledWith(expect.objectContaining({ take: 100, skip: 0 }));
            expect(res.json.mock.calls[0][0].pagination).toMatchObject({ page: 1, limit: 100 });
        });

        test('getAbsensiKelas keeps its default limit of 50', async () => {
            await akademikController.getAbsensiKelas(createMockReq({}, admin, {}, { id: '1' }), createMockRes());

            expect(prisma.absensi.findMany).toHaveBeenCalledWith(expect.objectContaining({ take: 50 }));
        });

        test('getSesiAbsensiByKelas caps limit at 100', async () => {
            const res = createMockRes();
            await akademikController.getSesiAbsensiByKelas(createMockReq({}, admin, { limit: '5000' }, { id: '1' }), res);

            expect(prisma.sesiAbsensi.findMany).toHaveBeenCalledWith(expect.objectContaining({ take: 100, skip: 0 }));
            expect(res.json.mock.calls[0][0].pagination).toMatchObject({ page: 1, limit: 100 });
        });

        test('getSesiAbsensiByKelas keeps its default limit of 20', async () => {
            await akademikController.getSesiAbsensiByKelas(createMockReq({}, admin, {}, { id: '1' }), createMockRes());

            expect(prisma.sesiAbsensi.findMany).toHaveBeenCalledWith(expect.objectContaining({ take: 20 }));
        });
    });

    /**
     * OPEN ABSENSI: no overlapping open sessions per class
     */
    describe('openAbsensi', () => {
        const dosen = { id_user: 5, role: 'DOSEN' };
        const body = { id_kelas: 1, mulai: '2026-10-14T01:00:00.000Z', selesai: '2026-10-14T03:00:00.000Z' };

        beforeEach(() => {
            prisma.kelas.findFirst.mockReset().mockResolvedValue({
                id_kelas: 1, id_dosen: 5, nama_kelas: 'A', matakuliah: { nama_matakuliah: 'MK' }
            });
            prisma.sesiAbsensi.findFirst.mockReset().mockResolvedValue(null);
            prisma.sesiAbsensi.create.mockReset().mockResolvedValue({ id_sesi_absensi: 10 });
            prisma.$executeRaw.mockReset().mockResolvedValue(1);
        });

        test('409 when the class already has an open session overlapping the window', async () => {
            prisma.sesiAbsensi.findFirst.mockResolvedValue({ id_sesi_absensi: 3 });

            const res = createMockRes();
            await akademikController.openAbsensi(createMockReq(body, dosen), res);

            expect(res.status).toHaveBeenCalledWith(409);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ status: 'error' }));
            expect(prisma.sesiAbsensi.create).not.toHaveBeenCalled();
            expect(prisma.sesiAbsensi.findFirst).toHaveBeenCalledWith(expect.objectContaining({
                where: expect.objectContaining({
                    id_kelas: 1,
                    deletedAt: null,
                    status: true,
                    mulai: { lt: new Date(body.selesai) },
                    selesai: { gt: new Date(body.mulai) }
                })
            }));
        });

        test('the overlap check and the insert run in one transaction after locking the class row', async () => {
            await akademikController.openAbsensi(createMockReq(body, dosen), createMockRes());

            expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function));
            const locks = rawCalls(prisma.$executeRaw, 'FOR UPDATE');
            expect(locks).toHaveLength(1);
            expect(prisma.$executeRaw.mock.invocationCallOrder[0])
                .toBeLessThan(prisma.sesiAbsensi.findFirst.mock.invocationCallOrder[0]);
        });

        test('201 when no open session overlaps', async () => {
            const res = createMockRes();
            await akademikController.openAbsensi(createMockReq(body, dosen), res);

            expect(res.status).toHaveBeenCalledWith(201);
            expect(prisma.sesiAbsensi.create).toHaveBeenCalled();
        });

        test.each([
            ['equals', body.mulai],
            ['is before', '2026-10-14T00:00:00.000Z']
        ])('400 when selesai %s mulai', async (_label, selesai) => {
            const res = createMockRes();
            await akademikController.openAbsensi(createMockReq({ ...body, selesai }, dosen), res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(prisma.sesiAbsensi.create).not.toHaveBeenCalled();
        });
    });

    /**
     * UPDATE KELAS: time validation, conflict check on every schedule change, one transaction
     */
    describe('updateKelas', () => {
        const admin = { id_user: 1, role: 'ADMIN' };
        const existing = { id_kelas: 7, id_dosen: 5, id_semester: 1, hari: 1, ruangan: '101', kapasitas: 40, nama_kelas: 'A' };
        const storedTimes = [{ jam_mulai: '08:00:00', jam_berakhir: '10:00:00' }];
        const rawQuery = (conflicts) => async (strings) => (
            strings.join('?').includes('jam_mulai::text') ? storedTimes : conflicts
        );

        const call = async (body, user = admin) => {
            const res = createMockRes();
            await akademikController.updateKelas(createMockReq(body, user, {}, { id: '7' }), res);
            return res;
        };

        beforeEach(() => {
            prisma.kelas.findFirst.mockReset().mockResolvedValue(existing);
            prisma.kelas.update.mockReset().mockResolvedValue(existing);
            prisma.user.findFirst.mockReset().mockResolvedValue({ id_user: 6, role: 'DOSEN' });
            prisma.pesertaKelas.count.mockReset().mockResolvedValue(10);
            prisma.$executeRaw.mockReset().mockResolvedValue(1);
            prisma.$queryRaw.mockReset().mockImplementation(rawQuery([]));
        });

        test('400 when the new jam_mulai is not before the stored jam_berakhir', async () => {
            const res = await call({ jam_mulai: '10:00:00' });

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Jam berakhir harus setelah jam mulai' });
            expect(rawCalls(prisma.$executeRaw, 'UPDATE kelas')).toHaveLength(0);
            expect(prisma.kelas.update).not.toHaveBeenCalled();
        });

        test('400 when both new times are in the wrong order', async () => {
            const res = await call({ jam_mulai: '15:00:00', jam_berakhir: '13:00:00' });

            expect(res.status).toHaveBeenCalledWith(400);
        });

        test.each([
            ['hari', { hari: 3 }],
            ['id_dosen', { id_dosen: 6 }],
            ['ruangan', { ruangan: 'Lab 2' }],
            ['jam_mulai', { jam_mulai: '07:00:00' }]
        ])('changing only %s runs the conflict check', async (_field, body) => {
            prisma.$queryRaw.mockImplementation(rawQuery([{ id_kelas: 9, nama_kelas: 'B', id_dosen: 5, ruangan: 'X' }]));

            const res = await call(body);

            expect(res.status).toHaveBeenCalledWith(409);
            expect(prisma.kelas.update).not.toHaveBeenCalled();
        });

        test('the conflict check uses the merged schedule and excludes the class itself', async () => {
            await call({ ruangan: 'Lab 2' });

            const conflictCall = rawCalls(prisma.$queryRaw, 'id_dosen')[0];
            expect(conflictCall.slice(1)).toEqual(expect.arrayContaining([1, '08:00:00', '10:00:00', 5, 'Lab 2', 7]));
        });

        test('a change that does not touch the schedule skips the conflict check', async () => {
            const res = await call({ nama_kelas: 'C' });

            expect(res.status).toHaveBeenCalledWith(200);
            expect(rawCalls(prisma.$queryRaw, 'id_dosen')).toHaveLength(0);
        });

        test('re-sending the stored schedule unchanged (as the mobile form does) skips the conflict check', async () => {
            // A clash that already exists must not block renaming the class
            prisma.$queryRaw.mockImplementation(rawQuery([{ id_kelas: 9, nama_kelas: 'B', id_dosen: 5, ruangan: '101' }]));

            const res = await call({
                id_dosen: '5',
                hari: 1,
                ruangan: ' 101 ',
                jam_mulai: '8:00:00',
                jam_berakhir: '10:00:00',
                nama_kelas: 'A2',
                kapasitas: 40
            });

            expect(res.status).toHaveBeenCalledWith(200);
            expect(rawCalls(prisma.$queryRaw, 'id_dosen')).toHaveLength(0);
            expect(prisma.kelas.update).toHaveBeenCalledWith(expect.objectContaining({
                data: expect.objectContaining({ nama_kelas: 'A2' })
            }));
        });

        test('a room that only differs in letter case is not a schedule change', async () => {
            prisma.kelas.findFirst.mockResolvedValue({ ...existing, ruangan: 'Lab 1' });
            prisma.$queryRaw.mockImplementation(rawQuery([{ id_kelas: 9, nama_kelas: 'B', id_dosen: 7, ruangan: 'LAB 1' }]));

            const res = await call({ ruangan: 'LAB 1' });

            expect(res.status).toHaveBeenCalledWith(200);
            expect(rawCalls(prisma.$queryRaw, 'id_dosen')).toHaveLength(0);
        });

        test('re-sending everything with one real change still runs the conflict check', async () => {
            prisma.$queryRaw.mockImplementation(rawQuery([{ id_kelas: 9, nama_kelas: 'B', id_dosen: 5, ruangan: 'X' }]));

            const res = await call({ id_dosen: 5, hari: 1, ruangan: '101', jam_mulai: '08:00:00', jam_berakhir: '11:00:00' });

            expect(res.status).toHaveBeenCalledWith(409);
            expect(prisma.kelas.update).not.toHaveBeenCalled();
        });

        test('time and field updates are written in one transaction', async () => {
            const tx = {
                $queryRaw: jest.fn().mockResolvedValue([]),
                $executeRaw: jest.fn().mockResolvedValue(1),
                pesertaKelas: { count: jest.fn().mockResolvedValue(0) },
                kelas: { update: jest.fn().mockResolvedValue(existing), findFirst: jest.fn().mockResolvedValue(existing) }
            };
            prisma.$transaction.mockImplementation(async (fn) => fn(tx));

            const res = await call({ jam_mulai: '13:00:00', jam_berakhir: '15:00:00', nama_kelas: 'C' });

            expect(res.status).toHaveBeenCalledWith(200);
            const timeUpdate = rawCalls(tx.$executeRaw, 'UPDATE kelas')[0];
            expect(timeUpdate.slice(1)).toEqual(expect.arrayContaining(['13:00:00', '15:00:00']));
            expect(tx.kelas.update).toHaveBeenCalledWith(expect.objectContaining({
                data: expect.objectContaining({ nama_kelas: 'C' })
            }));
            expect(prisma.$executeRaw).not.toHaveBeenCalled();
            expect(prisma.kelas.update).not.toHaveBeenCalled();
        });

        test('kapasitas is updated when given', async () => {
            const res = await call({ kapasitas: 30 });

            expect(res.status).toHaveBeenCalledWith(200);
            expect(prisma.kelas.update).toHaveBeenCalledWith(expect.objectContaining({
                data: expect.objectContaining({ kapasitas: 30 })
            }));
        });

        test('kapasitas below the current number of peserta is a 400', async () => {
            const res = await call({ kapasitas: 5 });

            expect(res.status).toHaveBeenCalledWith(400);
            expect(prisma.kelas.update).not.toHaveBeenCalled();
        });

        test.each([[0], [-1], ['abc'], [2.5]])('kapasitas %p is a 400', async (kapasitas) => {
            const res = await call({ kapasitas });

            expect(res.status).toHaveBeenCalledWith(400);
            expect(prisma.kelas.update).not.toHaveBeenCalled();
        });
    });

    /**
     * ENROLLMENT: capacity check and insert are atomic
     */
    describe('enrollment capacity is checked inside the insert transaction', () => {
        test('daftarKelas locks the class row before counting and inserts with the transaction client', async () => {
            prisma.kelas.findFirst.mockReset().mockResolvedValue({ id_kelas: 1, kapasitas: 5, hari: 1 });
            const tx = {
                $executeRaw: jest.fn().mockResolvedValue(1),
                $queryRaw: jest.fn()
                    .mockResolvedValueOnce([{ kapasitas: 5, hari: 1, deletedAt: null, jam_mulai: '08:00:00', jam_berakhir: '10:00:00' }])
                    .mockResolvedValueOnce([]),
                pesertaKelas: {
                    findUnique: jest.fn().mockResolvedValue(null),
                    count: jest.fn().mockResolvedValue(4),
                    create: jest.fn().mockResolvedValue({ id_kelas: 1, id_mahasiswa: 1 }),
                    update: jest.fn()
                }
            };
            prisma.$transaction.mockImplementation(async (fn) => fn(tx));

            const res = createMockRes();
            await akademikController.daftarKelas(createMockReq({ id_kelas: 1 }, { id_user: 1, role: 'MAHASISWA' }), res);

            expect(res.status).toHaveBeenCalledWith(201);
            expect(rawCalls(tx.$queryRaw, 'FOR UPDATE')).toHaveLength(1);
            expect(tx.$queryRaw.mock.invocationCallOrder[0]).toBeLessThan(tx.pesertaKelas.count.mock.invocationCallOrder[0]);
            expect(tx.pesertaKelas.create).toHaveBeenCalled();
            expect(prisma.pesertaKelas.create).not.toHaveBeenCalled();
            expect(prisma.pesertaKelas.count).not.toHaveBeenCalled();
        });

        describe('adminAddPeserta', () => {
            beforeEach(() => {
                prisma.kelas.findFirst.mockReset().mockResolvedValue({ id_kelas: 1, kapasitas: 3 });
                prisma.user.findMany.mockReset().mockResolvedValue([{ id_user: 11 }, { id_user: 12 }]);
                prisma.pesertaKelas.findMany.mockReset().mockResolvedValue([]);
                prisma.pesertaKelas.count.mockReset();
                prisma.pesertaKelas.createMany.mockReset().mockResolvedValue({ count: 2 });
                prisma.pesertaKelas.updateMany.mockReset().mockResolvedValue({ count: 0 });
                prisma.$executeRaw.mockReset().mockResolvedValue(1);
                prisma.$queryRaw.mockReset().mockResolvedValue([{ kapasitas: 3, deletedAt: null }]);
            });

            test('compares against the kapasitas read under the row lock, not the earlier read', async () => {
                // Read before the transaction: 3; lowered to 2 before the lock was taken
                prisma.$queryRaw.mockResolvedValue([{ kapasitas: 2, deletedAt: null }]);
                prisma.pesertaKelas.count.mockResolvedValue(1);

                const res = createMockRes();
                await akademikController.adminAddPeserta(createMockReq({ id_kelas: 1, id_mahasiswa: [11, 12] }), res);

                expect(res.status).toHaveBeenCalledWith(400);
                expect(res.json).toHaveBeenCalledWith({
                    status: 'error',
                    message: expect.stringContaining('Sisa kuota: 1')
                });
                const [lock] = rawCalls(prisma.$queryRaw, 'FOR UPDATE');
                expect(lock[0].join('?')).toMatch(/SELECT kapasitas/);
                expect(prisma.pesertaKelas.createMany).not.toHaveBeenCalled();
            });

            test('a class deleted before the lock was taken is 404', async () => {
                prisma.$queryRaw.mockResolvedValue([{ kapasitas: 3, deletedAt: new Date() }]);
                prisma.pesertaKelas.count.mockResolvedValue(0);

                const res = createMockRes();
                await akademikController.adminAddPeserta(createMockReq({ id_kelas: 1, id_mahasiswa: [11] }), res);

                expect(res.status).toHaveBeenCalledWith(404);
                expect(prisma.pesertaKelas.createMany).not.toHaveBeenCalled();
            });

            test('400 and nothing written when the batch does not fit', async () => {
                prisma.pesertaKelas.count.mockResolvedValue(2);

                const res = createMockRes();
                await akademikController.adminAddPeserta(createMockReq({ id_kelas: 1, id_mahasiswa: [11, 12] }), res);

                expect(res.status).toHaveBeenCalledWith(400);
                expect(res.json).toHaveBeenCalledWith({
                    status: 'error',
                    message: expect.stringContaining('Kapasitas kelas tidak mencukupi')
                });
                expect(prisma.pesertaKelas.createMany).not.toHaveBeenCalled();
                expect(prisma.pesertaKelas.updateMany).not.toHaveBeenCalled();
            });

            test('adds the batch inside a locked transaction when it fits', async () => {
                prisma.pesertaKelas.count.mockResolvedValue(1);

                const res = createMockRes();
                await akademikController.adminAddPeserta(createMockReq({ id_kelas: 1, id_mahasiswa: [11, 12] }), res);

                expect(res.status).toHaveBeenCalledWith(201);
                expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function));
                expect(rawCalls(prisma.$queryRaw, 'FOR UPDATE')).toHaveLength(1);
                expect(prisma.pesertaKelas.createMany).toHaveBeenCalled();
            });
        });
    });

    /**
     * ABSENSI INSERT RACE: the unique index wins, the client gets a 409
     */
    describe('createAbsensi duplicate insert race', () => {
        const mahasiswa = { id_user: 10, role: 'MAHASISWA' };
        const body = { id_kelas: 1, id_sesi_absensi: 2, latitude: -6.97, longitude: 107.63 };

        beforeEach(() => {
            prisma.kelas.findFirst.mockReset().mockResolvedValue({ id_kelas: 1 });
            prisma.pesertaKelas.findFirst.mockReset().mockResolvedValue({ id_mahasiswa: 10, id_kelas: 1 });
            prisma.sesiAbsensi.findFirst.mockReset().mockResolvedValue({
                id_sesi_absensi: 2, id_kelas: 1, require_face: false, type_absensi: 'REMOTE_ABSENSI',
                latitude: null, longitude: null, radius_meter: null,
                mulai: new Date(Date.now() - 60 * 60 * 1000),
                selesai: new Date(Date.now() + 60 * 60 * 1000)
            });
            prisma.absensi.findFirst.mockReset().mockResolvedValue(null);
            prisma.$queryRaw.mockReset().mockResolvedValue([]);
            prisma.$executeRaw.mockReset();
        });

        test.each([
            ['P2002', Object.assign(new Error('Unique constraint failed'), { code: 'P2002' })],
            ['P2010 / 23505', Object.assign(new Error('Raw query failed'), { code: 'P2010', meta: { code: '23505' } })]
        ])('a %s unique violation on insert is a 409', async (_label, err) => {
            prisma.$executeRaw.mockRejectedValue(err);

            const res = createMockRes();
            const next = jest.fn();
            await akademikController.createAbsensi(createMockReq(body, mahasiswa), res, next);

            expect(next).not.toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(409);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Anda sudah melakukan absensi untuk sesi ini'
            });
        });

        test('other insert errors still propagate', async () => {
            prisma.$executeRaw.mockRejectedValue(new Error('db down'));

            const next = jest.fn();
            await akademikController.createAbsensi(createMockReq(body, mahasiswa), createMockRes(), next);

            expect(next).toHaveBeenCalledWith(expect.any(Error));
        });
    });

    /**
     * ATTENDANCE STATUS ON CHECK-IN: TELAT after LATE_THRESHOLD_MINUTES (default 15), else HADIR
     */
    describe('createAbsensi sets the attendance status', () => {
        const mahasiswa = { id_user: 10, role: 'MAHASISWA' };
        const body = { id_kelas: 1, id_sesi_absensi: 2, latitude: -6.97, longitude: 107.63 };
        const SESSION_START = new Date('2026-10-14T01:00:00Z'); // 08:00 WIB
        const minutesAfterStart = (minutes) => new Date(SESSION_START.getTime() + minutes * 60 * 1000);
        let previousThreshold;

        const insertCall = () => rawCalls(prisma.$executeRaw, 'INSERT INTO absensi')[0];

        beforeEach(() => {
            previousThreshold = process.env.LATE_THRESHOLD_MINUTES;
            delete process.env.LATE_THRESHOLD_MINUTES;
            prisma.kelas.findFirst.mockReset().mockResolvedValue({ id_kelas: 1 });
            prisma.pesertaKelas.findFirst.mockReset().mockResolvedValue({ id_mahasiswa: 10, id_kelas: 1 });
            prisma.sesiAbsensi.findFirst.mockReset().mockResolvedValue({
                id_sesi_absensi: 2, id_kelas: 1, require_face: false, type_absensi: 'REMOTE_ABSENSI',
                latitude: null, longitude: null, radius_meter: null,
                mulai: SESSION_START,
                selesai: new Date('2026-10-14T03:00:00Z')
            });
            prisma.absensi.findFirst.mockReset()
                .mockResolvedValueOnce(null) // no earlier attendance for this session
                .mockResolvedValue({ id_absensi: 1, status: 'TELAT' });
            prisma.$queryRaw.mockReset().mockResolvedValue([]);
            prisma.$executeRaw.mockReset().mockResolvedValue(1);
        });

        afterEach(() => {
            if (previousThreshold === undefined) delete process.env.LATE_THRESHOLD_MINUTES;
            else process.env.LATE_THRESHOLD_MINUTES = previousThreshold;
        });

        test('20 minutes after the start is TELAT', async () => {
            useFakeNow(minutesAfterStart(20));

            const res = createMockRes();
            await akademikController.createAbsensi(createMockReq(body, mahasiswa), res);

            expect(res.status).toHaveBeenCalledWith(201);
            expect(insertCall()[0].join('?')).toMatch(/"StatusKehadiran"/);
            expect(insertCall().slice(1)).toContain('TELAT');
        });

        test('10 minutes after the start is HADIR', async () => {
            useFakeNow(minutesAfterStart(10));

            await akademikController.createAbsensi(createMockReq(body, mahasiswa), createMockRes());

            expect(insertCall().slice(1)).toContain('HADIR');
            expect(insertCall().slice(1)).not.toContain('TELAT');
        });

        test('exactly the threshold is still HADIR', async () => {
            useFakeNow(minutesAfterStart(15));

            await akademikController.createAbsensi(createMockReq(body, mahasiswa), createMockRes());

            expect(insertCall().slice(1)).toContain('HADIR');
        });

        test('LATE_THRESHOLD_MINUTES moves the boundary', async () => {
            process.env.LATE_THRESHOLD_MINUTES = '30';
            useFakeNow(minutesAfterStart(20));

            await akademikController.createAbsensi(createMockReq(body, mahasiswa), createMockRes());

            expect(insertCall().slice(1)).toContain('HADIR');
        });

        test('the impossible-travel check ignores records without a location (entered by a dosen)', async () => {
            useFakeNow(minutesAfterStart(5));

            await akademikController.createAbsensi(createMockReq(body, mahasiswa), createMockRes());

            const [previous] = rawCalls(prisma.$queryRaw, 'koordinat[0]');
            expect(previous[0].join('?')).toMatch(/koordinat IS NOT NULL/);
        });
    });

    /**
     * STATS / HISTORY: only closed sessions on/after the student's enrollment count
     */
    describe('attendance statistics count only closed sessions on/after enrollment', () => {
        const HOUR = 60 * 60 * 1000;
        const enrolledAt = new Date('2020-02-01T00:00:00Z');
        const sBefore = {
            id_sesi_absensi: 1, id_kelas: 1, status: false,
            mulai: new Date('2020-01-10T01:00:00Z'), selesai: new Date('2020-01-10T03:00:00Z')
        };
        // Ended long ago but never closed by hand
        const sAfter = {
            id_sesi_absensi: 2, id_kelas: 1, status: true,
            mulai: new Date('2020-03-01T01:00:00Z'), selesai: new Date('2020-03-01T03:00:00Z')
        };
        let sOpen;

        beforeEach(() => {
            sOpen = {
                id_sesi_absensi: 3, id_kelas: 1, status: true,
                mulai: new Date(Date.now() - HOUR), selesai: new Date(Date.now() + HOUR)
            };
        });

        test('getAbsensiStats (/absensi/kelas/:id/stats)', async () => {
            prisma.kelas.findFirst.mockReset().mockResolvedValue({ id_kelas: 1, id_dosen: 5 });
            prisma.sesiAbsensi.findMany.mockReset().mockResolvedValue([sBefore, sAfter, sOpen]);
            prisma.pesertaKelas.findMany.mockReset().mockResolvedValue([
                { id_mahasiswa: 10, createdAt: enrolledAt, deletedAt: null },
                { id_mahasiswa: 11, createdAt: new Date('2019-12-01T00:00:00Z'), deletedAt: null }
            ]);
            prisma.absensi.findMany.mockReset().mockResolvedValue([
                { id_user: 10, id_sesi_absensi: 1, type_absensi: 'REMOTE_ABSENSI', user: { role: 'MAHASISWA' } },
                { id_user: 10, id_sesi_absensi: 2, type_absensi: 'REMOTE_ABSENSI', user: { role: 'MAHASISWA' } },
                { id_user: 10, id_sesi_absensi: 3, type_absensi: 'LOKAL_ABSENSI', user: { role: 'MAHASISWA' } },
                { id_user: 11, id_sesi_absensi: 1, type_absensi: 'REMOTE_ABSENSI', user: { role: 'MAHASISWA' } },
                { id_user: 11, id_sesi_absensi: 2, type_absensi: 'LOKAL_ABSENSI', user: { role: 'MAHASISWA' } }
            ]);

            const res = createMockRes();
            await akademikController.getAbsensiStats(createMockReq({}, { id_user: 1, role: 'ADMIN' }, {}, { id: '1' }), res);

            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json.mock.calls[0][0].data).toEqual({
                totalPeserta: 2,
                totalSesi: 2,
                totalAbsensi: 3,
                absensiByType: { REMOTE_ABSENSI: 2, LOKAL_ABSENSI: 1 },
                absensiByStatus: { HADIR: 3, TELAT: 0, IZIN: 0, SAKIT: 0, ALPHA: 0 },
                totalMahasiswaAbsensi: 2,
                averageAbsensiPerMahasiswa: '1.50'
            });
        });

        test('getAbsensiStats counts only HADIR/TELAT as attendance and reports every status', async () => {
            prisma.kelas.findFirst.mockReset().mockResolvedValue({ id_kelas: 1, id_dosen: 5 });
            prisma.sesiAbsensi.findMany.mockReset().mockResolvedValue([sBefore, sAfter]);
            prisma.pesertaKelas.findMany.mockReset().mockResolvedValue([
                { id_mahasiswa: 10, createdAt: new Date('2019-12-01T00:00:00Z'), deletedAt: null },
                { id_mahasiswa: 11, createdAt: new Date('2019-12-01T00:00:00Z'), deletedAt: null }
            ]);
            prisma.absensi.findMany.mockReset().mockResolvedValue([
                { id_user: 10, id_sesi_absensi: 1, type_absensi: 'REMOTE_ABSENSI', status: 'TELAT', user: { role: 'MAHASISWA' } },
                { id_user: 10, id_sesi_absensi: 2, type_absensi: 'REMOTE_ABSENSI', status: 'ALPHA', user: { role: 'MAHASISWA' } },
                { id_user: 11, id_sesi_absensi: 1, type_absensi: 'LOKAL_ABSENSI', status: 'HADIR', user: { role: 'MAHASISWA' } },
                { id_user: 11, id_sesi_absensi: 2, type_absensi: 'REMOTE_ABSENSI', status: 'IZIN', user: { role: 'MAHASISWA' } }
            ]);

            const res = createMockRes();
            await akademikController.getAbsensiStats(createMockReq({}, { id_user: 1, role: 'ADMIN' }, {}, { id: '1' }), res);

            expect(res.json.mock.calls[0][0].data).toEqual({
                totalPeserta: 2,
                totalSesi: 2,
                totalAbsensi: 2,
                absensiByType: { REMOTE_ABSENSI: 1, LOKAL_ABSENSI: 1 },
                absensiByStatus: { HADIR: 1, TELAT: 1, IZIN: 1, SAKIT: 0, ALPHA: 1 },
                totalMahasiswaAbsensi: 2,
                averageAbsensiPerMahasiswa: '1.00'
            });
        });

        test('getAbsensiKuStats (/absensi/ku/stats) keeps its response shape', async () => {
            prisma.pesertaKelas.findMany.mockReset().mockResolvedValue([{ id_kelas: 1, createdAt: enrolledAt }]);
            prisma.absensi.findMany.mockReset().mockResolvedValue([
                { id_kelas: 1, type_absensi: 'REMOTE_ABSENSI', sesiAbsensi: sBefore },
                { id_kelas: 1, type_absensi: 'REMOTE_ABSENSI', sesiAbsensi: sAfter },
                { id_kelas: 1, type_absensi: 'LOKAL_ABSENSI', sesiAbsensi: sOpen }
            ]);

            const res = createMockRes();
            await akademikController.getAbsensiKuStats(createMockReq({}, { id_user: 10, role: 'MAHASISWA' }), res);

            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith({
                status: 'success',
                data: [{ id_kelas: 1, type_absensi: 'REMOTE_ABSENSI', _count: { type_absensi: 1 } }]
            });
        });

        test('getAbsensiKuStats counts only HADIR/TELAT records as attendance', async () => {
            const sAfter2 = { ...sAfter, id_sesi_absensi: 4, mulai: new Date('2020-03-08T01:00:00Z'), selesai: new Date('2020-03-08T03:00:00Z') };
            const sAfter3 = { ...sAfter, id_sesi_absensi: 5, mulai: new Date('2020-03-15T01:00:00Z'), selesai: new Date('2020-03-15T03:00:00Z') };
            prisma.pesertaKelas.findMany.mockReset().mockResolvedValue([{ id_kelas: 1, createdAt: enrolledAt }]);
            prisma.absensi.findMany.mockReset().mockResolvedValue([
                { id_kelas: 1, type_absensi: 'REMOTE_ABSENSI', status: 'TELAT', sesiAbsensi: sAfter },
                { id_kelas: 1, type_absensi: 'REMOTE_ABSENSI', status: 'SAKIT', sesiAbsensi: sAfter2 },
                { id_kelas: 1, type_absensi: 'REMOTE_ABSENSI', status: 'ALPHA', sesiAbsensi: sAfter3 }
            ]);

            const res = createMockRes();
            await akademikController.getAbsensiKuStats(createMockReq({}, { id_user: 10, role: 'MAHASISWA' }), res);

            expect(res.json.mock.calls[0][0].data).toEqual([
                { id_kelas: 1, type_absensi: 'REMOTE_ABSENSI', _count: { type_absensi: 1 } }
            ]);
        });

        test('getAbsensiKuWithHistory (/absensi/ku/history)', async () => {
            prisma.pesertaKelas.findMany.mockReset().mockResolvedValue([
                { id_kelas: 1, id_mahasiswa: 10, createdAt: enrolledAt, kelas: { id_kelas: 1, nama_kelas: 'A' } }
            ]);
            prisma.sesiAbsensi.findMany.mockReset().mockResolvedValue([sOpen, sAfter, sBefore]);
            prisma.absensi.findMany.mockReset().mockResolvedValue([
                { id_sesi_absensi: 2, id_kelas: 1, createdAt: new Date('2020-03-01T01:10:00Z'), type_absensi: 'REMOTE_ABSENSI' }
            ]);

            const res = createMockRes();
            await akademikController.getAbsensiKuWithHistory(createMockReq({}, { id_user: 10, role: 'MAHASISWA' }), res);

            const [entry] = res.json.mock.calls[0][0].data;
            expect(entry.stats).toEqual({
                total_sesi: 1, total_hadir: 1, total_telat: 0, total_izin: 0, total_sakit: 0, total_tidak_hadir: 0, persentase: '100.0'
            });
            // The session from before enrollment is not listed; the running one is
            expect(entry.sessions.map((s) => s.id_sesi_absensi)).toEqual([3, 2]);
            expect(entry.sessions[0].is_active).toBe(true);
            // status: the record's status (a record without one is a check-in), null when there is no record;
            // status_sesi: whether the sesi itself is still open
            expect(entry.sessions.map((s) => s.status)).toEqual([null, 'HADIR']);
            expect(entry.sessions.map((s) => s.status_sesi)).toEqual([true, true]);
        });

        test('getAbsensiKuWithHistory: 0% (not 100%) while no session counts yet', async () => {
            prisma.pesertaKelas.findMany.mockReset().mockResolvedValue([
                { id_kelas: 1, id_mahasiswa: 10, createdAt: enrolledAt, kelas: { id_kelas: 1, nama_kelas: 'A' } }
            ]);
            prisma.sesiAbsensi.findMany.mockReset().mockResolvedValue([sOpen]);
            prisma.absensi.findMany.mockReset().mockResolvedValue([]);

            const res = createMockRes();
            await akademikController.getAbsensiKuWithHistory(createMockReq({}, { id_user: 10, role: 'MAHASISWA' }), res);

            const [entry] = res.json.mock.calls[0][0].data;
            expect(entry.stats).toEqual({
                total_sesi: 0, total_hadir: 0, total_telat: 0, total_izin: 0, total_sakit: 0, total_tidak_hadir: 0, persentase: 0
            });
        });

        test('getAbsensiKuWithHistory: TELAT is present, IZIN/SAKIT are excused, ALPHA and no record are absent', async () => {
            const closed = (id, day) => ({
                id_sesi_absensi: id, id_kelas: 1, status: false,
                mulai: new Date(`2020-03-${day}T01:00:00Z`), selesai: new Date(`2020-03-${day}T03:00:00Z`)
            });
            prisma.pesertaKelas.findMany.mockReset().mockResolvedValue([
                { id_kelas: 1, id_mahasiswa: 10, createdAt: enrolledAt, kelas: { id_kelas: 1, nama_kelas: 'A' } }
            ]);
            prisma.sesiAbsensi.findMany.mockReset().mockResolvedValue([
                closed(15, '15'), closed(14, '14'), closed(13, '13'), closed(12, '12'), closed(11, '11')
            ]);
            prisma.absensi.findMany.mockReset().mockResolvedValue([
                { id_sesi_absensi: 11, id_kelas: 1, createdAt: new Date('2020-03-11T01:05:00Z'), type_absensi: 'REMOTE_ABSENSI', status: 'HADIR', keterangan: null },
                { id_sesi_absensi: 12, id_kelas: 1, createdAt: new Date('2020-03-12T01:30:00Z'), type_absensi: 'REMOTE_ABSENSI', status: 'TELAT', keterangan: null },
                { id_sesi_absensi: 13, id_kelas: 1, createdAt: new Date('2020-03-13T05:00:00Z'), type_absensi: 'REMOTE_ABSENSI', status: 'SAKIT', keterangan: 'Surat dokter' },
                { id_sesi_absensi: 14, id_kelas: 1, createdAt: new Date('2020-03-14T05:00:00Z'), type_absensi: 'REMOTE_ABSENSI', status: 'ALPHA', keterangan: null }
            ]);

            const res = createMockRes();
            await akademikController.getAbsensiKuWithHistory(createMockReq({}, { id_user: 10, role: 'MAHASISWA' }), res);

            const [entry] = res.json.mock.calls[0][0].data;
            expect(entry.sessions.map((s) => [s.id_sesi_absensi, s.status, s.hadir])).toEqual([
                [15, null, false], [14, 'ALPHA', false], [13, 'SAKIT', false], [12, 'TELAT', true], [11, 'HADIR', true]
            ]);
            expect(entry.sessions[2].keterangan).toBe('Surat dokter');
            // 2 present out of 5 sessions minus 1 excused
            expect(entry.stats).toEqual({
                total_sesi: 5, total_hadir: 2, total_telat: 1, total_izin: 0, total_sakit: 1, total_tidak_hadir: 2, persentase: '50.0'
            });
        });
    });

    /**
     * SESSION DETAIL AND SESSION LIST: statuses, and only the students a session belongs to
     */
    describe('session detail and list use attendance statuses', () => {
        const admin = { id_user: 1, role: 'ADMIN' };
        const before = new Date('2026-10-01T00:00:00Z');
        const after = new Date('2026-10-15T00:00:00Z');
        const SESI = {
            id_sesi_absensi: 7, id_kelas: 1, type_absensi: 'REMOTE_ABSENSI', status: false,
            mulai: new Date('2026-10-14T01:00:00Z'), selesai: new Date('2026-10-14T03:00:00Z'),
            kelas: { id_kelas: 1, id_dosen: 5, matakuliah: {}, dosen: {} }
        };
        const peserta = (id, createdAt) => ({
            id_mahasiswa: id, id_kelas: 1, createdAt, deletedAt: null,
            mahasiswa: { id_user: id, nama: `M${id}`, username: `13${id}` }
        });
        const row = (id_user, status, extra = {}) => ({
            id_user, id_sesi_absensi: 7, status, keterangan: null, diubah_oleh: null,
            createdAt: new Date('2026-10-14T01:05:00Z'), ...extra
        });

        test('getSesiAbsensiDetail: status per student, excused students are not absent, late enrollees are left out', async () => {
            prisma.sesiAbsensi.findFirst.mockReset().mockResolvedValue(SESI);
            prisma.pesertaKelas.findMany.mockReset().mockResolvedValue([
                peserta(10, before), peserta(11, before), peserta(12, before), peserta(13, before),
                peserta(14, after), // enrolled after the session, no record: not part of it
                peserta(15, after) // enrolled after the session but has a record: listed
            ]);
            prisma.absensi.findMany.mockReset().mockResolvedValue([
                row(10, 'HADIR'),
                row(11, 'TELAT', { createdAt: new Date('2026-10-14T01:20:00Z') }),
                row(12, 'IZIN', { keterangan: 'Lomba', diubah_oleh: 5 }),
                row(15, 'SAKIT', { diubah_oleh: 5 }),
                row(16, 'HADIR') // dropped student: not in the class list any more
            ]);

            const res = createMockRes();
            await akademikController.getSesiAbsensiDetail(createMockReq({}, admin, {}, { id: '7' }), res);

            expect(res.status).toHaveBeenCalledWith(200);
            const { peserta: list, stats } = res.json.mock.calls[0][0].data;
            expect(list.map((p) => [p.id_user, p.status, p.hadir])).toEqual([
                [10, 'HADIR', true], [11, 'TELAT', true], [12, 'IZIN', false], [13, null, false], [15, 'SAKIT', false]
            ]);
            expect(list[2]).toMatchObject({ keterangan: 'Lomba', diubah_oleh: 5, waktu_absen: null });
            expect(list[1].waktu_absen).toEqual(new Date('2026-10-14T01:20:00Z'));
            expect(stats).toEqual({
                total_peserta: 5,
                total_hadir: 2,
                total_telat: 1,
                total_izin: 1,
                total_sakit: 1,
                total_tidak_hadir: 1,
                persentase: '66.7'
            });
        });

        test('getSesiAbsensiDetail: 0% when every student is excused', async () => {
            prisma.sesiAbsensi.findFirst.mockReset().mockResolvedValue(SESI);
            prisma.pesertaKelas.findMany.mockReset().mockResolvedValue([peserta(10, before)]);
            prisma.absensi.findMany.mockReset().mockResolvedValue([row(10, 'IZIN')]);

            const res = createMockRes();
            await akademikController.getSesiAbsensiDetail(createMockReq({}, admin, {}, { id: '7' }), res);

            expect(res.json.mock.calls[0][0].data.stats).toMatchObject({ total_peserta: 1, total_tidak_hadir: 0, persentase: 0 });
        });

        test('getSesiAbsensiByKelas: total_peserta and jumlah_hadir per session', async () => {
            const s1 = { id_sesi_absensi: 1, id_kelas: 1, status: false, mulai: new Date('2026-10-07T01:00:00Z'), selesai: new Date('2026-10-07T03:00:00Z'), _count: { absensi: 1 } };
            const s2 = { id_sesi_absensi: 2, id_kelas: 1, status: false, mulai: new Date('2026-10-14T01:00:00Z'), selesai: new Date('2026-10-14T03:00:00Z'), _count: { absensi: 2 } };
            prisma.kelas.findFirst.mockReset().mockResolvedValue({ id_kelas: 1, id_dosen: 5 });
            prisma.sesiAbsensi.findMany.mockReset().mockResolvedValue([s2, s1]);
            prisma.sesiAbsensi.count.mockReset().mockResolvedValue(2);
            prisma.pesertaKelas.findMany.mockReset().mockResolvedValue([
                { id_mahasiswa: 10, createdAt: new Date('2026-10-01T00:00:00Z') },
                { id_mahasiswa: 11, createdAt: new Date('2026-10-10T00:00:00Z') }
            ]);
            prisma.absensi.findMany.mockReset().mockResolvedValue([
                { id_user: 10, id_sesi_absensi: 1, status: 'HADIR' },
                { id_user: 10, id_sesi_absensi: 2, status: 'IZIN' },
                { id_user: 11, id_sesi_absensi: 2, status: 'TELAT' }
            ]);

            const res = createMockRes();
            await akademikController.getSesiAbsensiByKelas(createMockReq({}, admin, {}, { id: '1' }), res);

            const { data } = res.json.mock.calls[0][0];
            expect(data.map((s) => [s.id_sesi_absensi, s.total_peserta, s.jumlah_hadir])).toEqual([[2, 2, 1], [1, 1, 1]]);
            expect(prisma.absensi.findMany).toHaveBeenCalledWith(expect.objectContaining({
                where: expect.objectContaining({ id_sesi_absensi: { in: [2, 1] }, deletedAt: null })
            }));
        });
    });

    /**
     * JADWAL PENGGANTI: class id from the route, jam fields stored, tanggal_asli on the class day, students notified
     */
    describe('createJadwalPengganti', () => {
        const ownDosen = { id_user: 2, role: 'DOSEN' };
        // hari 3 = Rabu; 14/10/2026 is a Wednesday
        const kelas = { id_kelas: 5, id_dosen: 2, hari: 3, nama_kelas: 'IF-01', matakuliah: { nama_matakuliah: 'Basis Data' } };
        const ganti = {
            tanggal_asli: '2026-10-14',
            status: 'GANTI_JADWAL',
            alasan: 'Dosen dinas luar',
            tanggal_ganti: '2026-10-16',
            jam_mulai_ganti: '09:00:00',
            jam_berakhir_ganti: '11:00:00',
            ruangan_ganti: 'B202'
        };

        const call = async (body, { user = ownDosen, id = '5' } = {}) => {
            const res = createMockRes();
            const next = jest.fn();
            await akademikController.createJadwalPengganti(createMockReq(body, user, {}, { id }), res, next);
            return { res, next };
        };

        beforeEach(() => {
            prisma.kelas.findFirst.mockReset().mockResolvedValue(kelas);
            prisma.jadwalPengganti.create.mockReset().mockImplementation(async ({ data }) => ({
                id_jadwal_pengganti: 40, ...data, kelas
            }));
            sendJadwalPenggantiNotification.mockReset().mockResolvedValue(undefined);
        });

        test('takes the class from the route parameter, not from the body', async () => {
            const { res } = await call({ ...ganti, id_kelas: 99 });

            expect(res.status).toHaveBeenCalledWith(201);
            expect(prisma.kelas.findFirst).toHaveBeenCalledWith(expect.objectContaining({
                where: expect.objectContaining({ id_kelas: 5, deletedAt: null })
            }));
            expect(prisma.jadwalPengganti.create).toHaveBeenCalledWith(expect.objectContaining({
                data: expect.objectContaining({ id_kelas: 5, createdBy: 2 })
            }));
        });

        test('stores jam_mulai_ganti / jam_berakhir_ganti and returns them as HH:MM:SS', async () => {
            const { res } = await call({ ...ganti, jam_mulai_ganti: '9:00' });

            const { data } = prisma.jadwalPengganti.create.mock.calls[0][0];
            expect(data.jam_mulai_ganti).toEqual(new Date('1970-01-01T09:00:00.000Z'));
            expect(data.jam_berakhir_ganti).toEqual(new Date('1970-01-01T11:00:00.000Z'));
            expect(data.ruangan_ganti).toBe('B202');
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                data: expect.objectContaining({ jam_mulai_ganti: '09:00:00', jam_berakhir_ganti: '11:00:00' })
            }));
        });

        test('tanggal_asli must fall on the class day (hari)', async () => {
            // 15/10/2026 is a Thursday
            const { res } = await call({ ...ganti, tanggal_asli: '2026-10-15' });

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Tanggal asli harus jatuh pada hari Rabu sesuai jadwal kelas'
            });
            expect(prisma.jadwalPengganti.create).not.toHaveBeenCalled();
            expect(sendJadwalPenggantiNotification).not.toHaveBeenCalled();
        });

        test('the class day is the Jakarta day: 00:30 WIB Wednesday (still Tuesday in UTC) is accepted', async () => {
            const { res } = await call({ ...ganti, tanggal_asli: '2026-10-13T17:30:00.000Z' });

            expect(res.status).toHaveBeenCalledWith(201);
        });

        test('a date-time without offset (as the mobile app sends it) is read as WIB', async () => {
            const { res } = await call({ ...ganti, tanggal_asli: '2026-10-14T00:00:00.000', tanggal_ganti: '2026-10-16T00:00:00.000' });

            expect(res.status).toHaveBeenCalledWith(201);
            const { data } = prisma.jadwalPengganti.create.mock.calls[0][0];
            expect(data.tanggal_asli).toEqual(new Date('2026-10-13T17:00:00.000Z'));
            expect(data.tanggal_ganti).toEqual(new Date('2026-10-15T17:00:00.000Z'));
        });

        test.each([
            ['equal to', '09:00:00', '09:00:00'],
            ['before', '11:00:00', '09:00:00']
        ])('jam_berakhir_ganti %s jam_mulai_ganti is a 400', async (_label, mulai, berakhir) => {
            const { res } = await call({ ...ganti, jam_mulai_ganti: mulai, jam_berakhir_ganti: berakhir });

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Jam berakhir harus setelah jam mulai' });
            expect(prisma.jadwalPengganti.create).not.toHaveBeenCalled();
        });

        test('only one of the two jam fields is a 400', async () => {
            const { res } = await call({ ...ganti, jam_berakhir_ganti: undefined });

            expect(res.status).toHaveBeenCalledWith(400);
            expect(prisma.jadwalPengganti.create).not.toHaveBeenCalled();
        });

        test.each([['25:00:00'], ['jam 9'], ['09:60']])('an invalid jam (%s) is a 400', async (jam) => {
            const { res } = await call({ ...ganti, jam_mulai_ganti: jam });

            expect(res.status).toHaveBeenCalledWith(400);
            expect(prisma.jadwalPengganti.create).not.toHaveBeenCalled();
        });

        test('an invalid tanggal_asli is a 400', async () => {
            const { res } = await call({ ...ganti, tanggal_asli: 'besok' });

            expect(res.status).toHaveBeenCalledWith(400);
            expect(prisma.jadwalPengganti.create).not.toHaveBeenCalled();
        });

        test('LIBUR does not store replacement date, time or room', async () => {
            const { res } = await call({ ...ganti, status: 'LIBUR' });

            expect(res.status).toHaveBeenCalledWith(201);
            expect(prisma.jadwalPengganti.create.mock.calls[0][0].data).toMatchObject({
                status: 'LIBUR', tanggal_ganti: null, jam_mulai_ganti: null, jam_berakhir_ganti: null, ruangan_ganti: null
            });
        });

        test('notifies the enrolled students after the record is saved', async () => {
            await call(ganti);

            expect(sendJadwalPenggantiNotification).toHaveBeenCalledWith(5, expect.objectContaining({
                idJadwalPengganti: 40,
                namaKelas: 'IF-01',
                namaMatakuliah: 'Basis Data',
                status: 'GANTI_JADWAL',
                tanggalAsli: new Date('2026-10-13T17:00:00.000Z'),
                tanggalGanti: new Date('2026-10-15T17:00:00.000Z'),
                jamMulaiGanti: '09:00:00',
                jamBerakhirGanti: '11:00:00',
                ruanganGanti: 'B202',
                alasan: 'Dosen dinas luar'
            }));
            expect(prisma.jadwalPengganti.create.mock.invocationCallOrder[0])
                .toBeLessThan(sendJadwalPenggantiNotification.mock.invocationCallOrder[0]);
        });

        test('a failing notification does not fail the request', async () => {
            sendJadwalPenggantiNotification.mockRejectedValue(new Error('FCM down'));

            const { res, next } = await call(ganti);
            await new Promise((resolve) => setImmediate(resolve));

            expect(res.status).toHaveBeenCalledWith(201);
            expect(next).not.toHaveBeenCalled();
        });

        test('a dosen of another class gets 403', async () => {
            const { res } = await call(ganti, { user: { id_user: 3, role: 'DOSEN' } });

            expect(res.status).toHaveBeenCalledWith(403);
            expect(prisma.jadwalPengganti.create).not.toHaveBeenCalled();
            expect(sendJadwalPenggantiNotification).not.toHaveBeenCalled();
        });

        test('a non-numeric class id is a 400', async () => {
            const { res } = await call(ganti, { id: 'abc' });

            expect(res.status).toHaveBeenCalledWith(400);
            expect(prisma.kelas.findFirst).not.toHaveBeenCalled();
        });
    });

    /**
     * Stored replacement times are shown as HH:MM:SS in the daily and weekly schedule
     */
    describe('replacement times in the schedule views', () => {
        const admin = { id_user: 1, role: 'ADMIN' };

        beforeEach(() => {
            prisma.$queryRaw.mockReset().mockResolvedValue([{ id_kelas: 3, jam_mulai: '13:00:00', jam_berakhir: '15:00:00' }]);
            prisma.jadwalPengganti.findMany.mockReset().mockResolvedValue([{ id_kelas: 3 }]);
            prisma.kelas.findMany.mockReset().mockResolvedValue([{
                id_kelas: 3, nama_kelas: 'C', hari: 5, ruangan: 'R1', matakuliah: {}, dosen: {}, _count: { peserta: 0 }, sesiAbsensi: [],
                jadwalPengganti: [{
                    id_jadwal_pengganti: 9,
                    status: 'GANTI_JADWAL',
                    tanggal_asli: new Date('2026-10-15T17:00:00Z'),
                    // Wednesday 14/10 in Jakarta
                    tanggal_ganti: new Date('2026-10-13T17:00:00Z'),
                    jam_mulai_ganti: new Date('1970-01-01T09:00:00Z'),
                    jam_berakhir_ganti: new Date('1970-01-01T11:00:00Z'),
                    ruangan_ganti: 'Lab',
                    alasan: 'Rapat'
                }]
            }]);
        });

        test('getKelasHariIni uses the replacement start and end time', async () => {
            useFakeNow(AFTER_MIDNIGHT_WIB);

            const res = createMockRes();
            await akademikController.getKelasHariIni(createMockReq({}, admin), res);

            const [moved] = res.json.mock.calls[0][0].data;
            expect(moved).toMatchObject({ id_kelas: 3, jam_mulai: '09:00:00', jam_berakhir: '11:00:00', ruangan: 'Lab' });
        });

        test('getKelasWithHari uses the replacement start and end time', async () => {
            useFakeNow(AFTER_MIDNIGHT_WIB);

            const res = createMockRes();
            await akademikController.getKelasWithHari(createMockReq({}, admin), res);

            const [moved] = res.json.mock.calls[0][0].data.Rabu;
            expect(moved).toMatchObject({ id_kelas: 3, jam_mulai: '09:00:00', jam_berakhir: '11:00:00', ruangan: 'Lab' });
            expect(moved.override).toMatchObject({ jam_mulai_ganti: '09:00:00', jam_berakhir_ganti: '11:00:00' });
        });
    });
});
