/**
 * Route level tests for upload hardening:
 *  - kendaraan upload routes authenticate BEFORE multer buffers anything
 *  - post media: max 5 files, 5 MB each, image/video only
 */
process.env.JWT_SECRET = 'test_secret';

jest.mock('../utils/prisma', () => ({
    user: { findUnique: jest.fn() }
}));

// Controllers are stubbed: these tests only exercise the middleware chain in the route files.
jest.mock('../controllers/kendaraanController', () => {
    const ok = (req, res) => res.status(201).json({ status: 'success' });
    return {
        registerKendaraan: ok,
        getKendaraan: ok,
        deleteKendaraan: ok,
        verifyKendaraan: ok,
        getAllUnverifiedKendaraan: ok,
        getAllKendaraan: ok,
        getHistoriPengajuan: ok,
        rejectKendaraan: ok,
        resubmitKendaraan: ok
    };
});

jest.mock('../controllers/postController', () => {
    const ok = (req, res) => res.status(201).json({
        status: 'success',
        data: { files: ((req.files && req.files.media) || []).length }
    });
    return {
        getAllPosts: ok, getPostById: ok, createPost: ok, updatePost: ok, deletePost: ok,
        toggleLike: ok, getComments: ok, addComment: ok, deleteComment: ok, getMyPosts: ok
    };
});

const express = require('express');
const jwt = require('jsonwebtoken');
const request = require('supertest');
const prisma = require('../utils/prisma');
const kendaraanRoutes = require('../routes/kendaraanRoutes');
const postRoutes = require('../routes/postRoutes');

const app = express();
app.use(express.json());
app.use('/kendaraan', kendaraanRoutes);
app.use('/posts', postRoutes);
// Mirrors server.js: whatever multer throws and is not handled by the route becomes a 500.
app.use((err, req, res, next) => res.status(err.statusCode || 500).json({ status: 'error', message: err.message }));

const authHeader = () => ({ Authorization: `Bearer ${jwt.sign({ id: 1 }, process.env.JWT_SECRET)}` });

beforeEach(() => {
    prisma.user.findUnique.mockReset();
    prisma.user.findUnique.mockResolvedValue({ id_user: 1, username: 'budi', nama: 'Budi', role: 'MAHASISWA', nim_nip: null });
});

describe('kendaraan upload routes: protect runs before multer', () => {
    // 'bogus' is not an allowed upload field, so multer would raise an error if it ever ran.
    test('POST /register without a token is 401, and multer never parses the body', async () => {
        const res = await request(app)
            .post('/kendaraan/register')
            .attach('bogus', Buffer.from('x'), { filename: 'a.jpg', contentType: 'image/jpeg' });

        expect(res.status).toBe(401);
        expect(prisma.user.findUnique).not.toHaveBeenCalled();
    });

    test('PUT /:id/resubmit without a token is 401, and multer never parses the body', async () => {
        const res = await request(app)
            .put('/kendaraan/5/resubmit')
            .attach('bogus', Buffer.from('x'), { filename: 'a.jpg', contentType: 'image/jpeg' });

        expect(res.status).toBe(401);
    });

    test('POST /register with a valid token still reaches multer (bad field => multer error, not 401)', async () => {
        const res = await request(app)
            .post('/kendaraan/register')
            .set(authHeader())
            .attach('bogus', Buffer.from('x'), { filename: 'a.jpg', contentType: 'image/jpeg' });

        expect(res.status).not.toBe(401);
        expect(res.status).toBe(500);
    });
});

describe('post media upload limits', () => {
    const attachImages = (req, count) => {
        for (let i = 0; i < count; i++) {
            req = req.attach('media', Buffer.from(`img-${i}`), { filename: `p${i}.jpg`, contentType: 'image/jpeg' });
        }
        return req;
    };

    test('accepts 5 image files', async () => {
        const res = await attachImages(request(app).post('/posts').set(authHeader()).field('content', 'halo'), 5);

        expect(res.status).toBe(201);
        expect(res.body.data.files).toBe(5);
    });

    test('rejects a 6th file with 400 and an Indonesian message', async () => {
        const res = await attachImages(request(app).post('/posts').set(authHeader()).field('content', 'halo'), 6);

        expect(res.status).toBe(400);
        expect(res.body.status).toBe('error');
        expect(res.body.message).toMatch(/maksimal 5 file/i);
    });

    test('update route enforces the same 5 file limit', async () => {
        const res = await attachImages(request(app).put('/posts/3').set(authHeader()).field('content', 'halo'), 6);

        expect(res.status).toBe(400);
        expect(res.body.message).toMatch(/maksimal 5 file/i);
    });

    test('accepts a file just under 5 MB', async () => {
        const res = await request(app).post('/posts').set(authHeader())
            .attach('media', Buffer.alloc(5 * 1024 * 1024 - 1), { filename: 'big.jpg', contentType: 'image/jpeg' });

        expect(res.status).toBe(201);
    });

    test('rejects a file over 5 MB with 400', async () => {
        const res = await request(app).post('/posts').set(authHeader())
            .attach('media', Buffer.alloc(5 * 1024 * 1024 + 1), { filename: 'big.jpg', contentType: 'image/jpeg' });

        expect(res.status).toBe(400);
        expect(res.body.message).toMatch(/5 MB/);
    });

    test('accepts a video', async () => {
        const res = await request(app).post('/posts').set(authHeader())
            .attach('media', Buffer.from('vid'), { filename: 'clip.mp4', contentType: 'video/mp4' });

        expect(res.status).toBe(201);
    });

    test.each([
        ['text/plain', 'note.txt'],
        ['application/pdf', 'doc.pdf'],
        ['image/svg+xml', 'x.svg'],
        ['application/x-msdownload', 'run.exe']
    ])('rejects %s (image/video only) with 400', async (contentType, filename) => {
        const res = await request(app).post('/posts').set(authHeader())
            .attach('media', Buffer.from('x'), { filename, contentType });

        expect(res.status).toBe(400);
        expect(res.body.status).toBe('error');
    });

    test('unauthenticated upload is 401 before multer', async () => {
        const res = await request(app).post('/posts')
            .attach('media', Buffer.from('x'), { filename: 'note.txt', contentType: 'text/plain' });

        expect(res.status).toBe(401);
    });
});
