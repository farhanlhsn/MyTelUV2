/**
 * Unit Testing - Parkir Controller
 * 
 * @author MyTelUV2 Team
 * @date 2026-01-04
 */

// Mock dependencies
jest.mock('../utils/prisma', () => ({
    kendaraan: { findMany: jest.fn(), findFirst: jest.fn() },
    logParkir: { count: jest.fn(), findMany: jest.fn(), findFirst: jest.fn(), create: jest.fn(), update: jest.fn() },
    parkiran: { findUnique: jest.fn() },
    $queryRaw: jest.fn(),
    $executeRaw: jest.fn(),
    $executeRawUnsafe: jest.fn(),
    $transaction: jest.fn(),
}));

jest.mock('../utils/r2FileHandler', () => ({
    uploadFile: jest.fn(),
}));

jest.mock('../utils/firebase', () => ({
    sendParkingNotification: jest.fn().mockResolvedValue(true),
}));

// Import modules
const prisma = require('../utils/prisma');
const { uploadFile } = require('../utils/r2FileHandler');
const { sendParkingNotification } = require('../utils/firebase');
const parkirController = require('../controllers/parkirController');

// Helper functions
const createMockReq = (body = {}, headers = {}, file = null) => ({
    body,
    headers,
    file,
    user: { id_user: 1 }, // Default user for other endpoints
    query: {},
    params: {}
});

const createMockRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

describe('Parkir Controller - processEdgeEntry', () => {

    beforeEach(() => {
        jest.clearAllMocks();
        process.env.EDGE_DEVICE_SECRET = 'secret123';
    });

    const validHeaders = { 'x-edge-secret': 'secret123' };
    const validBody = {
        plate_text: 'D 1234 ABC',
        parkiran_id: '1',
        gate_type: 'MASUK'
    };

    /**
     * AUTH & VALIDATION
     */
    test('should Deny if secret is invalid', async () => {
        const req = createMockReq(validBody, { 'x-edge-secret': 'wrong' });
        const res = createMockRes();
        await parkirController.processEdgeEntry(req, res);
        expect(res.status).toHaveBeenCalledWith(401);
    });

    test('should Deny if fields missing', async () => {
        const req = createMockReq({}, validHeaders);
        const res = createMockRes();
        await parkirController.processEdgeEntry(req, res);
        expect(res.status).toHaveBeenCalledWith(400);
    });

    /**
     * ENTRY (MASUK) SCENARIOS
     */
    describe('Gate MASUK', () => {

        test('should Allow Entry if valid and not full', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue({
                id_kendaraan: 1,
                plat_nomor: 'D1234ABC',
                user: { id_user: 1, nama: 'User' }
            });

            // Mock Parkiran query
            prisma.$queryRaw.mockResolvedValueOnce([{
                id_parkiran: 1,
                nama_parkiran: 'Gedung A',
                kapasitas: 100,
                live_kapasitas: 50
            }]);

            // Mock Last Log (not inside)
            prisma.logParkir.findFirst.mockResolvedValue(null);

            // Mock Transaction (Create Log + Update Live Capacity)
            prisma.$transaction.mockResolvedValue([{ id_log_parkir: 100 }, 1]);

            // Mock Upload
            uploadFile.mockResolvedValue({ fileUrl: 'http://img.com' });

            const req = createMockReq(validBody, validHeaders, { buffer: 'buf', originalname: 'a.jpg' });
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(prisma.$transaction).toHaveBeenCalled();
            expect(sendParkingNotification).toHaveBeenCalledWith(1, 'MASUK', expect.anything(), 'Gedung A');
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                gate_action: 'OPEN',
                success: true
            }));
        });

        test('should Deny Entry if Parking Full', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue({ id_kendaraan: 1, plat_nomor: 'D1234ABC' });
            prisma.$queryRaw.mockResolvedValueOnce([{
                id_parkiran: 1,
                nama_parkiran: 'Gedung A',
                kapasitas: 100,
                live_kapasitas: 100 // FULL
            }]);

            const req = createMockReq(validBody, validHeaders);
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                gate_action: 'DENY',
                message: expect.stringContaining('penuh')
            }));
        });

        test('should Deny Entry if Already Inside', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue({ id_kendaraan: 1, plat_nomor: 'D1234ABC' });
            prisma.$queryRaw.mockResolvedValueOnce([{
                id_parkiran: 1, kapasitas: 100, live_kapasitas: 50
            }]);

            // Last log was entry -> car is inside
            prisma.logParkir.findFirst.mockResolvedValue({ type: 'MASUK' });

            const req = createMockReq(validBody, validHeaders);
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                gate_action: 'DENY',
                message: expect.stringContaining('sudah berada di dalam')
            }));
        });

        test('should Deny if Vehicle Not Found', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(null);
            const req = createMockReq(validBody, validHeaders);
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);
            expect(res.status).toHaveBeenCalledWith(404);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                gate_action: 'DENY',
                message: expect.stringContaining('tidak terdaftar')
            }));
        });
    });

    /**
     * EXIT (KELUAR) SCENARIOS
     */
    describe('Gate KELUAR', () => {
        const exitBody = { ...validBody, gate_type: 'KELUAR' };

        test('should Allow Exit if vehicle is inside', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue({
                id_kendaraan: 1,
                plat_nomor: 'D1234ABC',
                user: { id_user: 1, nama: 'User' }
            });
            prisma.$queryRaw.mockResolvedValueOnce([{
                id_parkiran: 1, nama_parkiran: 'Gedung A'
            }]);

            // Last log was MASUK -> car is inside
            prisma.logParkir.findFirst.mockResolvedValue({ type: 'MASUK' });

            prisma.$transaction.mockResolvedValue([{ id_log_parkir: 101 }, 1]);

            const req = createMockReq(exitBody, validHeaders);
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(prisma.$transaction).toHaveBeenCalled(); // create exit log + decrement
            expect(sendParkingNotification).toHaveBeenCalledWith(1, 'KELUAR', expect.anything(), 'Gedung A');
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                gate_action: 'OPEN'
            }));
        });

        test('should Deny Exit if vehicle not inside', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue({ id_kendaraan: 1 });
            prisma.$queryRaw.mockResolvedValueOnce([{ id_parkiran: 1 }]);

            // Last log was KELUAR or null -> car is outside
            prisma.logParkir.findFirst.mockResolvedValue({ type: 'KELUAR' });

            const req = createMockReq(exitBody, validHeaders);
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                gate_action: 'DENY'
            }));
        });
    });
});
