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
            expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Plat nomor sudah terdaftar' });
        });

        describe('plate normalisation and soft-deleted plates', () => {
            beforeEach(() => {
                uploadFile.mockReset().mockResolvedValue({ fileUrl: 'http://url.com/new.jpg' });
                deleteFile.mockReset().mockResolvedValue(undefined);
                prisma.kendaraan.findUnique.mockReset();
                prisma.kendaraan.count.mockReset().mockResolvedValue(0);
                prisma.kendaraan.create.mockReset().mockResolvedValue({ id_kendaraan: 1 });
                prisma.kendaraan.update.mockReset().mockResolvedValue({ id_kendaraan: 7 });
            });

            test('checks uniqueness and saves against the normalised plate', async () => {
                prisma.kendaraan.findUnique.mockResolvedValue(null);
                const req = createMockReq({ plat_nomor: 'b 1234-xyz', nama_kendaraan: 'Motor' }, { id_user: 1 }, mockFiles);
                const res = createMockRes();

                await kendaraanController.registerKendaraan(req, res);

                expect(prisma.kendaraan.findUnique).toHaveBeenCalledWith({ where: { plat_nomor: 'B1234XYZ' } });
                expect(prisma.kendaraan.create).toHaveBeenCalledWith({
                    data: expect.objectContaining({ plat_nomor: 'B1234XYZ' })
                });
                expect(res.status).toHaveBeenCalledWith(201);
            });

            test('rejects a plate that is empty once normalised, before touching the database', async () => {
                const req = createMockReq({ plat_nomor: '--- ', nama_kendaraan: 'Motor' }, { id_user: 1 }, mockFiles);
                const res = createMockRes();

                await kendaraanController.registerKendaraan(req, res);

                expect(res.status).toHaveBeenCalledWith(400);
                expect(prisma.kendaraan.findUnique).not.toHaveBeenCalled();
                expect(uploadFile).not.toHaveBeenCalled();
            });

            test('still answers 409 when the existing plate row is active', async () => {
                prisma.kendaraan.findUnique.mockResolvedValue({ id_kendaraan: 9, id_user: 2, deletedAt: null });
                const res = createMockRes();

                await kendaraanController.registerKendaraan(createMockReq(mockBody, { id_user: 1 }, mockFiles), res);

                expect(res.status).toHaveBeenCalledWith(409);
                expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Plat nomor sudah terdaftar' });
                expect(prisma.kendaraan.create).not.toHaveBeenCalled();
                expect(prisma.kendaraan.update).not.toHaveBeenCalled();
            });

            test('re-registering a soft-deleted plate reuses that row for the new owner', async () => {
                prisma.kendaraan.findUnique.mockResolvedValue({
                    id_kendaraan: 7,
                    id_user: 2,
                    plat_nomor: 'D1234ABC',
                    deletedAt: new Date('2026-01-01T00:00:00Z'),
                    statusVerif: false,
                    status_pengajuan: 'DISETUJUI',
                    feedback: 'DELETE_REQUEST: dijual',
                    fotoKendaraan: ['http://old/1.jpg', 'http://old/2.jpg', 'http://old/3.jpg'],
                    fotoSTNK: 'http://old/stnk.jpg'
                });
                const res = createMockRes();

                await kendaraanController.registerKendaraan(createMockReq(mockBody, { id_user: 1 }, mockFiles), res);

                expect(prisma.kendaraan.create).not.toHaveBeenCalled();
                expect(prisma.kendaraan.update).toHaveBeenCalledWith({
                    where: { id_kendaraan: 7, deletedAt: { not: null } },
                    data: {
                        id_user: 1,
                        nama_kendaraan: 'Motor',
                        fotoKendaraan: ['http://url.com/new.jpg', 'http://url.com/new.jpg', 'http://url.com/new.jpg'],
                        fotoSTNK: 'http://url.com/new.jpg',
                        statusVerif: false,
                        status_pengajuan: 'MENUNGGU',
                        feedback: null,
                        deletedAt: null,
                        createdAt: expect.any(Date)
                    }
                });
                expect(res.status).toHaveBeenCalledWith(201);
            });

            test('a reused row gets createdAt = now so it appears at the top of the admin pending queue', async () => {
                prisma.kendaraan.findUnique.mockResolvedValue({
                    id_kendaraan: 7,
                    id_user: 2,
                    deletedAt: new Date('2026-01-01T00:00:00Z'),
                    createdAt: new Date('2025-01-01T00:00:00Z'),
                    fotoKendaraan: [],
                    fotoSTNK: 'http://old/stnk.jpg'
                });
                const before = Date.now();

                await kendaraanController.registerKendaraan(createMockReq(mockBody, { id_user: 1 }, mockFiles), createMockRes());

                const { data } = prisma.kendaraan.update.mock.calls[0][0];
                expect(data.createdAt).toBeInstanceOf(Date);
                expect(data.createdAt.getTime()).toBeGreaterThanOrEqual(before);
                expect(data.createdAt.getTime()).toBeLessThanOrEqual(Date.now());
            });

            test('the new owner of a reused row is held to the per-user vehicle limit', async () => {
                prisma.kendaraan.findUnique.mockResolvedValue({ id_kendaraan: 7, id_user: 2, deletedAt: new Date() });
                prisma.kendaraan.count.mockResolvedValue(3);
                const res = createMockRes();

                await kendaraanController.registerKendaraan(createMockReq(mockBody, { id_user: 1 }, mockFiles), res);

                expect(res.status).toHaveBeenCalledWith(400);
                expect(prisma.kendaraan.update).not.toHaveBeenCalled();
            });

            test('removes the previous owner photos of a reused row after the update', async () => {
                prisma.kendaraan.findUnique.mockResolvedValue({
                    id_kendaraan: 7,
                    id_user: 2,
                    deletedAt: new Date(),
                    fotoKendaraan: ['http://old/1.jpg'],
                    fotoSTNK: 'http://old/stnk.jpg'
                });

                await kendaraanController.registerKendaraan(createMockReq(mockBody, { id_user: 1 }, mockFiles), createMockRes());

                expect(deleteFile).toHaveBeenCalledWith('http://old/1.jpg');
                expect(deleteFile).toHaveBeenCalledWith('http://old/stnk.jpg');
            });

            test('a lost race on the unique plate (P2002) answers 409 and cleans up the uploads', async () => {
                const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
                prisma.kendaraan.findUnique.mockResolvedValue(null);
                prisma.kendaraan.create.mockRejectedValue(Object.assign(new Error('Unique constraint failed'), { code: 'P2002' }));
                fileExists.mockResolvedValue(true);
                const res = createMockRes();

                try {
                    await kendaraanController.registerKendaraan(createMockReq(mockBody, { id_user: 1 }, mockFiles), res);

                    expect(res.status).toHaveBeenCalledWith(409);
                    expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Plat nomor sudah terdaftar' });
                    expect(deleteFile).toHaveBeenCalled();
                } finally {
                    errorSpy.mockRestore();
                }
            });

            test('a lost race on a reused row (P2025) answers 409', async () => {
                const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
                prisma.kendaraan.findUnique.mockResolvedValue({ id_kendaraan: 7, id_user: 2, deletedAt: new Date() });
                prisma.kendaraan.update.mockRejectedValue(Object.assign(new Error('Record not found'), { code: 'P2025' }));
                fileExists.mockResolvedValue(true);
                const res = createMockRes();

                try {
                    await kendaraanController.registerKendaraan(createMockReq(mockBody, { id_user: 1 }, mockFiles), res);

                    expect(res.status).toHaveBeenCalledWith(409);
                    expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Plat nomor sudah terdaftar' });
                } finally {
                    errorSpy.mockRestore();
                }
            });
        });

        test('should cleanup files if db create fails', async () => {
            const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
            uploadFile.mockResolvedValue({ fileUrl: 'http://url.com/img.jpg' });
            prisma.kendaraan.findUnique.mockResolvedValue(null);
            prisma.kendaraan.create.mockRejectedValue(new Error('DB Error'));
            fileExists.mockResolvedValue(true);

            const req = createMockReq(mockBody, { id_user: 1 }, mockFiles);
            const res = createMockRes();

            try {
                await kendaraanController.registerKendaraan(req, res);

                expect(deleteFile).toHaveBeenCalled(); // Should attempt cleanup
                expect(res.status).toHaveBeenCalledWith(500);
            } finally {
                errorSpy.mockRestore();
            }
        });

        describe('5xx responses never leak error.message', () => {
            const leaky = new Error('connect ECONNREFUSED r2.internal.example:9000 password=hunter2');
            let errorSpy;

            beforeEach(() => {
                errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
                prisma.kendaraan.findUnique.mockResolvedValueOnce(null); // plate is free
                prisma.kendaraan.count.mockResolvedValueOnce(0);
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

            test('vehicle photo upload failure', async () => {
                uploadFile.mockReset().mockRejectedValueOnce(leaky);
                const res = createMockRes();

                await kendaraanController.registerKendaraan(createMockReq(mockBody, { id_user: 1 }, mockFiles), res);

                expectGeneric500(res);
            });

            test('STNK upload failure', async () => {
                const ok = { fileUrl: 'http://url.com/img.jpg' };
                uploadFile.mockReset()
                    .mockResolvedValueOnce(ok).mockResolvedValueOnce(ok).mockResolvedValueOnce(ok)
                    .mockRejectedValueOnce(leaky);
                const res = createMockRes();

                await kendaraanController.registerKendaraan(createMockReq(mockBody, { id_user: 1 }, mockFiles), res);

                expectGeneric500(res);
            });

            test('database save failure', async () => {
                uploadFile.mockReset().mockResolvedValue({ fileUrl: 'http://url.com/img.jpg' });
                prisma.kendaraan.create.mockRejectedValueOnce(leaky);
                const res = createMockRes();

                await kendaraanController.registerKendaraan(createMockReq(mockBody, { id_user: 1 }, mockFiles), res);

                expectGeneric500(res);
            });
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

        test('should verify and approve vehicle deletion request (soft delete)', async () => {
            const req = createMockReq({ id_kendaraan: 1, id_user: 2 });
            const res = createMockRes();

            prisma.kendaraan.findUnique.mockResolvedValue({
                id_kendaraan: 1,
                statusVerif: false,
                plat_nomor: 'D 1 A',
                nama_kendaraan: 'Tesla',
                feedback: 'DELETE_REQUEST: Ganti kendaraan'
            });
            prisma.kendaraan.update.mockResolvedValue({});
            prisma.user.findUnique.mockResolvedValue({ fcm_token: 'token123' });

            await kendaraanController.verifyKendaraan(req, res);

            expect(prisma.kendaraan.update).toHaveBeenCalledWith({
                where: { id_kendaraan: 1 },
                data: expect.objectContaining({
                    deletedAt: expect.any(Date),
                    statusVerif: false
                })
            });

            expect(sendPushNotification).toHaveBeenCalledWith(
                'token123',
                expect.stringContaining('Kendaraan Dihapus'),
                expect.any(String),
                expect.anything()
            );

            expect(res.status).toHaveBeenCalledWith(200);
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

        test('rejecting a delete request on an approved vehicle keeps it DISETUJUI and verified', async () => {
            const req = createMockReq({ id_kendaraan: 1, id_user: 2, feedback: 'Masih dipakai' });
            const res = createMockRes();

            prisma.kendaraan.findUnique.mockResolvedValue({
                id_kendaraan: 1,
                plat_nomor: 'D1A',
                status_pengajuan: 'DISETUJUI',
                statusVerif: true,
                feedback: 'DELETE_REQUEST: Ganti plat'
            });
            prisma.kendaraan.update.mockResolvedValue({});
            prisma.user.findUnique.mockResolvedValue({ fcm_token: null });

            await kendaraanController.rejectKendaraan(req, res);

            const { data } = prisma.kendaraan.update.mock.calls[0][0];
            expect(data.status_pengajuan).toBe('DISETUJUI');
            expect(data.statusVerif).toBe(true);
            expect(data).not.toHaveProperty('deletedAt');
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('should reject vehicle deletion request and restore to DISETUJUI', async () => {
            const req = createMockReq({ id_kendaraan: 1, id_user: 2, feedback: 'Kendaraan ini masih aktif digunakan' });
            const res = createMockRes();

            prisma.kendaraan.findUnique.mockResolvedValue({
                id_kendaraan: 1,
                plat_nomor: 'D 1 A',
                feedback: 'DELETE_REQUEST: Ganti plat'
            });
            prisma.kendaraan.update.mockResolvedValue({});
            prisma.user.findUnique.mockResolvedValue({ fcm_token: 'token123' });

            await kendaraanController.rejectKendaraan(req, res);

            expect(prisma.kendaraan.update).toHaveBeenCalledWith({
                where: { id_kendaraan: 1, id_user: 2 },
                data: expect.objectContaining({
                    status_pengajuan: 'DISETUJUI',
                    statusVerif: true,
                    feedback: 'PENOLAKAN_HAPUS: Kendaraan ini masih aktif digunakan'
                })
            });

            expect(sendPushNotification).toHaveBeenCalledWith(
                'token123',
                expect.stringContaining('Pembatalan Penghapusan'),
                expect.any(String),
                expect.anything()
            );

            expect(res.status).toHaveBeenCalledWith(200);
        });
    });

    /**
     * DELETE KENDARAAN
     */
    describe('deleteKendaraan', () => {
        test('should submit deletion request', async () => {
            const req = createMockReq({ reason: 'Jual kendaraan' }, { id_user: 1 }, {}, { id_kendaraan: 1 });
            const res = createMockRes();

            prisma.kendaraan.findUnique.mockResolvedValue({
                id_kendaraan: 1,
                id_user: 1,
                fotoKendaraan: ['url1', 'url2'],
                fotoSTNK: 'urlStnk',
                status_pengajuan: 'DISETUJUI',
                statusVerif: true,
                deletedAt: null
            });

            await kendaraanController.deleteKendaraan(req, res);

            expect(prisma.kendaraan.update).toHaveBeenCalledWith({
                where: { id_kendaraan: 1 },
                data: {
                    status_pengajuan: 'MENUNGGU',
                    statusVerif: false,
                    feedback: 'DELETE_REQUEST: Jual kendaraan'
                }
            });
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test.each(['MENUNGGU', 'DITOLAK'])('refuses a deletion request for a %s vehicle with 409', async (status) => {
            const req = createMockReq({ reason: 'Jual kendaraan' }, { id_user: 1 }, {}, { id_kendaraan: 1 });
            const res = createMockRes();

            prisma.kendaraan.findUnique.mockResolvedValue({
                id_kendaraan: 1,
                id_user: 1,
                status_pengajuan: status,
                statusVerif: false,
                deletedAt: null
            });

            await kendaraanController.deleteKendaraan(req, res);

            expect(prisma.kendaraan.update).not.toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(409);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Hanya kendaraan yang sudah disetujui yang bisa diajukan hapus'
            });
        });

        test("still answers 404 for a vehicle that is not the caller's", async () => {
            const req = createMockReq({}, { id_user: 1 }, {}, { id_kendaraan: 1 });
            const res = createMockRes();
            prisma.kendaraan.findUnique.mockResolvedValue(null);

            await kendaraanController.deleteKendaraan(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
            expect(prisma.kendaraan.update).not.toHaveBeenCalled();
        });
    });

    /**
     * ADMIN LIST SEARCH
     */
    describe('getAllUnverifiedKendaraan', () => {
        beforeEach(() => {
            prisma.kendaraan.count.mockReset().mockResolvedValue(0);
            prisma.kendaraan.findMany.mockReset().mockResolvedValue([]);
        });

        test('searches the plate column with the normalised search term', async () => {
            const req = createMockReq({}, { id_user: 1 }, {}, {}, { search: 'b 1234-x' });
            const res = createMockRes();

            await kendaraanController.getAllUnverifiedKendaraan(req, res);

            const { where } = prisma.kendaraan.findMany.mock.calls[0][0];
            expect(where.OR).toEqual(expect.arrayContaining([
                { plat_nomor: { contains: 'B1234X', mode: 'insensitive' } }
            ]));
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('a search that normalises to nothing does not add an empty plate clause', async () => {
            const req = createMockReq({}, { id_user: 1 }, {}, {}, { search: '---' });
            const res = createMockRes();

            await kendaraanController.getAllUnverifiedKendaraan(req, res);

            const { where } = prisma.kendaraan.findMany.mock.calls[0][0];
            expect(JSON.stringify(where.OR)).not.toContain('"contains":""');
        });
    });
});
