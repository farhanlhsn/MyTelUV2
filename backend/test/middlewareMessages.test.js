/**
 * The `message` of every error the middlewares answer with is Indonesian: the mobile app shows it to the
 * user as it is. (The Socket.IO handshake keeps its `Unauthorized` error: it is a code the client
 * compares, not text for a person.)
 */
process.env.JWT_SECRET = 'test_secret';

const mockPrisma = {
    user: { findUnique: jest.fn() },
};

jest.mock('../utils/prisma', () => mockPrisma);

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const { protect, authorize } = require('../middlewares/authMiddleware');
const { protectEdgeDevice } = require('../middlewares/edgeAuthMiddleware');
const {
    validateRequired,
    validateEmail,
    validatePassword,
    validateUsername
} = require('../middlewares/validationMiddleware');
const { edgeLimiter } = require('../middlewares/rateLimiterMiddleware');

const createRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

const answer = (res) => ({ status: res.status.mock.calls[0][0], body: res.json.mock.calls[0][0] });

describe('authMiddleware messages', () => {
    beforeEach(() => mockPrisma.user.findUnique.mockReset());

    test('a request without a token', async () => {
        const res = createRes();
        await protect({ headers: {} }, res, jest.fn());

        expect(answer(res)).toEqual({
            status: 401,
            body: { status: 'error', message: 'Akses ditolak. Silakan login terlebih dahulu.' }
        });
    });

    test('an invalid or expired token', async () => {
        const res = createRes();
        await protect({ headers: { authorization: 'Bearer not-a-jwt' } }, res, jest.fn());

        expect(answer(res)).toEqual({
            status: 401,
            body: { status: 'error', message: 'Token tidak valid atau sudah kedaluwarsa' }
        });
    });

    test('a token of a user who is gone or deactivated', async () => {
        mockPrisma.user.findUnique.mockResolvedValue(null);
        const token = jwt.sign({ id: 7 }, process.env.JWT_SECRET, { expiresIn: '1h' });
        const res = createRes();

        await protect({ headers: { authorization: `Bearer ${token}` } }, res, jest.fn());

        expect(answer(res)).toEqual({
            status: 401,
            body: { status: 'error', message: 'Pengguna tidak ditemukan atau akunnya telah dinonaktifkan' }
        });
    });

    test('a role without access names the role', () => {
        const res = createRes();
        const next = jest.fn();

        authorize('ADMIN')({ user: { role: 'MAHASISWA' } }, res, next);

        expect(next).not.toHaveBeenCalled();
        expect(answer(res)).toEqual({
            status: 403,
            body: { status: 'error', message: 'Peran MAHASISWA tidak memiliki akses ke fitur ini' }
        });
    });
});

describe('edgeAuthMiddleware messages', () => {
    const original = process.env.EDGE_DEVICE_SECRET;
    afterEach(() => {
        if (original === undefined) delete process.env.EDGE_DEVICE_SECRET;
        else process.env.EDGE_DEVICE_SECRET = original;
    });

    test('a wrong secret', () => {
        process.env.EDGE_DEVICE_SECRET = 'configured';
        const res = createRes();

        protectEdgeDevice({ get: () => 'wrong' }, res, jest.fn());

        expect(answer(res).status).toBe(401);
        expect(answer(res).body).toMatchObject({
            message: 'Perangkat edge tidak berwenang',
            data: { gate_action: 'DENY' }
        });
    });

    test('no secret configured on the server', () => {
        delete process.env.EDGE_DEVICE_SECRET;
        const res = createRes();

        protectEdgeDevice({ get: () => 'any' }, res, jest.fn());

        expect(answer(res).status).toBe(503);
        expect(answer(res).body).toMatchObject({
            message: 'Autentikasi perangkat edge belum dikonfigurasi',
            data: { gate_action: 'DENY' }
        });
    });
});

describe('validationMiddleware messages', () => {
    test('validateRequired lists the missing fields', () => {
        const res = createRes();

        validateRequired(['nama', 'username'])({ body: { nama: ' ' } }, res, jest.fn());

        expect(answer(res)).toEqual({
            status: 400,
            body: { status: 'error', message: 'Kolom wajib belum diisi: nama, username' }
        });
    });

    test('validateEmail', () => {
        const res = createRes();

        validateEmail({ body: { email: 'bukan-email' } }, res, jest.fn());

        expect(answer(res).body.message).toBe('Format email tidak valid');
    });

    test('validatePassword: too short, and without a letter and a number', () => {
        const short = createRes();
        validatePassword({ body: { password: 'a1' } }, short, jest.fn());
        expect(answer(short).body.message).toBe('Password minimal 6 karakter');

        const weak = createRes();
        validatePassword({ body: { password: 'abcdefgh' } }, weak, jest.fn());
        expect(answer(weak).body.message).toBe('Password harus mengandung minimal satu huruf dan satu angka');
    });

    test('validateUsername: length, and format', () => {
        const short = createRes();
        validateUsername({ body: { username: 'ab' } }, short, jest.fn());
        expect(answer(short).body.message).toBe('Username harus 3 sampai 30 karakter');

        const format = createRes();
        validateUsername({ body: { username: '1budi' } }, format, jest.fn());
        expect(answer(format).body.message).toBe(
            'Username harus diawali huruf dan hanya boleh berisi huruf, angka, dan garis bawah (_)'
        );
    });
});

describe('rateLimiterMiddleware messages', () => {
    test('the edge device limiter answers in Indonesian', async () => {
        const app = express();
        app.set('trust proxy', 'loopback, linklocal, uniquelocal');
        app.get('/edge', edgeLimiter, (req, res) => res.status(200).json({ status: 'success' }));
        const ip = '203.0.113.200';

        let last;
        for (let i = 0; i < 60; i++) {
            last = await request(app).get('/edge').set('X-Forwarded-For', ip);
        }
        expect(last.status).toBe(200);

        const blocked = await request(app).get('/edge').set('X-Forwarded-For', ip);
        expect(blocked.status).toBe(429);
        expect(blocked.body).toEqual({
            status: 'error',
            message: 'Terlalu banyak permintaan dari perangkat edge. Coba lagi nanti.'
        });
    });
});
