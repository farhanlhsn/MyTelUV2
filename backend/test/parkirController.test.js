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
    params: {},
    app: {
        get: jest.fn().mockReturnValue(null) // Mock Socket.io getter
    }
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

            // Mock atomic capacity update
            prisma.$executeRaw.mockResolvedValue(1);

            // Mock Log Creation
            prisma.logParkir.create.mockResolvedValue({ id_log_parkir: 100 });

            // Mock Upload
            uploadFile.mockResolvedValue({ fileUrl: 'http://img.com' });

            const req = createMockReq(validBody, validHeaders, { buffer: 'buf', originalname: 'a.jpg' });
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(prisma.$executeRaw).toHaveBeenCalled();
            expect(prisma.logParkir.create).toHaveBeenCalled();
            expect(sendParkingNotification).toHaveBeenCalledWith(1, 'MASUK', expect.anything(), 'Gedung A');
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                data: expect.objectContaining({
                    gate_action: 'OPEN'
                })
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

            // Mock atomic capacity update returns 0 because full
            prisma.$executeRaw.mockResolvedValue(0);

            const req = createMockReq(validBody, validHeaders);
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                data: expect.objectContaining({
                    gate_action: 'DENY'
                }),
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
                status: 'error',
                data: expect.objectContaining({
                    gate_action: 'DENY'
                }),
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
                status: 'error',
                data: expect.objectContaining({
                    gate_action: 'DENY'
                }),
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
                id_parkiran: 1, nama_parkiran: 'Gedung A', live_kapasitas: 10
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
                status: 'success',
                data: expect.objectContaining({
                    gate_action: 'OPEN'
                })
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

            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                data: expect.objectContaining({
                    gate_action: 'DENY'
                })
            }));
        });
    });
});

describe('Parkir Controller - exportParkirLogs & manualOverride', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    describe('exportParkirLogs', () => {
        test('should export CSV successfully if logs exist', async () => {
            const mockLogs = [
                {
                    id_log_parkir: 1,
                    timestamp: new Date('2026-05-18T10:00:00Z'),
                    type: 'MASUK',
                    confidence: 0.95,
                    image_url: 'http://img.com/1.jpg',
                    face_image_url: 'http://img.com/face1.jpg',
                    kendaraan: { plat_nomor: 'D1234ABC', nama_kendaraan: 'Mobil Honda' },
                    user: { nama: 'Farhan', username: 'farhan' },
                    parkiran: { nama_parkiran: 'Gedung A' }
                }
            ];

            prisma.logParkir.findMany.mockResolvedValue(mockLogs);

            const req = createMockReq();
            req.query = { parkiran_id: '1', from: '2026-05-01', to: '2026-05-31' };
            
            const res = {
                status: jest.fn().mockReturnThis(),
                setHeader: jest.fn(),
                send: jest.fn()
            };

            await parkirController.exportParkirLogs(req, res);

            expect(prisma.logParkir.findMany).toHaveBeenCalledWith(expect.objectContaining({
                where: expect.objectContaining({
                    id_parkiran: 1,
                    timestamp: expect.objectContaining({
                        gte: expect.any(Date),
                        lte: expect.any(Date)
                    })
                })
            }));
            expect(res.setHeader).toHaveBeenCalledWith('Content-Type', 'text/csv; charset=utf-8');
            expect(res.setHeader).toHaveBeenCalledWith('Content-Disposition', expect.stringContaining('attachment; filename='));
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.send).toHaveBeenCalledWith(expect.stringContaining('"ID Log","Timestamp","Tipe","Plat Nomor","Kendaraan","User","Username","Parkiran"'));
        });

        test('should return 404 if no logs found', async () => {
            prisma.logParkir.findMany.mockResolvedValue([]);

            const req = createMockReq();
            const res = createMockRes();

            await parkirController.exportParkirLogs(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                message: expect.stringContaining('Tidak ada data')
            }));
        });
    });

    describe('manualOverride', () => {
        test('should allow manual override entry successfully', async () => {
            prisma.$queryRaw.mockResolvedValue([{
                id_parkiran: 1,
                nama_parkiran: 'Gedung A',
                kapasitas: 10,
                live_kapasitas: 5
            }]);

            prisma.kendaraan.findFirst.mockResolvedValue({
                id_kendaraan: 2,
                plat_nomor: 'D9999XYZ',
                user: { id_user: 5, nama: 'Budi' }
            });

            prisma.$executeRaw.mockResolvedValue(1); // successfully incremented capacity
            prisma.logParkir.create.mockResolvedValue({ id_log_parkir: 150 });

            // Mock Socket.io
            const mockIo = { emit: jest.fn() };
            const req = createMockReq({ plat_nomor: 'D 9999 XYZ', gate_type: 'MASUK' });
            req.params = { id: '1' };
            req.app.get.mockReturnValue(mockIo);

            // Re-mock prisma queryRaw for socket capacity check
            prisma.$queryRaw.mockResolvedValueOnce([{
                id_parkiran: 1,
                nama_parkiran: 'Gedung A',
                kapasitas: 10,
                live_kapasitas: 5
            }]).mockResolvedValueOnce([{
                live_kapasitas: 6
            }]);

            const res = createMockRes();

            await parkirController.manualOverride(req, res);

            expect(prisma.$executeRaw).toHaveBeenCalled();
            expect(prisma.logParkir.create).toHaveBeenCalled();
            expect(mockIo.emit).toHaveBeenCalledWith('parking_update', expect.objectContaining({
                id_parkiran: 1,
                live_kapasitas: 6,
                kapasitas: 10
            }));
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                message: expect.stringContaining('Override berhasil')
            }));
        });

        test('should allow manual override exit successfully', async () => {
            prisma.$queryRaw.mockResolvedValueOnce([{
                id_parkiran: 1,
                nama_parkiran: 'Gedung A',
                kapasitas: 10,
                live_kapasitas: 5
            }]);

            prisma.kendaraan.findFirst.mockResolvedValue({
                id_kendaraan: 2,
                plat_nomor: 'D9999XYZ',
                user: { id_user: 5 }
            });

            prisma.logParkir.create.mockResolvedValue({ id_log_parkir: 151 });

            const mockIo = { emit: jest.fn() };
            const req = createMockReq({ plat_nomor: 'D9999XYZ', gate_type: 'KELUAR' });
            req.params = { id: '1' };
            req.app.get.mockReturnValue(mockIo);

            prisma.$queryRaw.mockResolvedValueOnce([{
                live_kapasitas: 4
            }]);

            const res = createMockRes();

            await parkirController.manualOverride(req, res);

            expect(prisma.$executeRaw).toHaveBeenCalled(); // decrements capacity
            expect(mockIo.emit).toHaveBeenCalledWith('parking_update', expect.objectContaining({
                id_parkiran: 1,
                live_kapasitas: 4
            }));
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('should fail if required fields are missing', async () => {
            const req = createMockReq({});
            const res = createMockRes();

            await parkirController.manualOverride(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
        });

        test('should fail if vehicle not found', async () => {
            prisma.$queryRaw.mockResolvedValue([{ id_parkiran: 1, kapasitas: 10 }]);
            prisma.kendaraan.findFirst.mockResolvedValue(null);

            const req = createMockReq({ plat_nomor: 'UNKNOWN', gate_type: 'MASUK' });
            const res = createMockRes();

            await parkirController.manualOverride(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
        });
    });
});

