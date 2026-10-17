/**
 * Unit Testing - Auth Controller
 * 
 * @author MyTelUV2 Team
 * @date 2026-01-04
 */

// Mock dependencies BEFORE importing 
jest.mock('../utils/prisma', () => ({
    user: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
    },
    refreshToken: {
        create: jest.fn(),
        deleteMany: jest.fn(),
        findUnique: jest.fn(),
        delete: jest.fn(),
    },
    passwordResetToken: {
        findUnique: jest.fn(),
        update: jest.fn(),
    },
    dataBiometrik: {
        updateMany: jest.fn(),
    },
    $transaction: jest.fn(),
}));

jest.mock('bcryptjs', () => ({
    hash: jest.fn(),
    compare: jest.fn(),
}));

jest.mock('jsonwebtoken', () => ({
    sign: jest.fn(),
}));

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

// Import mocked modules
const prisma = require('../utils/prisma');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { logAudit } = require('../utils/auditLogger');

// Import the controller
const authController = require('../controllers/authController');
const { validateZod } = require('../middlewares/validationMiddleware');
const { registerSchema, adminCreateUserSchema, changePasswordSchema, resetPasswordSchema, adminResetPasswordSchema } = require('../middlewares/zodSchemas');

// Helper functions for req/res
const createMockReq = (body = {}, user = null) => ({
    body,
    user,
});

const createMockRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

// Runs a schema through validateZod and returns what the next handler would see.
const run = async (schema, body) => {
    const req = { body };
    const res = createMockRes();
    const next = jest.fn();
    await validateZod(schema)(req, res, next);
    return { req, res, next };
};

describe('Auth Controller Tests', () => {

    beforeEach(() => {
        // resetAllMocks (not clearAllMocks): also drops the mockReturnValue/mockResolvedValue
        // implementations so one test's sentinels cannot leak into the next.
        jest.resetAllMocks();
    });

    /**
     * REGISTER TESTS
     */
    describe('register', () => {
        const mockUserData = {
            nama: 'Test User',
            username: 'testu',
            password: 'password123'
        };

        test('should register a new user successfully', async () => {
            prisma.user.findFirst.mockResolvedValue(null); // Username valid (not taken)
            bcrypt.hash.mockResolvedValue('hashed_password');
            prisma.user.create.mockResolvedValue({
                id_user: 1,
                ...mockUserData,
                role: 'MAHASISWA'
            });

            const req = createMockReq(mockUserData);
            const res = createMockRes();

            await authController.register(req, res);

            expect(bcrypt.hash).toHaveBeenCalledWith('password123', 10);
            expect(prisma.user.create).toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(201);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                message: 'Akun berhasil dibuat'
            }));
        });

        test.each(['DOSEN', 'ADMIN', 'mahasiswa', undefined])('always creates a MAHASISWA, ignoring body role %p', async (role) => {
            prisma.user.findFirst.mockResolvedValue(null);
            bcrypt.hash.mockResolvedValue('hashed_password');
            prisma.user.create.mockResolvedValue({ id_user: 1, ...mockUserData, role: 'MAHASISWA' });

            const res = createMockRes();
            await authController.register(createMockReq({ ...mockUserData, role }), res);

            expect(prisma.user.create).toHaveBeenCalledTimes(1);
            expect(prisma.user.create.mock.calls[0][0].data.role).toBe('MAHASISWA');
            expect(res.status).toHaveBeenCalledWith(201);
        });

        test('stores an optional email lowercased', async () => {
            prisma.user.findFirst.mockResolvedValue(null);
            bcrypt.hash.mockResolvedValue('hashed_password');
            prisma.user.create.mockResolvedValue({ id_user: 1, ...mockUserData, role: 'MAHASISWA' });

            await authController.register(createMockReq({ ...mockUserData, email: 'Budi.Santoso@Student.Telkomuniversity.ac.id' }), createMockRes());

            expect(prisma.user.create.mock.calls[0][0].data.email).toBe('budi.santoso@student.telkomuniversity.ac.id');
        });

        test('stores a null email when none is given', async () => {
            prisma.user.findFirst.mockResolvedValue(null);
            bcrypt.hash.mockResolvedValue('hashed_password');
            prisma.user.create.mockResolvedValue({ id_user: 1, ...mockUserData, role: 'MAHASISWA' });

            await authController.register(createMockReq(mockUserData), createMockRes());

            expect(prisma.user.create.mock.calls[0][0].data.email).toBeNull();
        });

        test('duplicate check does not exclude soft-deleted users (matches the DB unique constraint)', async () => {
            prisma.user.findFirst.mockResolvedValue({ id_user: 9, username: 'testu', nim_nip: null, email: null, deletedAt: new Date() });

            await authController.register(createMockReq(mockUserData), createMockRes());

            expect(prisma.user.findFirst).toHaveBeenCalledTimes(1);
            const { where } = prisma.user.findFirst.mock.calls[0][0];
            expect(JSON.stringify(where)).not.toContain('deletedAt');
            expect(where.OR).toEqual(expect.arrayContaining([{ username: 'testu' }]));
        });

        test('should return 409 if username already exists, even for a soft-deleted user', async () => {
            prisma.user.findFirst.mockResolvedValue({ id_user: 9, username: 'testu', nim_nip: null, email: null, deletedAt: new Date() });

            const res = createMockRes();
            await authController.register(createMockReq(mockUserData), res);

            expect(res.status).toHaveBeenCalledWith(409);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Username sudah digunakan'
            });
            expect(prisma.user.create).not.toHaveBeenCalled();
        });

        test('should return 409 if NIM/NIP already exists, even for a soft-deleted user', async () => {
            prisma.user.findFirst.mockResolvedValue({ id_user: 9, username: 'other', nim_nip: '13012100012', email: null, deletedAt: new Date() });

            const res = createMockRes();
            await authController.register(createMockReq({ ...mockUserData, nim_nip: '13012100012' }), res);

            expect(prisma.user.findFirst.mock.calls[0][0].where.OR).toEqual(expect.arrayContaining([{ nim_nip: '13012100012' }]));
            expect(res.status).toHaveBeenCalledWith(409);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'NIM/NIP sudah terdaftar'
            });
            expect(prisma.user.create).not.toHaveBeenCalled();
        });

        test('should return 409 if email already exists (compared lowercased)', async () => {
            prisma.user.findFirst.mockResolvedValue({ id_user: 9, username: 'other', nim_nip: null, email: 'budi@telkom.ac.id', deletedAt: null });

            const res = createMockRes();
            await authController.register(createMockReq({ ...mockUserData, email: 'Budi@Telkom.ac.id' }), res);

            expect(prisma.user.findFirst.mock.calls[0][0].where.OR).toEqual(expect.arrayContaining([{ email: 'budi@telkom.ac.id' }]));
            expect(res.status).toHaveBeenCalledWith(409);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Email sudah terdaftar'
            });
            expect(prisma.user.create).not.toHaveBeenCalled();
        });

        test('returns 409 (not 500) when a concurrent register wins the unique constraint race', async () => {
            prisma.user.findFirst.mockResolvedValue(null);
            bcrypt.hash.mockResolvedValue('hashed_password');
            prisma.user.create.mockRejectedValue(Object.assign(new Error('Unique constraint failed'), { code: 'P2002' }));

            const res = createMockRes();
            await authController.register(createMockReq(mockUserData), res);

            expect(res.status).toHaveBeenCalledWith(409);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ status: 'error' }));
        });
    });

    /**
     * REGISTER SCHEMA (public registration hardening)
     */
    describe('registerSchema', () => {
        const validBody = { nama: 'Budi', username: 'budi_1', password: 'Rahasia123' };

        test('strips a client supplied role so it never reaches the controller', async () => {
            const { req, next } = await run(registerSchema, { ...validBody, role: 'DOSEN' });

            expect(next).toHaveBeenCalledWith();
            expect(req.body).not.toHaveProperty('role');
        });

        test('keeps an optional email through validation', async () => {
            const { req, next } = await run(registerSchema, { ...validBody, email: 'budi@telkom.ac.id' });

            expect(next).toHaveBeenCalledWith();
            expect(req.body.email).toBe('budi@telkom.ac.id');
        });

        test('rejects a malformed email with 400', async () => {
            const { res, next } = await run(registerSchema, { ...validBody, email: 'bukan-email' });

            expect(next).not.toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(400);
        });
    });

    /**
     * ADMIN CREATE USER (the only way to create DOSEN / ADMIN accounts)
     */
    describe('adminCreateUserSchema', () => {
        const validBody = { nama: 'Pak Dosen', username: 'dosen_1', password: 'Rahasia123' };

        test.each(['MAHASISWA', 'DOSEN', 'ADMIN'])('accepts and keeps role %s', async (role) => {
            const { req, next } = await run(adminCreateUserSchema, { ...validBody, role });

            expect(next).toHaveBeenCalledWith();
            expect(req.body.role).toBe(role);
        });

        test.each(['SUPERUSER', 'dosen', '', null, 5])('rejects invalid role %p with 400', async (role) => {
            const { res, next } = await run(adminCreateUserSchema, { ...validBody, role });

            expect(next).not.toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(400);
        });

        test('rejects a missing role with 400', async () => {
            const { res, next } = await run(adminCreateUserSchema, validBody);

            expect(next).not.toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(400);
        });

        describe('nim_nip depends on the role', () => {
            const body = (role, nim_nip) => ({ ...validBody, role, ...(nim_nip === undefined ? {} : { nim_nip }) });

            test.each([
                ['DOSEN', '198012345678901234'], // 18 digit NIP
                ['DOSEN', '0412058001'],         // 10 digit NIDN
                ['DOSEN', '12345678'],           // lower bound (8)
                ['DOSEN', '12345678901234567890'], // upper bound (20)
                ['ADMIN', '198012345678901234'],
                ['ADMIN', '12345678'],
                ['MAHASISWA', '13012100012'],    // 11 digit NIM
                ['MAHASISWA', '130121000123'],   // 12 digit NIM
            ])('%s accepts nim_nip %s', async (role, nim_nip) => {
                const { req, next } = await run(adminCreateUserSchema, body(role, nim_nip));

                expect(next).toHaveBeenCalledWith();
                expect(req.body.nim_nip).toBe(nim_nip);
            });

            test.each(['MAHASISWA', 'DOSEN', 'ADMIN'])('%s may omit nim_nip', async (role) => {
                const { req, next } = await run(adminCreateUserSchema, body(role));

                expect(next).toHaveBeenCalledWith();
                expect(req.body).not.toHaveProperty('nim_nip');
            });

            test.each([
                ['MAHASISWA', '198012345678901234'], // lecturer length is not a valid NIM
                ['MAHASISWA', '12345678'],
                ['MAHASISWA', '1234567890'],
                ['DOSEN', '1234567'],                // 7 digits: too short
                ['DOSEN', '123456789012345678901'],  // 21 digits: too long
                ['DOSEN', '1980123456abcd7890'],     // not digits only
                ['ADMIN', '1234567'],
                ['ADMIN', '123456789012345678901'],
            ])('%s rejects nim_nip %s with 400', async (role, nim_nip) => {
                const { res, next } = await run(adminCreateUserSchema, body(role, nim_nip));

                expect(next).not.toHaveBeenCalled();
                expect(res.status).toHaveBeenCalledWith(400);
                expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ status: 'error' }));
            });

            test('public registerSchema is unchanged: an 18 digit value is still rejected', async () => {
                const { res, next } = await run(registerSchema, { ...validBody, nim_nip: '198012345678901234' });

                expect(next).not.toHaveBeenCalled();
                expect(res.status).toHaveBeenCalledWith(400);
            });
        });

        test('keeps optional nim_nip and email, and still strips unknown keys', async () => {
            const { req, next } = await run(adminCreateUserSchema, {
                ...validBody, role: 'DOSEN', nim_nip: '198012345678', email: 'dosen@telkom.ac.id', isSuperAdmin: true
            });

            expect(next).toHaveBeenCalledWith();
            expect(req.body).toEqual({
                ...validBody, role: 'DOSEN', nim_nip: '198012345678', email: 'dosen@telkom.ac.id'
            });
        });
    });

    describe('adminCreateUser', () => {
        const admin = { id_user: 99, nama: 'Admin Kampus', role: 'ADMIN' };
        const body = { nama: 'Pak Dosen', username: 'dosen_1', password: 'Rahasia123', role: 'DOSEN' };
        const makeReq = (extra = {}) => ({ ...createMockReq({ ...body, ...extra }, admin), ip: '10.0.0.1', headers: {} });
        const created = {
            id_user: 5, nama: 'Pak Dosen', username: 'dosen_1', role: 'DOSEN',
            nim_nip: null, email: null, password: 'hashed_password'
        };

        test('creates a DOSEN account with 201 and never returns the password hash', async () => {
            prisma.user.findFirst.mockResolvedValue(null);
            bcrypt.hash.mockResolvedValue('hashed_password');
            prisma.user.create.mockResolvedValue(created);

            const res = createMockRes();
            await authController.adminCreateUser(makeReq(), res);

            expect(bcrypt.hash).toHaveBeenCalledWith('Rahasia123', 10);
            expect(prisma.user.create.mock.calls[0][0].data).toEqual(expect.objectContaining({
                nama: 'Pak Dosen', username: 'dosen_1', password: 'hashed_password', role: 'DOSEN', nim_nip: null, email: null
            }));
            expect(res.status).toHaveBeenCalledWith(201);
            const payload = res.json.mock.calls[0][0];
            expect(payload.status).toBe('success');
            expect(payload.data).toEqual(expect.objectContaining({ id: 5, username: 'dosen_1', nama: 'Pak Dosen', role: 'DOSEN' }));
            expect(JSON.stringify(payload)).not.toContain('hashed_password');
            expect(payload.data).not.toHaveProperty('password');
        });

        test.each(['ADMIN', 'MAHASISWA'])('creates the requested role %s', async (role) => {
            prisma.user.findFirst.mockResolvedValue(null);
            bcrypt.hash.mockResolvedValue('hashed_password');
            prisma.user.create.mockResolvedValue({ ...created, role });

            const res = createMockRes();
            await authController.adminCreateUser(makeReq({ role }), res);

            expect(prisma.user.create.mock.calls[0][0].data.role).toBe(role);
            expect(res.status).toHaveBeenCalledWith(201);
        });

        test('stores email lowercased and nim_nip', async () => {
            prisma.user.findFirst.mockResolvedValue(null);
            bcrypt.hash.mockResolvedValue('hashed_password');
            prisma.user.create.mockResolvedValue({ ...created, email: 'dosen@telkom.ac.id', nim_nip: '198012345678' });

            const res = createMockRes();
            await authController.adminCreateUser(makeReq({ email: 'Dosen@Telkom.AC.id', nim_nip: '198012345678' }), res);

            const { data } = prisma.user.create.mock.calls[0][0];
            expect(data.email).toBe('dosen@telkom.ac.id');
            expect(data.nim_nip).toBe('198012345678');
            expect(res.json.mock.calls[0][0].data).toEqual(expect.objectContaining({ email: 'dosen@telkom.ac.id', nim_nip: '198012345678' }));
        });

        test('writes an ADMIN_CREATE_USER audit entry', async () => {
            prisma.user.findFirst.mockResolvedValue(null);
            bcrypt.hash.mockResolvedValue('hashed_password');
            prisma.user.create.mockResolvedValue(created);

            await authController.adminCreateUser(makeReq(), createMockRes());

            expect(logAudit).toHaveBeenCalledWith(expect.objectContaining({
                action: 'ADMIN_CREATE_USER',
                performedBy: 99,
                targetUserId: 5,
                ip: '10.0.0.1'
            }));
        });

        test('uses the same duplicate rules as register: soft-deleted rows count, 409 with an Indonesian message', async () => {
            prisma.user.findFirst.mockResolvedValue({ username: 'dosen_1', nim_nip: null, email: null });

            const res = createMockRes();
            await authController.adminCreateUser(makeReq(), res);

            const { where } = prisma.user.findFirst.mock.calls[0][0];
            expect(JSON.stringify(where)).not.toContain('deletedAt');
            expect(where.OR).toEqual(expect.arrayContaining([{ username: 'dosen_1' }]));
            expect(res.status).toHaveBeenCalledWith(409);
            expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Username sudah digunakan' });
            expect(prisma.user.create).not.toHaveBeenCalled();
            expect(logAudit).not.toHaveBeenCalled();
        });

        test('409 for a duplicate email, compared lowercased', async () => {
            prisma.user.findFirst.mockResolvedValue({ username: 'lain', nim_nip: null, email: 'dosen@telkom.ac.id' });

            const res = createMockRes();
            await authController.adminCreateUser(makeReq({ email: 'DOSEN@telkom.ac.id' }), res);

            expect(prisma.user.findFirst.mock.calls[0][0].where.OR).toEqual(expect.arrayContaining([{ email: 'dosen@telkom.ac.id' }]));
            expect(res.status).toHaveBeenCalledWith(409);
            expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Email sudah terdaftar' });
        });

        test('maps a concurrent unique-constraint race (P2002) to 409', async () => {
            prisma.user.findFirst.mockResolvedValue(null);
            bcrypt.hash.mockResolvedValue('hashed_password');
            prisma.user.create.mockRejectedValue(Object.assign(new Error('Unique constraint failed'), { code: 'P2002' }));

            const res = createMockRes();
            await authController.adminCreateUser(makeReq(), res);

            expect(res.status).toHaveBeenCalledWith(409);
            expect(logAudit).not.toHaveBeenCalled();
        });
    });

    /**
     * PASSWORD POLICY (min 8)
     */
    describe('password policy (min 8)', () => {
        // '1234567' is the brief's example; 'abc1234' has a letter AND a digit, so only the length rule can reject it.
        test.each([
            ['registerSchema', { nama: 'Budi', username: 'budi_1' }, 'password'],
            ['changePasswordSchema', { oldPassword: 'lama12345' }, 'newPassword'],
            ['resetPasswordSchema', { token: 'tok' }, 'newPassword'],
            ['adminResetPasswordSchema', { id_user: 7 }, 'new_password'],
            ['adminCreateUserSchema', { nama: 'Pak Dosen', username: 'dosen_1', role: 'DOSEN' }, 'password'],
        ])('%s rejects a 7 character password with 400 "Password minimal 8 karakter"', async (schemaName, base, field) => {
            const schema = { registerSchema, adminCreateUserSchema, changePasswordSchema, resetPasswordSchema, adminResetPasswordSchema }[schemaName];

            for (const short of ['1234567', 'abc1234']) {
                const { res, next } = await run(schema, { ...base, [field]: short });
                expect(next).not.toHaveBeenCalled();
                expect(res.status).toHaveBeenCalledWith(400);
                expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                    status: 'error',
                    message: expect.stringContaining('Password minimal 8 karakter')
                }));
            }
        });

        test.each([
            ['registerSchema', { nama: 'Budi', username: 'budi_1' }, 'password'],
            ['changePasswordSchema', { oldPassword: 'lama12345' }, 'newPassword'],
            ['resetPasswordSchema', { token: 'tok' }, 'newPassword'],
            ['adminResetPasswordSchema', { id_user: 7 }, 'new_password'],
            ['adminCreateUserSchema', { nama: 'Pak Dosen', username: 'dosen_1', role: 'DOSEN' }, 'password'],
        ])('%s accepts an 8 character password', async (schemaName, base, field) => {
            const schema = { registerSchema, adminCreateUserSchema, changePasswordSchema, resetPasswordSchema, adminResetPasswordSchema }[schemaName];

            const { req, next } = await run(schema, { ...base, [field]: 'abcdef12' });
            expect(next).toHaveBeenCalledWith();
            expect(req.body[field]).toBe('abcdef12');
        });
    });

    /**
     * LOGIN TESTS
     */
    describe('login', () => {
        const mockCredentials = {
            username: 'testu',
            password: 'password123'
        };

        const mockUser = {
            id_user: 1,
            username: 'testu',
            password: 'hashed_password',
            nama: 'Test User',
            role: 'MAHASISWA',
            deletedAt: null
        };

        test('should login successfully with correct credentials', async () => {
            process.env.JWT_SECRET = 'test_secret';
            prisma.user.findFirst.mockResolvedValue(mockUser);
            bcrypt.compare.mockResolvedValue(true);
            jwt.sign.mockReturnValue('mock_token');

            const req = createMockReq(mockCredentials);
            const res = createMockRes();

            await authController.login(req, res);

            expect(prisma.user.findFirst).toHaveBeenCalledWith({ where: { username: 'testu', deletedAt: null } });
            expect(bcrypt.compare).toHaveBeenCalledWith('password123', 'hashed_password');
            expect(jwt.sign).toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                message: 'Login berhasil',
                data: expect.objectContaining({
                    token: 'mock_token'
                })
            }));
            // changePassword returns the very same shape (see its test)
            expect(Object.keys(res.json.mock.calls[0][0].data).sort()).toEqual(
                ['id_user', 'nama', 'refresh_token', 'role', 'token', 'username']
            );
        });

        test('should return 401 if user not found', async () => {
            prisma.user.findFirst.mockResolvedValue(null);

            const req = createMockReq(mockCredentials);
            const res = createMockRes();

            await authController.login(req, res);

            expect(res.status).toHaveBeenCalledWith(401);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Username atau password salah'
            });
        });

        test('should return 401 if password incorrect', async () => {
            prisma.user.findFirst.mockResolvedValue(mockUser);
            bcrypt.compare.mockResolvedValue(false);

            const req = createMockReq(mockCredentials);
            const res = createMockRes();

            await authController.login(req, res);

            expect(res.status).toHaveBeenCalledWith(401);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Username atau password salah'
            });
        });
    });

    /**
     * GET ME TESTS
     */
    describe('getMe', () => {
        test('should return user data', async () => {
            const mockUser = { id_user: 1, nama: 'User', username: 'u', role: 'MAHASISWA' };
            const req = createMockReq({}, mockUser);
            const res = createMockRes();

            await authController.getMe(req, res);

            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                data: expect.objectContaining({
                    id: 1,
                    nama: 'User'
                })
            }));
        });

        test('should return the push notification preference so the app can show the real toggle state', async () => {
            for (const enabled of [true, false]) {
                const mockUser = { id_user: 1, nama: 'User', username: 'u', role: 'MAHASISWA', nim_nip: null, push_notifications_enabled: enabled };
                const res = createMockRes();

                await authController.getMe(createMockReq({}, mockUser), res);

                expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                    data: expect.objectContaining({ push_notifications_enabled: enabled })
                }));
            }
        });
    });

    /**
     * LOGOUT TESTS
     */
    describe('logout', () => {
        test('should clear FCM token and logout', async () => {
            const req = createMockReq({}, { id_user: 1 });
            const res = createMockRes();
            prisma.user.update.mockResolvedValue({});

            await authController.logout(req, res);

            expect(prisma.user.update).toHaveBeenCalledWith({
                where: { id_user: 1 },
                data: { fcm_token: null }
            });
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith({
                status: 'success',
                message: 'Logout berhasil'
            });
        });
    });

    /**
     * CHANGE PASSWORD TESTS
     */
    describe('changePassword', () => {
        const changePasswordUser = {
            id_user: 1, username: 'testu', nama: 'Test User', role: 'MAHASISWA', password: 'hashed_old_pass'
        };

        test('should change password successfully', async () => {
            const req = createMockReq({
                oldPassword: 'oldpass',
                newPassword: 'newpassword123'
            }, { id_user: 1 });
            const res = createMockRes();

            prisma.user.findUnique.mockResolvedValue({ ...changePasswordUser });
            bcrypt.compare.mockResolvedValue(true);
            bcrypt.hash.mockResolvedValue('hashed_new_pass');
            prisma.user.update.mockReturnValue('UPDATE_OP');
            prisma.refreshToken.deleteMany.mockReturnValue('REVOKE_OP');
            prisma.refreshToken.create.mockReturnValue('CREATE_OP');
            prisma.$transaction.mockResolvedValue([]);
            jwt.sign.mockReturnValue('new_access_token');

            await authController.changePassword(req, res);

            expect(bcrypt.compare).toHaveBeenCalledWith('oldpass', 'hashed_old_pass');
            expect(bcrypt.hash).toHaveBeenCalledWith('newpassword123', 10);
            expect(prisma.user.update).toHaveBeenCalledWith({
                where: { id_user: 1 },
                data: { password: 'hashed_new_pass' }
            });
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                message: 'Password berhasil diubah'
            }));
        });

        test('revokes every refresh token in the transaction, then issues a fresh pair for the caller (login response shape)', async () => {
            const req = createMockReq({
                oldPassword: 'oldpass',
                newPassword: 'newpassword123'
            }, { id_user: 1 });
            const res = createMockRes();

            prisma.user.findUnique.mockResolvedValue({ ...changePasswordUser });
            bcrypt.compare.mockResolvedValue(true);
            bcrypt.hash.mockResolvedValue('hashed_new_pass');
            prisma.user.update.mockReturnValue('UPDATE_OP');
            prisma.refreshToken.deleteMany.mockReturnValue('REVOKE_OP');
            prisma.refreshToken.create.mockReturnValue('CREATE_OP');
            prisma.$transaction.mockResolvedValue([]);
            jwt.sign.mockReturnValue('new_access_token');

            await authController.changePassword(req, res);

            // all old tokens go first, the new one is created after them (order matters inside the transaction)
            expect(prisma.refreshToken.deleteMany).toHaveBeenCalledWith({ where: { id_user: 1 } });
            expect(prisma.$transaction).toHaveBeenCalledWith(['UPDATE_OP', 'REVOKE_OP', 'CREATE_OP']);
            expect(prisma.refreshToken.create).toHaveBeenCalledWith({
                data: { token: 'mocked-uuid-token', id_user: 1, expiresAt: expect.any(Date) }
            });
            expect(jwt.sign).toHaveBeenCalledWith({ id: 1 }, process.env.JWT_SECRET, { expiresIn: '1h' });

            const body = res.json.mock.calls[0][0];
            expect(body.status).toBe('success');
            expect(body.data).toEqual({
                id_user: 1,
                token: 'new_access_token',
                refresh_token: 'mocked-uuid-token',
                username: 'testu',
                nama: 'Test User',
                role: 'MAHASISWA'
            });
            expect(JSON.stringify(body)).not.toContain('hashed');
        });

        test('does not revoke sessions when the old password is wrong', async () => {
            const req = createMockReq({ oldPassword: 'wrongpass', newPassword: 'newpassword123' }, { id_user: 1 });
            prisma.user.findUnique.mockResolvedValue({ id_user: 1, password: 'hashed_old_pass' });
            bcrypt.compare.mockResolvedValue(false);

            await authController.changePassword(req, createMockRes());

            expect(prisma.refreshToken.deleteMany).not.toHaveBeenCalled();
            expect(prisma.refreshToken.create).not.toHaveBeenCalled();
            expect(prisma.$transaction).not.toHaveBeenCalled();
        });

        test('should fail if old password incorrect', async () => {
            const req = createMockReq({
                oldPassword: 'wrongpass',
                newPassword: 'newpassword123'
            }, { id_user: 1 });
            const res = createMockRes();

            prisma.user.findUnique.mockResolvedValue({ id_user: 1, password: 'hashed_old_pass' });
            bcrypt.compare.mockResolvedValue(false);

            await authController.changePassword(req, res);

            // 400, not 401: a 401 makes clients think the session expired and log the user out
            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.status).not.toHaveBeenCalledWith(401);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Password lama salah'
            });
        });

        test('should fail if new password too short', async () => {
            const req = createMockReq({
                oldPassword: 'oldpass',
                newPassword: 'short'
            }, { id_user: 1 });
            const res = createMockRes();

            await authController.changePassword(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                message: 'Password minimal 8 karakter'
            }));
        });

        test('should fail if new password is 7 characters', async () => {
            const req = createMockReq({
                oldPassword: 'oldpass',
                newPassword: 'abc1234'
            }, { id_user: 1 });
            const res = createMockRes();

            await authController.changePassword(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(prisma.$transaction).not.toHaveBeenCalled();
        });
    });

    /**
     * ADMIN RESET PASSWORD TESTS
     */
    describe('adminResetPassword', () => {
        const admin = { id_user: 99, nama: 'Admin' };

        test('revokes every refresh token of the target user in the same transaction as the password update', async () => {
            const req = { ...createMockReq({ id_user: '7', new_password: 'Baru12345' }, admin), ip: '10.0.0.1', headers: {} };
            const res = createMockRes();

            prisma.user.findUnique.mockResolvedValue({ id_user: 7, nama: 'Budi', deletedAt: null });
            bcrypt.hash.mockResolvedValue('hashed_new_pass');
            prisma.user.update.mockReturnValue('UPDATE_OP');
            prisma.refreshToken.deleteMany.mockReturnValue('REVOKE_OP');
            prisma.$transaction.mockResolvedValue([]);

            await authController.adminResetPassword(req, res);

            expect(prisma.user.update).toHaveBeenCalledWith({
                where: { id_user: 7 },
                data: { password: 'hashed_new_pass' }
            });
            expect(prisma.refreshToken.deleteMany).toHaveBeenCalledWith({ where: { id_user: 7 } });
            expect(prisma.$transaction).toHaveBeenCalledWith(['UPDATE_OP', 'REVOKE_OP']);
            expect(logAudit).toHaveBeenCalledWith(expect.objectContaining({ action: 'ADMIN_RESET_PASSWORD', targetUserId: 7 }));
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith({
                status: 'success',
                message: 'Password untuk Budi berhasil direset'
            });
        });

        test('returns Indonesian messages for missing fields and an unknown user', async () => {
            const missing = createMockRes();
            await authController.adminResetPassword({ ...createMockReq({ id_user: 7 }, admin), ip: '10.0.0.1', headers: {} }, missing);
            expect(missing.status).toHaveBeenCalledWith(400);
            expect(missing.json).toHaveBeenCalledWith({ status: 'error', message: 'id_user dan new_password wajib diisi' });

            prisma.user.findUnique.mockResolvedValue(null);
            const unknown = createMockRes();
            await authController.adminResetPassword({ ...createMockReq({ id_user: 7, new_password: 'Baru12345' }, admin), ip: '10.0.0.1', headers: {} }, unknown);
            expect(unknown.status).toHaveBeenCalledWith(404);
            expect(unknown.json).toHaveBeenCalledWith({ status: 'error', message: 'Pengguna tidak ditemukan' });
        });

        test('rejects a 7 character password without touching the database', async () => {
            const req = { ...createMockReq({ id_user: 7, new_password: 'abc1234' }, admin), ip: '10.0.0.1', headers: {} };
            const res = createMockRes();

            await authController.adminResetPassword(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ message: 'Password minimal 8 karakter' }));
            expect(prisma.$transaction).not.toHaveBeenCalled();
        });
    });

    /**
     * RESET PASSWORD WITH TOKEN TESTS
     */
    describe('resetPasswordWithToken', () => {
        const validRecord = () => ({
            id: 5,
            id_user: 3,
            usedAt: null,
            expiresAt: new Date(Date.now() + 60 * 1000),
            user: { id_user: 3, nama: 'Budi', deletedAt: null }
        });

        test('revokes every refresh token of the user in the same transaction as the password update', async () => {
            const req = { ...createMockReq({ token: 'reset-token', newPassword: 'Baru12345' }), ip: '10.0.0.1', headers: {} };
            const res = createMockRes();

            prisma.passwordResetToken.findUnique.mockResolvedValue(validRecord());
            bcrypt.hash.mockResolvedValue('hashed_new_pass');
            prisma.user.update.mockReturnValue('UPDATE_OP');
            prisma.passwordResetToken.update.mockReturnValue('USED_OP');
            prisma.refreshToken.deleteMany.mockReturnValue('REVOKE_OP');
            prisma.$transaction.mockResolvedValue([]);

            await authController.resetPasswordWithToken(req, res);

            expect(prisma.refreshToken.deleteMany).toHaveBeenCalledWith({ where: { id_user: 3 } });
            expect(prisma.$transaction).toHaveBeenCalledTimes(1);
            const ops = prisma.$transaction.mock.calls[0][0];
            expect(ops).toEqual(expect.arrayContaining(['UPDATE_OP', 'USED_OP', 'REVOKE_OP']));
            expect(ops).toHaveLength(3);
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith({ status: 'success', message: 'Password berhasil direset' });
        });

        test('does not revoke sessions for an invalid or used token', async () => {
            const req = { ...createMockReq({ token: 'reset-token', newPassword: 'Baru12345' }), ip: '10.0.0.1', headers: {} };
            const res = createMockRes();

            prisma.passwordResetToken.findUnique.mockResolvedValue({ ...validRecord(), usedAt: new Date() });

            await authController.resetPasswordWithToken(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Token reset tidak valid atau sudah kedaluwarsa' });
            expect(prisma.refreshToken.deleteMany).not.toHaveBeenCalled();
            expect(prisma.$transaction).not.toHaveBeenCalled();
        });
    });

    /**
     * REQUEST PASSWORD RESET TESTS
     */
    describe('requestPasswordReset', () => {
        test('looks the email up case-insensitively (register stores emails lowercased)', async () => {
            prisma.user.findFirst.mockResolvedValue(null);

            const res = createMockRes();
            await authController.requestPasswordReset(createMockReq({ username: 'Budi.Santoso@Telkom.AC.id' }), res);

            const { where } = prisma.user.findFirst.mock.calls[0][0];
            expect(where.deletedAt).toBeNull();
            expect(where.OR).toEqual([
                { username: 'Budi.Santoso@Telkom.AC.id' },
                { email: { equals: 'Budi.Santoso@Telkom.AC.id', mode: 'insensitive' } }
            ]);
        });

        test('answers 200 with the same Indonesian message whether or not the account exists', async () => {
            prisma.user.findFirst.mockResolvedValue(null);

            const res = createMockRes();
            await authController.requestPasswordReset(createMockReq({ username: 'tidak.ada' }), res);

            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith({
                status: 'success',
                message: 'Jika username atau email terdaftar, tautan reset password telah dikirim.'
            });
        });
    });

    /**
     * REGISTER FCM TOKEN TESTS
     */
    describe('registerFcmToken', () => {
        test('should register token successfully', async () => {
            const req = createMockReq({ fcm_token: 'token123' }, { id_user: 1 });
            const res = createMockRes();
            prisma.user.update.mockResolvedValue({});

            await authController.registerFcmToken(req, res);

            expect(prisma.user.update).toHaveBeenCalledWith({
                where: { id_user: 1 },
                data: { fcm_token: 'token123' }
            });
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('should fail if token missing', async () => {
            const req = createMockReq({}, { id_user: 1 });
            const res = createMockRes();

            await authController.registerFcmToken(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
        });
    });

    /**
     * REACTIVATE USER TESTS
     */
    describe('reactivateUser', () => {
        test('reactivates the user but never restores soft-deleted biometric data', async () => {
            const req = { params: { id_user: '5' }, user: { id_user: 1, nama: 'Admin' }, ip: '127.0.0.1', headers: {} };
            const res = createMockRes();
            prisma.user.findUnique.mockResolvedValue({ id_user: 5, nama: 'Budi', deletedAt: new Date() });
            prisma.user.update.mockResolvedValue({});

            await authController.reactivateUser(req, res);

            expect(prisma.user.update).toHaveBeenCalledWith({
                where: { id_user: 5 },
                data: { deletedAt: null }
            });
            expect(prisma.dataBiometrik.updateMany).not.toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('returns 404 when the user is not deactivated', async () => {
            const req = { params: { id_user: '5' }, user: { id_user: 1, nama: 'Admin' }, ip: '127.0.0.1', headers: {} };
            const res = createMockRes();
            prisma.user.findUnique.mockResolvedValue({ id_user: 5, nama: 'Budi', deletedAt: null });

            await authController.reactivateUser(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
            expect(prisma.user.update).not.toHaveBeenCalled();
        });
    });

    describe('uploadProfilePicture', () => {
        test('a storage failure returns a generic 500 and never leaks error.message', async () => {
            const { uploadFile } = require('../utils/r2FileHandler');
            const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
            uploadFile.mockRejectedValueOnce(new Error('connect ECONNREFUSED r2.internal.example:9000 password=hunter2'));
            const req = {
                user: { id_user: 1 },
                file: { buffer: Buffer.from('img'), originalname: 'me.jpg', mimetype: 'image/jpeg' },
            };
            const res = createMockRes();

            try {
                await authController.uploadProfilePicture(req, res);

                expect(res.status).toHaveBeenCalledWith(500);
                expect(res.json).toHaveBeenCalledWith({
                    status: 'error',
                    message: 'Terjadi kesalahan pada server'
                });
                expect(JSON.stringify(res.json.mock.calls)).not.toMatch(/ECONNREFUSED|hunter2/);
                expect(errorSpy).toHaveBeenCalled(); // the real error is logged, not returned
            } finally {
                errorSpy.mockRestore();
            }
        });
    });
});
