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
            prisma.matakuliah.findFirst.mockResolvedValue({ id_matakuliah: 1 });
            prisma.user.findFirst.mockResolvedValue({ id_user: 5, role: 'DOSEN' });
            prisma.$queryRaw.mockResolvedValue([{ id_kelas: 99 }]); // Conflict found

            const req = createMockReq(validBody);
            const res = createMockRes();

            await akademikController.createKelas(req, res);

            expect(res.status).toHaveBeenCalledWith(409);
        });

        test('should fail if invali time format', async () => {
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
});
