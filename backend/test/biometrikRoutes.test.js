/**
 * Route level tests for /biometrik/scan access control.
 * The controller is stubbed: only the middleware chain in the route file is exercised.
 */
process.env.JWT_SECRET = 'test_secret';

jest.mock('../utils/prisma', () => ({
    user: { findUnique: jest.fn() }
}));

jest.mock('../controllers/biometrikController', () => {
    const ok = (req, res) => res.status(200).json({ status: 'success' });
    return {
        addBiometrik: ok,
        deleteBiometrik: ok,
        editBiometrik: ok,
        verifyWajah: ok,
        scanWajah: ok,
        biometrikAbsen: ok,
        requestLivenessToken: ok,
        getMyBiometrikStatus: ok,
    };
});

const express = require('express');
const jwt = require('jsonwebtoken');
const request = require('supertest');
const prisma = require('../utils/prisma');
const biometrikRoutes = require('../routes/biometrikRoutes');

const app = express();
app.use(express.json());
app.use('/biometrik', biometrikRoutes);
app.use((err, req, res, next) => res.status(err.statusCode || 500).json({ status: 'error', message: err.message }));

const asRole = (role) => {
    prisma.user.findUnique.mockResolvedValue({ id_user: 1, username: 'u', nama: 'U', role, nim_nip: null });
    return { Authorization: `Bearer ${jwt.sign({ id: 1 }, process.env.JWT_SECRET)}` };
};

beforeEach(() => {
    prisma.user.findUnique.mockReset();
});

describe('POST /biometrik/scan', () => {
    test('is 401 without a token', async () => {
        const res = await request(app).post('/biometrik/scan');
        expect(res.status).toBe(401);
    });

    test('is 403 for MAHASISWA', async () => {
        const res = await request(app).post('/biometrik/scan').set(asRole('MAHASISWA'));
        expect(res.status).toBe(403);
    });

    test('is allowed for DOSEN', async () => {
        const res = await request(app).post('/biometrik/scan').set(asRole('DOSEN'));
        expect(res.status).toBe(200);
    });

    test('is allowed for ADMIN', async () => {
        const res = await request(app).post('/biometrik/scan').set(asRole('ADMIN'));
        expect(res.status).toBe(200);
    });
});

describe('GET /biometrik/status', () => {
    test('is 401 without a token', async () => {
        const res = await request(app).get('/biometrik/status');
        expect(res.status).toBe(401);
    });

    test.each(['MAHASISWA', 'DOSEN', 'ADMIN'])('is allowed for %s', async (role) => {
        const res = await request(app).get('/biometrik/status').set(asRole(role));
        expect(res.status).toBe(200);
    });
});
