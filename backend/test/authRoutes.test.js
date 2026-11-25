/**
 * Route level tests for account creation:
 *  - POST /auth/register is public and can only ever create a MAHASISWA
 *  - POST /auth/admin/users is ADMIN only and is the way to create DOSEN / ADMIN accounts
 * The real router, authorize middleware, Zod schemas and controller run; only the database,
 * bcrypt and the audit logger are mocked.
 */
process.env.JWT_SECRET = 'test_secret';

jest.mock('../utils/prisma', () => ({
    user: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
    },
}));

jest.mock('bcryptjs', () => ({
    hash: jest.fn().mockResolvedValue('hashed_password'),
    compare: jest.fn(),
}));

// uuid v13 is ESM only, which jest cannot load without a transform (same mock as authController.test.js)
jest.mock('uuid', () => ({
    v4: () => 'mocked-uuid-token',
}));

jest.mock('../utils/auditLogger', () => ({
    logAudit: jest.fn(),
}));

jest.mock('../utils/r2FileHandler', () => ({
    uploadFile: jest.fn(),
    deleteFile: jest.fn(),
    fileExists: jest.fn(),
}));

const express = require('express');
const jwt = require('jsonwebtoken');
const request = require('supertest');
const prisma = require('../utils/prisma');
const { logAudit } = require('../utils/auditLogger');
const authRoutes = require('../routes/authRoutes');

const app = express();
app.set('trust proxy', 'loopback, linklocal, uniquelocal');
app.use(express.json());
app.use('/auth', authRoutes);
app.use((err, req, res, next) => res.status(err.statusCode || 500).json({ status: 'error', message: err.message }));

const usersById = {
    1: { id_user: 1, username: 'admin', nama: 'Admin Kampus', role: 'ADMIN', nim_nip: null },
    2: { id_user: 2, username: 'mhs', nama: 'Mahasiswa', role: 'MAHASISWA', nim_nip: null },
    3: { id_user: 3, username: 'dosen', nama: 'Dosen', role: 'DOSEN', nim_nip: null },
};
const tokenFor = (id) => ({ Authorization: `Bearer ${jwt.sign({ id }, process.env.JWT_SECRET)}` });

// authLimiter (register) keys on IP + username, so each test uses its own client IP.
let ipCounter = 0;
const freshIp = () => `198.51.100.${++ipCounter}`;

beforeEach(() => {
    jest.clearAllMocks();
    prisma.user.findUnique.mockImplementation(async ({ where }) => usersById[where.id_user] || null);
    prisma.user.findFirst.mockResolvedValue(null);
    prisma.user.create.mockImplementation(async ({ data }) => ({ id_user: 10, ...data }));
});

const newDosen = { nama: 'Pak Dosen', username: 'dosen_baru', password: 'Rahasia123', role: 'DOSEN' };

describe('POST /auth/admin/users (ADMIN only)', () => {
    test('admin creates a DOSEN => 201 with role DOSEN and no password hash', async () => {
        const res = await request(app).post('/auth/admin/users').set(tokenFor(1)).send(newDosen);

        expect(res.status).toBe(201);
        expect(res.body.status).toBe('success');
        expect(res.body.data).toEqual(expect.objectContaining({ id: 10, username: 'dosen_baru', nama: 'Pak Dosen', role: 'DOSEN' }));
        expect(JSON.stringify(res.body)).not.toContain('hashed_password');
        expect(prisma.user.create.mock.calls[0][0].data.role).toBe('DOSEN');
        expect(logAudit).toHaveBeenCalledWith(expect.objectContaining({ action: 'ADMIN_CREATE_USER', performedBy: 1, targetUserId: 10 }));
    });

    test('admin can create another ADMIN', async () => {
        const res = await request(app).post('/auth/admin/users').set(tokenFor(1)).send({ ...newDosen, username: 'admin_baru', role: 'ADMIN' });

        expect(res.status).toBe(201);
        expect(res.body.data.role).toBe('ADMIN');
    });

    test('admin create stores a lowercased email and the optional nim_nip', async () => {
        const res = await request(app).post('/auth/admin/users').set(tokenFor(1))
            .send({ ...newDosen, email: 'Dosen.Baru@Telkom.AC.id', nim_nip: '198012345678' });

        expect(res.status).toBe(201);
        const { data } = prisma.user.create.mock.calls[0][0];
        expect(data.email).toBe('dosen.baru@telkom.ac.id');
        expect(data.nim_nip).toBe('198012345678');
    });

    test('admin creates a DOSEN with an 18 digit NIP => 201', async () => {
        const res = await request(app).post('/auth/admin/users').set(tokenFor(1))
            .send({ ...newDosen, nim_nip: '198012345678901234' });

        expect(res.status).toBe(201);
        expect(res.body.data.role).toBe('DOSEN');
        expect(prisma.user.create.mock.calls[0][0].data.nim_nip).toBe('198012345678901234');
    });

    test('admin creating a MAHASISWA with an 18 digit value => 400 (NIM keeps the 11-12 digit rule)', async () => {
        const res = await request(app).post('/auth/admin/users').set(tokenFor(1))
            .send({ ...newDosen, username: 'mhs_baru', role: 'MAHASISWA', nim_nip: '198012345678901234' });

        expect(res.status).toBe(400);
        expect(res.body.status).toBe('error');
        expect(prisma.user.create).not.toHaveBeenCalled();
    });

    test('admin creates a MAHASISWA with a valid 11 digit NIM => 201', async () => {
        const res = await request(app).post('/auth/admin/users').set(tokenFor(1))
            .send({ ...newDosen, username: 'mhs_baru', role: 'MAHASISWA', nim_nip: '13012100012' });

        expect(res.status).toBe(201);
    });

    test('a MAHASISWA is refused with 403 and nothing is created', async () => {
        const res = await request(app).post('/auth/admin/users').set(tokenFor(2)).send(newDosen);

        expect(res.status).toBe(403);
        expect(prisma.user.create).not.toHaveBeenCalled();
    });

    test('a DOSEN is refused with 403 and nothing is created', async () => {
        const res = await request(app).post('/auth/admin/users').set(tokenFor(3)).send(newDosen);

        expect(res.status).toBe(403);
        expect(prisma.user.create).not.toHaveBeenCalled();
    });

    test('no token => 401', async () => {
        const res = await request(app).post('/auth/admin/users').send(newDosen);

        expect(res.status).toBe(401);
        expect(prisma.user.create).not.toHaveBeenCalled();
    });

    test.each(['SUPERUSER', 'dosen', ''])('invalid role %p => 400 and nothing is created', async (role) => {
        const res = await request(app).post('/auth/admin/users').set(tokenFor(1)).send({ ...newDosen, role });

        expect(res.status).toBe(400);
        expect(res.body.status).toBe('error');
        expect(prisma.user.create).not.toHaveBeenCalled();
    });

    test('missing role => 400', async () => {
        const { role, ...withoutRole } = newDosen;
        const res = await request(app).post('/auth/admin/users').set(tokenFor(1)).send(withoutRole);

        expect(res.status).toBe(400);
        expect(prisma.user.create).not.toHaveBeenCalled();
    });

    test('7 character password => 400 "Password minimal 8 karakter"', async () => {
        const res = await request(app).post('/auth/admin/users').set(tokenFor(1)).send({ ...newDosen, password: 'abc1234' });

        expect(res.status).toBe(400);
        expect(res.body.message).toContain('Password minimal 8 karakter');
    });

    test('duplicate username (including a soft-deleted user) => 409', async () => {
        prisma.user.findFirst.mockResolvedValue({ username: 'dosen_baru', nim_nip: null, email: null });

        const res = await request(app).post('/auth/admin/users').set(tokenFor(1)).send(newDosen);

        expect(res.status).toBe(409);
        expect(res.body).toEqual({ status: 'error', message: 'Username sudah digunakan' });
        expect(JSON.stringify(prisma.user.findFirst.mock.calls[0][0].where)).not.toContain('deletedAt');
        expect(prisma.user.create).not.toHaveBeenCalled();
    });
});

describe('POST /auth/register stays public and MAHASISWA only', () => {
    test('a client supplied role DOSEN / ADMIN is ignored', async () => {
        for (const role of ['DOSEN', 'ADMIN']) {
            prisma.user.create.mockClear();
            const res = await request(app).post('/auth/register').set('X-Forwarded-For', freshIp())
                .send({ nama: 'Budi', username: `budi_${role.toLowerCase()}`, password: 'Rahasia123', role });

            expect(res.status).toBe(201);
            expect(prisma.user.create.mock.calls[0][0].data.role).toBe('MAHASISWA');
            expect(res.body.data.role).toBe('MAHASISWA');
        }
    });
});
