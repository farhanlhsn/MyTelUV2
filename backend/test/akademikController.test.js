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
    user: { findFirst: jest.fn() },
    semester: { findFirst: jest.fn() },
    pesertaKelas: { findFirst: jest.fn(), findMany: jest.fn(), findUnique: jest.fn(), create: jest.fn(), update: jest.fn(), count: jest.fn() },
    jadwalPengganti: { findMany: jest.fn() },
    $transaction: jest.fn(),
    $queryRaw: jest.fn(),
    $executeRaw: jest.fn(),
}));

jest.mock('../utils/akademikHelpers', () => ({
    parsePagination: jest.fn().mockReturnValue({ page: 1, limit: 10, skip: 0 }),
    buildPaginationResponse: jest.fn().mockImplementation((total, page, limit) => ({ total, page, limit })),
    isDosenAuthorizedForKelas: jest.fn(),
    haversineDistance: jest.fn(),
}));

// Import modules
const prisma = require('../utils/prisma');
const akademikController = require('../controllers/akademikController');

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

        test('should create kelas successfully', async () => {
            prisma.semester.findFirst.mockResolvedValue({ id_semester: 1, nama_semester: 'Genap 2026/2027' });
            prisma.matakuliah.findFirst.mockResolvedValue({ id_matakuliah: 1 });
            prisma.user.findFirst.mockResolvedValue({ id_user: 5, role: 'DOSEN' });
            prisma.$queryRaw.mockResolvedValue([]); // No conflict
            prisma.$executeRaw.mockResolvedValue([{}]); // Insert
            prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 1 });

            const req = createMockReq(validBody);
            const res = createMockRes();

            await akademikController.createKelas(req, res);

            expect(prisma.$executeRaw).toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(201);
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
        });
    });
});
