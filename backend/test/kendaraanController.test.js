/**
 * Unit Testing - Kendaraan Controller
 * 
 * @author MyTelUV2 Team
 * @date 2026-01-04
 */

// Mock dependencies
jest.mock('../utils/prisma', () => ({
    kendaraan: {
        findUnique: jest.fn(),
        create: jest.fn(),
        findMany: jest.fn(),
        delete: jest.fn(),
        update: jest.fn(),
        count: jest.fn(),
    },
    user: {
        findUnique: jest.fn(),
    }
}));

jest.mock('../utils/r2FileHandler', () => ({
    uploadFile: jest.fn(),
    deleteFile: jest.fn(),
    fileExists: jest.fn(),
}));

jest.mock('../utils/firebase', () => ({
    sendPushNotification: jest.fn(),
}));

// Import modules
const prisma = require('../utils/prisma');
const { uploadFile, deleteFile, fileExists } = require('../utils/r2FileHandler');
const { sendPushNotification } = require('../utils/firebase');
const kendaraanController = require('../controllers/kendaraanController');

// Helper functions
const createMockReq = (body = {}, user = { id_user: 1 }, files = {}, params = {}, query = {}) => ({
    body,
    user,
    files,
    params,
    query,
});

const createMockRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

describe('Kendaraan Controller Tests', () => {

    beforeEach(() => {
        jest.clearAllMocks();
    });

    /**
     * REGISTER KENDARAAN
     */
    describe('registerKendaraan', () => {
        const mockFiles = {
            fotoKendaraan: [
                { buffer: Buffer.from('1'), originalname: '1.jpg', mimetype: 'image/jpeg' },
                { buffer: Buffer.from('2'), originalname: '2.jpg', mimetype: 'image/jpeg' },
                { buffer: Buffer.from('3'), originalname: '3.jpg', mimetype: 'image/jpeg' }
            ],
            fotoSTNK: [
                { buffer: Buffer.from('stnk'), originalname: 'stnk.jpg', mimetype: 'image/jpeg' }
            ]
        };
        const mockBody = { plat_nomor: 'D 1234 ABC', nama_kendaraan: 'Motor' };

        test('should register kendaraan successfully', async () => {
            uploadFile.mockResolvedValue({ fileUrl: 'http://url.com/img.jpg' });
            prisma.kendaraan.findUnique.mockResolvedValue(null); // Plat available
            prisma.kendaraan.create.mockResolvedValue({ id_kendaraan: 1, ...mockBody });

            const req = createMockReq(mockBody, { id_user: 1 }, mockFiles);
            const res = createMockRes();

            await kendaraanController.registerKendaraan(req, res);

            expect(uploadFile).toHaveBeenCalledTimes(4); // 3 kendaraan + 1 stnk
            expect(prisma.kendaraan.create).toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(201);
        });

        test('should fail if less than 3 vehicle photos', async () => {
            const badFiles = {
                ...mockFiles,
                fotoKendaraan: [mockFiles.fotoKendaraan[0]] // Only 1
            };
            const req = createMockReq(mockBody, { id_user: 1 }, badFiles);
            const res = createMockRes();

            await kendaraanController.registerKendaraan(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                message: expect.stringContaining('Exactly 3')
            }));
        });

        test('should fail if stnk photo missing', async () => {
            const badFiles = { ...mockFiles, fotoSTNK: [] };
            const req = createMockReq(mockBody, { id_user: 1 }, badFiles);
            const res = createMockRes();

            await kendaraanController.registerKendaraan(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                message: 'fotoSTNK is required'
            }));
        });

        test('should fail if plat already registered', async () => {
            prisma.kendaraan.findUnique.mockResolvedValue({ id_kendaraan: 99 });
            const req = createMockReq(mockBody, { id_user: 1 }, mockFiles);
            const res = createMockRes();

            await kendaraanController.registerKendaraan(req, res);

            expect(res.status).toHaveBeenCalledWith(409);
        });

        test('should cleanup files if db create fails', async () => {
            uploadFile.mockResolvedValue({ fileUrl: 'http://url.com/img.jpg' });
            prisma.kendaraan.findUnique.mockResolvedValue(null);
            prisma.kendaraan.create.mockRejectedValue(new Error('DB Error'));
            fileExists.mockResolvedValue(true);

            const req = createMockReq(mockBody, { id_user: 1 }, mockFiles);
            const res = createMockRes();

            await kendaraanController.registerKendaraan(req, res);

            expect(deleteFile).toHaveBeenCalled(); // Should attempt cleanup
            expect(res.status).toHaveBeenCalledWith(500);
        });
    });

    /**
     * VERIFY KENDARAAN (ADMIN)
     */
    describe('verifyKendaraan', () => {
        test('should verify and send notification', async () => {
            const req = createMockReq({ id_kendaraan: 1, id_user: 2 });
            const res = createMockRes();

            prisma.kendaraan.findUnique.mockResolvedValue({
                id_kendaraan: 1,
                statusVerif: false,
                plat_nomor: 'D 1 A',
                nama_kendaraan: 'Tesla'
            });
            prisma.kendaraan.update.mockResolvedValue({});
            prisma.user.findUnique.mockResolvedValue({ fcm_token: 'token123' });

            await kendaraanController.verifyKendaraan(req, res);

            expect(prisma.kendaraan.update).toHaveBeenCalledWith({
                where: { id_kendaraan: 1, id_user: 2 },
                data: expect.objectContaining({ statusVerif: true })
            });

            expect(sendPushNotification).toHaveBeenCalledWith(
                'token123',
                expect.stringContaining('Disetujui'),
                expect.any(String),
                expect.anything()
            );

            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('should fail if vehicle not found', async () => {
            const req = createMockReq({ id_kendaraan: 999, id_user: 2 });
            const res = createMockRes();
            prisma.kendaraan.findUnique.mockResolvedValue(null);

            await kendaraanController.verifyKendaraan(req, res);
            expect(res.status).toHaveBeenCalledWith(404);
        });

        test('should fail if already verified', async () => {
            const req = createMockReq({ id_kendaraan: 1, id_user: 2 });
            const res = createMockRes();
            prisma.kendaraan.findUnique.mockResolvedValue({ statusVerif: true });

            await kendaraanController.verifyKendaraan(req, res);
            expect(res.status).toHaveBeenCalledWith(400);
        });
    });

    /**
     * REJECT KENDARAAN
     */
    describe('rejectKendaraan', () => {
        test('should reject and send notification', async () => {
            const req = createMockReq({ id_kendaraan: 1, id_user: 2, feedback: 'Buram' });
            const res = createMockRes();

            prisma.kendaraan.findUnique.mockResolvedValue({
                id_kendaraan: 1,
                status_pengajuan: 'MENUNGGU',
                plat_nomor: 'D 1 A'
            });
            prisma.user.findUnique.mockResolvedValue({ fcm_token: 'token123' });

            await kendaraanController.rejectKendaraan(req, res);

            expect(prisma.kendaraan.update).toHaveBeenCalledWith({
                where: { id_kendaraan: 1, id_user: 2 },
                data: expect.objectContaining({
                    statusVerif: false,
                    status_pengajuan: 'DITOLAK',
                    feedback: 'Buram'
                })
            });
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('should fail with 400 if feedback missing', async () => {
            const req = createMockReq({ id_kendaraan: 1, id_user: 2, feedback: '' });
            const res = createMockRes();
            await kendaraanController.rejectKendaraan(req, res);
            expect(res.status).toHaveBeenCalledWith(400);
        });
    });

    /**
     * DELETE KENDARAAN
     */
    describe('deleteKendaraan', () => {
        test('should delete vehicle and files', async () => {
            const req = createMockReq({}, { id_user: 1 }, {}, { id_kendaraan: 1 });
            const res = createMockRes();

            prisma.kendaraan.findUnique.mockResolvedValue({
                id_kendaraan: 1,
                fotoKendaraan: ['url1', 'url2'],
                fotoSTNK: 'urlStnk'
            });
            fileExists.mockResolvedValue(true);

            await kendaraanController.deleteKendaraan(req, res);

            expect(deleteFile).toHaveBeenCalledTimes(3); // 2 vehicle + 1 stnk
            expect(prisma.kendaraan.delete).toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(200);
        });
    });
});
