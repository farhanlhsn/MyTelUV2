/**
 * Unit Testing - biometrik enrollment (add / edit) duplicate face guard
 *
 * One face must not be registered for two accounts: a new embedding that matches another active
 * user's embedding at or above the verification threshold is rejected with 409.
 */

jest.mock('../utils/prisma', () => ({
    user: { findUnique: jest.fn() },
    dataBiometrik: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        upsert: jest.fn(),
        update: jest.fn(),
    },
}));

jest.mock('axios');

jest.mock('../utils/r2FileHandler', () => ({
    uploadFile: jest.fn().mockResolvedValue({ fileUrl: 'https://example.com/face.jpg' }),
    deleteFile: jest.fn().mockResolvedValue(true),
}));

jest.mock('../utils/auditLogger', () => ({
    logAudit: jest.fn(),
    BIOMETRIK_ACTIONS: { ADD: 'BIOMETRIK_ADD', EDIT: 'BIOMETRIK_EDIT', DELETE: 'BIOMETRIK_DELETE', ABSEN_SUCCESS: 'ABSEN_SUCCESS' },
}));

// A plain constructor (not jest.fn) so jest.resetAllMocks() in beforeEach cannot wipe it.
jest.mock('form-data', () => function FormDataMock() {
    this.append = () => {};
    this.getHeaders = () => ({ 'Content-Type': 'multipart/form-data' });
});

const prisma = require('../utils/prisma');
const axios = require('axios');
const { uploadFile } = require('../utils/r2FileHandler');
const { addBiometrik, editBiometrik } = require('../controllers/biometrikController');

const DUPLICATE_MESSAGE = 'Wajah ini sudah terdaftar untuk pengguna lain';

const createReq = ({ body = {}, params = {} } = {}) => ({
    file: { buffer: Buffer.from('img'), originalname: 'face.jpg', mimetype: 'image/jpeg' },
    body,
    params,
    user: { id_user: 1, role: 'ADMIN' },
    headers: {},
});

const createRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

const faceDetected = (embedding) => ({ data: { success: true, embedding, face_score: 0.99 } });

// embeddingCache logs every invalidation; keep the test output pristine.
let logSpy;

beforeEach(() => {
    jest.resetAllMocks();
    logSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
    uploadFile.mockResolvedValue({ fileUrl: 'https://example.com/face.jpg' });
    // Another active user (10) has face [1,0,0] enrolled.
    prisma.dataBiometrik.findMany.mockResolvedValue([{ id_user: 10, face_embedding: [1, 0, 0] }]);
});

afterEach(() => {
    logSpy.mockRestore();
});

describe('addBiometrik - duplicate face guard', () => {
    beforeEach(() => {
        prisma.user.findUnique.mockResolvedValue({ id_user: 20, nama: 'Mhs 20' });
        prisma.dataBiometrik.findUnique.mockResolvedValue(null);
    });

    test("rejects with 409 when the face matches another active user's embedding", async () => {
        axios.post.mockResolvedValueOnce(faceDetected([1, 0, 0]));
        const req = createReq({ body: { id_user: '20' } });
        const res = createRes();

        await addBiometrik(req, res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(409);
        expect(res.json).toHaveBeenCalledWith({ status: 'error', message: DUPLICATE_MESSAGE });
        expect(uploadFile).not.toHaveBeenCalled();
        expect(prisma.dataBiometrik.upsert).not.toHaveBeenCalled();
    });

    test('only other users active biometric rows are candidates', async () => {
        axios.post.mockResolvedValueOnce(faceDetected([1, 0, 0]));
        const req = createReq({ body: { id_user: '20' } });

        await addBiometrik(req, createRes(), jest.fn());

        expect(prisma.dataBiometrik.findMany).toHaveBeenCalledWith(expect.objectContaining({
            where: expect.objectContaining({ deletedAt: null, id_user: { not: 20 } }),
        }));
    });

    test('registers the face when it matches nobody else', async () => {
        axios.post.mockResolvedValueOnce(faceDetected([0, 0, 1]));
        prisma.dataBiometrik.upsert.mockResolvedValue({
            id_biometrik: 5, id_user: 20, photo_url: 'https://example.com/face.jpg', createdAt: new Date(),
        });
        const req = createReq({ body: { id_user: '20' } });
        const res = createRes();

        await addBiometrik(req, res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(201);
        expect(prisma.dataBiometrik.upsert).toHaveBeenCalled();
    });

    test('registers the face when there are no other enrolled users', async () => {
        prisma.dataBiometrik.findMany.mockResolvedValue([]);
        axios.post.mockResolvedValueOnce(faceDetected([1, 0, 0]));
        prisma.dataBiometrik.upsert.mockResolvedValue({
            id_biometrik: 5, id_user: 20, photo_url: 'https://example.com/face.jpg', createdAt: new Date(),
        });
        const res = createRes();

        await addBiometrik(createReq({ body: { id_user: '20' } }), res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(201);
    });
});

describe('editBiometrik - duplicate face guard', () => {
    beforeEach(() => {
        prisma.dataBiometrik.findUnique.mockResolvedValue({ id_biometrik: 7, id_user: 20, deletedAt: null });
    });

    test("rejects with 409 when the new face matches another active user's embedding", async () => {
        axios.post.mockResolvedValueOnce(faceDetected([1, 0, 0]));
        const req = createReq({ params: { id_user: '20' } });
        const res = createRes();

        await editBiometrik(req, res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(409);
        expect(res.json).toHaveBeenCalledWith({ status: 'error', message: DUPLICATE_MESSAGE });
        expect(uploadFile).not.toHaveBeenCalled();
        expect(prisma.dataBiometrik.update).not.toHaveBeenCalled();
        expect(prisma.dataBiometrik.findMany).toHaveBeenCalledWith(expect.objectContaining({
            where: expect.objectContaining({ deletedAt: null, id_user: { not: 20 } }),
        }));
    });

    test('updates the face when it matches nobody else', async () => {
        axios.post.mockResolvedValueOnce(faceDetected([0, 1, 0]));
        prisma.dataBiometrik.update.mockResolvedValue({
            id_biometrik: 7, id_user: 20, photo_url: 'https://example.com/face.jpg', updatedAt: new Date(),
        });
        const res = createRes();

        await editBiometrik(createReq({ params: { id_user: '20' } }), res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(200);
        expect(prisma.dataBiometrik.update).toHaveBeenCalled();
    });
});

describe('duplicate face guard is skipped in TEST_MODE', () => {
    // In TEST_MODE the face service returns one dummy embedding for every image, so "this face is
    // already registered for someone else" would be true for everybody.
    const originalTestMode = process.env.TEST_MODE;

    beforeEach(() => {
        process.env.TEST_MODE = 'true';
    });

    afterEach(() => {
        if (originalTestMode === undefined) delete process.env.TEST_MODE;
        else process.env.TEST_MODE = originalTestMode;
    });

    test('addBiometrik enrolls a face identical to another user without querying other embeddings', async () => {
        prisma.user.findUnique.mockResolvedValue({ id_user: 20, nama: 'Mhs 20' });
        prisma.dataBiometrik.findUnique.mockResolvedValue(null);
        axios.post.mockResolvedValueOnce(faceDetected([1, 0, 0])); // identical to user 10's embedding
        prisma.dataBiometrik.upsert.mockResolvedValue({
            id_biometrik: 5, id_user: 20, photo_url: 'https://example.com/face.jpg', createdAt: new Date(),
        });
        const res = createRes();

        await addBiometrik(createReq({ body: { id_user: '20' } }), res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(201);
        expect(prisma.dataBiometrik.findMany).not.toHaveBeenCalled();
    });

    test('editBiometrik updates to a face identical to another user without querying other embeddings', async () => {
        prisma.dataBiometrik.findUnique.mockResolvedValue({ id_biometrik: 7, id_user: 20, deletedAt: null });
        axios.post.mockResolvedValueOnce(faceDetected([1, 0, 0])); // identical to user 10's embedding
        prisma.dataBiometrik.update.mockResolvedValue({
            id_biometrik: 7, id_user: 20, photo_url: 'https://example.com/face.jpg', updatedAt: new Date(),
        });
        const res = createRes();

        await editBiometrik(createReq({ params: { id_user: '20' } }), res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(200);
        expect(prisma.dataBiometrik.findMany).not.toHaveBeenCalled();
    });
});
