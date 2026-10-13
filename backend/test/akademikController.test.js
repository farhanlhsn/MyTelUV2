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
    jadwalPengganti: { findMany: jest.fn() },
    sesiAbsensi: { findFirst: jest.fn(), findMany: jest.fn(), create: jest.fn(), count: jest.fn() },
    absensi: { findFirst: jest.fn(), findMany: jest.fn(), count: jest.fn(), groupBy: jest.fn() },
    $transaction: jest.fn(),
    $queryRaw: jest.fn(),
    $executeRaw: jest.fn(),
}));

jest.mock('../utils/akademikHelpers', () => ({
    parsePagination: jest.fn().mockReturnValue({ page: 1, limit: 10, skip: 0 }),
    buildPaginationResponse: jest.fn().mockImplementation((total, page, limit) => ({ total, page, limit })),
    isDosenAuthorizedForKelas: jest.fn(),
    haversineDistance: jest.fn(),
    isCountableSession: jest.requireActual('../utils/akademikHelpers').isCountableSession,
    isUniqueViolation: jest.requireActual('../utils/akademikHelpers').isUniqueViolation,
}));

jest.mock('../utils/firebase', () => ({
    sendAbsensiNotification: jest.fn().mockResolvedValue(undefined),
}));

// Import modules
const prisma = require('../utils/prisma');
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

        describe('Class Capacity Check (BF20)', () => {
            test('should block registration if capacity limit reached', async () => {
                prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 1, kapasitas: 5, hari: 1 });
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
                prisma.$queryRaw.mockResolvedValue([]); // No schedule conflict
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
        });

        describe('Schedule Conflict Check (BF18)', () => {
            test('should block registration if class day and time overlap', async () => {
                prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 1, kapasitas: 50, hari: 1 });
                prisma.pesertaKelas.count.mockResolvedValue(10); // Under capacity
                
                // Target class times and queryRaw conflict response
                prisma.$queryRaw
                    .mockResolvedValueOnce([{ jam_mulai: '08:00:00', jam_berakhir: '10:00:00' }]) // target time fetch
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
                    .mockResolvedValueOnce([{ jam_mulai: '08:00:00', jam_berakhir: '10:00:00' }])
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
            expect(rawCalls(tx.$executeRaw, 'FOR UPDATE')).toHaveLength(1);
            expect(tx.$executeRaw.mock.invocationCallOrder[0]).toBeLessThan(tx.pesertaKelas.count.mock.invocationCallOrder[0]);
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
                expect(rawCalls(prisma.$executeRaw, 'FOR UPDATE')).toHaveLength(1);
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
                totalMahasiswaAbsensi: 2,
                averageAbsensiPerMahasiswa: '1.50'
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
            expect(entry.stats).toEqual({ total_sesi: 1, total_hadir: 1, total_tidak_hadir: 0, persentase: '100.0' });
            // The session from before enrollment is not listed; the running one is
            expect(entry.sessions.map((s) => s.id_sesi_absensi)).toEqual([3, 2]);
            expect(entry.sessions[0].is_active).toBe(true);
        });
    });
});
