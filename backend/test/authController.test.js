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
const { registerSchema, changePasswordSchema, resetPasswordSchema, adminResetPasswordSchema } = require('../middlewares/zodSchemas');

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
                message: 'User created successfully'
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
        const run = async (schema, body) => {
            const req = { body };
            const res = createMockRes();
            const next = jest.fn();
            await validateZod(schema)(req, res, next);
            return { req, res, next };
        };
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
     * PASSWORD POLICY (min 8)
     */
    describe('password policy (min 8)', () => {
        const run = async (schema, body) => {
            const req = { body };
            const res = createMockRes();
            const next = jest.fn();
            await validateZod(schema)(req, res, next);
            return { req, res, next };
        };

        // '1234567' is the brief's example; 'abc1234' has a letter AND a digit, so only the length rule can reject it.
        test.each([
            ['registerSchema', { nama: 'Budi', username: 'budi_1' }, 'password'],
            ['changePasswordSchema', { oldPassword: 'lama12345' }, 'newPassword'],
            ['resetPasswordSchema', { token: 'tok' }, 'newPassword'],
            ['adminResetPasswordSchema', { id_user: 7 }, 'new_password'],
        ])('%s rejects a 7 character password with 400 "Password minimal 8 karakter"', async (schemaName, base, field) => {
            const schema = { registerSchema, changePasswordSchema, resetPasswordSchema, adminResetPasswordSchema }[schemaName];

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
        ])('%s accepts an 8 character password', async (schemaName, base, field) => {
            const schema = { registerSchema, changePasswordSchema, resetPasswordSchema, adminResetPasswordSchema }[schemaName];

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
                message: 'Login successful',
                data: expect.objectContaining({
                    token: 'mock_token'
                })
            }));
        });

        test('should return 401 if user not found', async () => {
            prisma.user.findFirst.mockResolvedValue(null);

            const req = createMockReq(mockCredentials);
            const res = createMockRes();

            await authController.login(req, res);

            expect(res.status).toHaveBeenCalledWith(401);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Invalid username or password'
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
                message: 'Invalid username or password'
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
                message: 'Logged out successfully'
            });
        });
    });

    /**
     * CHANGE PASSWORD TESTS
     */
    describe('changePassword', () => {
        test('should change password successfully', async () => {
            const req = createMockReq({
                oldPassword: 'oldpass',
                newPassword: 'newpassword123'
            }, { id_user: 1 });
            const res = createMockRes();

            prisma.user.findUnique.mockResolvedValue({ id_user: 1, password: 'hashed_old_pass' });
            bcrypt.compare.mockResolvedValue(true);
            bcrypt.hash.mockResolvedValue('hashed_new_pass');
            prisma.user.update.mockReturnValue('UPDATE_OP');
            prisma.refreshToken.deleteMany.mockReturnValue('REVOKE_OP');
            prisma.$transaction.mockResolvedValue([]);

            await authController.changePassword(req, res);

            expect(bcrypt.compare).toHaveBeenCalledWith('oldpass', 'hashed_old_pass');
            expect(bcrypt.hash).toHaveBeenCalledWith('newpassword123', 10);
            expect(prisma.user.update).toHaveBeenCalledWith({
                where: { id_user: 1 },
                data: { password: 'hashed_new_pass' }
            });
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith({
                status: 'success',
                message: 'Password changed successfully'
            });
        });

        test('revokes every refresh token of the user in the same transaction as the password update', async () => {
            const req = createMockReq({
                oldPassword: 'oldpass',
                newPassword: 'newpassword123'
            }, { id_user: 1 });
            const res = createMockRes();

            prisma.user.findUnique.mockResolvedValue({ id_user: 1, password: 'hashed_old_pass' });
            bcrypt.compare.mockResolvedValue(true);
            bcrypt.hash.mockResolvedValue('hashed_new_pass');
            prisma.user.update.mockReturnValue('UPDATE_OP');
            prisma.refreshToken.deleteMany.mockReturnValue('REVOKE_OP');
            prisma.$transaction.mockResolvedValue([]);

            await authController.changePassword(req, res);

            expect(prisma.refreshToken.deleteMany).toHaveBeenCalledWith({ where: { id_user: 1 } });
            expect(prisma.$transaction).toHaveBeenCalledWith(['UPDATE_OP', 'REVOKE_OP']);
        });

        test('does not revoke sessions when the old password is wrong', async () => {
            const req = createMockReq({ oldPassword: 'wrongpass', newPassword: 'newpassword123' }, { id_user: 1 });
            prisma.user.findUnique.mockResolvedValue({ id_user: 1, password: 'hashed_old_pass' });
            bcrypt.compare.mockResolvedValue(false);

            await authController.changePassword(req, createMockRes());

            expect(prisma.refreshToken.deleteMany).not.toHaveBeenCalled();
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

            expect(res.status).toHaveBeenCalledWith(401);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Old password is incorrect'
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
        });

        test('does not revoke sessions for an invalid or used token', async () => {
            const req = { ...createMockReq({ token: 'reset-token', newPassword: 'Baru12345' }), ip: '10.0.0.1', headers: {} };
            const res = createMockRes();

            prisma.passwordResetToken.findUnique.mockResolvedValue({ ...validRecord(), usedAt: new Date() });

            await authController.resetPasswordWithToken(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(prisma.refreshToken.deleteMany).not.toHaveBeenCalled();
            expect(prisma.$transaction).not.toHaveBeenCalled();
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
});
