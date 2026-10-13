/**
 * Unit Testing - biometrik scan (CCTV / classroom) and verify
 *
 * Covers the hardening rules:
 *  - /scan is limited to a class for DOSEN (own class only, id_kelas required) and may span all
 *    classes only for ADMIN
 *  - candidates are limited to the class's active participants when id_kelas is given
 *  - raw similarity / confidence never reach non-ADMIN callers (only a boolean match)
 */

jest.mock('../utils/prisma', () => ({
    kelas: { findFirst: jest.fn() },
    pesertaKelas: { findMany: jest.fn() },
    dataBiometrik: { findMany: jest.fn(), findUnique: jest.fn() },
}));

jest.mock('axios');

jest.mock('../utils/r2FileHandler', () => ({
    uploadFile: jest.fn().mockResolvedValue({ fileUrl: 'https://example.com/face.jpg' }),
    deleteFile: jest.fn().mockResolvedValue(true),
}));

// A plain constructor (not jest.fn) so jest.resetAllMocks() in beforeEach cannot wipe it.
jest.mock('form-data', () => function FormDataMock() {
    this.append = () => {};
    this.getHeaders = () => ({ 'Content-Type': 'multipart/form-data' });
});

const prisma = require('../utils/prisma');
const axios = require('axios');
const embeddingCache = require('../utils/embeddingCache');
const { scanWajah, verifyWajah } = require('../controllers/biometrikController');

const row = (id_user, face_embedding, nama = `User ${id_user}`) => ({
    id_biometrik: id_user,
    id_user,
    face_embedding,
    deletedAt: null,
    user: { id_user, nama, username: `user${id_user}`, role: 'MAHASISWA' },
});

// Three orthogonal embeddings: a detected face of [1,0,0] only matches user 10.
const ALL_ROWS = [row(10, [1, 0, 0]), row(11, [0, 1, 0]), row(12, [0, 0, 1])];

const createReq = ({ user, body = {}, file = true } = {}) => ({
    file: file ? { buffer: Buffer.from('img'), originalname: 'cctv.jpg', mimetype: 'image/jpeg' } : undefined,
    body,
    user,
    headers: {},
});

const createRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

const detectMultiple = (embeddings) => ({
    data: {
        success: true,
        count: embeddings.length,
        faces: embeddings.map((embedding) => ({ embedding, bbox: [0, 0, 10, 10] })),
    },
});

beforeEach(() => {
    jest.resetAllMocks();
    embeddingCache.invalidateCache();
    prisma.dataBiometrik.findMany.mockResolvedValue(ALL_ROWS);
});

describe('scanWajah - who may scan and against whom', () => {
    test('DOSEN without id_kelas is rejected with 400 before the face service is called', async () => {
        const req = createReq({ user: { id_user: 2, role: 'DOSEN' } });
        const res = createRes();

        await scanWajah(req, res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ status: 'error' }));
        expect(axios.post).not.toHaveBeenCalled();
    });

    test('DOSEN with a non numeric id_kelas is rejected with 400', async () => {
        const req = createReq({ user: { id_user: 2, role: 'DOSEN' }, body: { id_kelas: 'abc' } });
        const res = createRes();

        await scanWajah(req, res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(400);
        expect(prisma.kelas.findFirst).not.toHaveBeenCalled();
        expect(axios.post).not.toHaveBeenCalled();
    });

    test("DOSEN scanning another dosen's class gets 403 and the face service is not called", async () => {
        prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 5, id_dosen: 99 });
        const req = createReq({ user: { id_user: 2, role: 'DOSEN' }, body: { id_kelas: '5' } });
        const res = createRes();

        await scanWajah(req, res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(403);
        expect(axios.post).not.toHaveBeenCalled();
    });

    test('DOSEN scanning a class that does not exist gets 404', async () => {
        prisma.kelas.findFirst.mockResolvedValue(null);
        const req = createReq({ user: { id_user: 2, role: 'DOSEN' }, body: { id_kelas: '5' } });
        const res = createRes();

        await scanWajah(req, res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(404);
        expect(axios.post).not.toHaveBeenCalled();
    });

    test("DOSEN scanning their own class only matches that class's active participants", async () => {
        prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 5, id_dosen: 2 });
        // Only user 11 is enrolled: the detected face [1,0,0] belongs to user 10 who is NOT in the class.
        prisma.pesertaKelas.findMany.mockResolvedValue([{ id_mahasiswa: 11 }]);
        axios.post.mockResolvedValueOnce(detectMultiple([[1, 0, 0]]));

        const req = createReq({ user: { id_user: 2, role: 'DOSEN' }, body: { id_kelas: '5' } });
        const res = createRes();

        await scanWajah(req, res, jest.fn());

        expect(prisma.pesertaKelas.findMany).toHaveBeenCalledWith(expect.objectContaining({
            where: expect.objectContaining({ id_kelas: 5, deletedAt: null }),
        }));
        expect(res.status).toHaveBeenCalledWith(200);
        const body = res.json.mock.calls[0][0];
        expect(body.data.identified_users).toBe(0);
        expect(body.data.users).toEqual([]);
        expect(body.data.unidentified_count).toBe(1);
        expect(body.data.id_kelas).toBe(5);
    });

    test('DOSEN scanning their own class identifies an enrolled student without exposing similarity', async () => {
        prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 5, id_dosen: 2 });
        prisma.pesertaKelas.findMany.mockResolvedValue([{ id_mahasiswa: 10 }, { id_mahasiswa: 11 }]);
        axios.post.mockResolvedValueOnce(detectMultiple([[1, 0, 0]]));

        const req = createReq({ user: { id_user: 2, role: 'DOSEN' }, body: { id_kelas: '5' } });
        const res = createRes();

        await scanWajah(req, res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(200);
        const { users, identified_users } = res.json.mock.calls[0][0].data;
        expect(identified_users).toBe(1);
        expect(users).toHaveLength(1);
        expect(users[0]).toMatchObject({ id_user: 10, match: true });
        expect(users[0]).not.toHaveProperty('similarity');
        expect(users[0]).not.toHaveProperty('confidence');
    });

    test('ADMIN without id_kelas scans against every active embedding and still sees similarity', async () => {
        axios.post.mockResolvedValueOnce(detectMultiple([[1, 0, 0]]));

        const req = createReq({ user: { id_user: 1, role: 'ADMIN' } });
        const res = createRes();

        await scanWajah(req, res, jest.fn());

        expect(prisma.pesertaKelas.findMany).not.toHaveBeenCalled();
        expect(res.status).toHaveBeenCalledWith(200);
        const { users } = res.json.mock.calls[0][0].data;
        expect(users).toHaveLength(1);
        expect(users[0]).toMatchObject({ id_user: 10, match: true, similarity: 1, confidence: 'high' });
    });

    test('ADMIN with id_kelas is limited to that class', async () => {
        prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 7, id_dosen: 99 });
        prisma.pesertaKelas.findMany.mockResolvedValue([{ id_mahasiswa: 12 }]);
        axios.post.mockResolvedValueOnce(detectMultiple([[1, 0, 0]]));

        const req = createReq({ user: { id_user: 1, role: 'ADMIN' }, body: { id_kelas: '7' } });
        const res = createRes();

        await scanWajah(req, res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(200);
        expect(res.json.mock.calls[0][0].data.identified_users).toBe(0);
    });

    test('a class with no enrolled biometric candidates returns an empty result', async () => {
        prisma.kelas.findFirst.mockResolvedValue({ id_kelas: 5, id_dosen: 2 });
        prisma.pesertaKelas.findMany.mockResolvedValue([]);
        axios.post.mockResolvedValueOnce(detectMultiple([[1, 0, 0], [0, 1, 0]]));

        const req = createReq({ user: { id_user: 2, role: 'DOSEN' }, body: { id_kelas: '5' } });
        const res = createRes();

        await scanWajah(req, res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(200);
        expect(res.json.mock.calls[0][0].data).toMatchObject({
            total_faces_detected: 2,
            identified_users: 0,
            unidentified_count: 2,
            users: [],
        });
    });
});

describe('verifyWajah - similarity is only for ADMIN', () => {
    const faceDetected = { data: { success: true, embedding: [1, 0, 0] } };

    test('MAHASISWA match response has no similarity or confidence', async () => {
        prisma.dataBiometrik.findUnique.mockResolvedValue(row(10, [1, 0, 0]));
        axios.post
            .mockResolvedValueOnce(faceDetected)
            .mockResolvedValueOnce({ data: { is_match: true, best_match_index: 0, similarity: 0.93 } });

        const req = createReq({ user: { id_user: 10, role: 'MAHASISWA' } });
        const res = createRes();

        await verifyWajah(req, res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(200);
        const body = res.json.mock.calls[0][0];
        expect(body.matched).toBe(true);
        expect(body.data).toMatchObject({ id_user: 10, match: true });
        expect(body.data).not.toHaveProperty('similarity');
        expect(body.data).not.toHaveProperty('confidence');
    });

    test('MAHASISWA no-match response has no best_similarity', async () => {
        prisma.dataBiometrik.findUnique.mockResolvedValue(row(10, [0, 1, 0]));
        axios.post
            .mockResolvedValueOnce(faceDetected)
            .mockResolvedValueOnce({ data: { is_match: false, best_match_index: 0, similarity: 0.12 } });

        const req = createReq({ user: { id_user: 10, role: 'MAHASISWA' } });
        const res = createRes();

        await verifyWajah(req, res, jest.fn());

        const body = res.json.mock.calls[0][0];
        expect(body.matched).toBe(false);
        expect(body).not.toHaveProperty('best_similarity');
        expect(JSON.stringify(body)).not.toMatch(/similarity/);
    });

    test('ADMIN still receives similarity and confidence', async () => {
        axios.post
            .mockResolvedValueOnce(faceDetected)
            .mockResolvedValueOnce({ data: { is_match: true, best_match_index: 0, similarity: 0.93 } });

        const req = createReq({ user: { id_user: 1, role: 'ADMIN' } });
        const res = createRes();

        await verifyWajah(req, res, jest.fn());

        const body = res.json.mock.calls[0][0];
        expect(body.matched).toBe(true);
        expect(body.data).toMatchObject({ id_user: 10, match: true, similarity: 0.93, confidence: 'high' });
    });
});
