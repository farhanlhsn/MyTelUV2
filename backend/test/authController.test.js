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
        create: jest.fn(),
        update: jest.fn(),
    }
}));

jest.mock('bcryptjs', () => ({
    hash: jest.fn(),
    compare: jest.fn(),
}));

jest.mock('jsonwebtoken', () => ({
    sign: jest.fn(),
}));

jest.mock('../utils/auditLogger', () => ({
    logAudit: jest.fn(),
}));

// Import mocked modules
const prisma = require('../utils/prisma');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { logAudit } = require('../utils/auditLogger');

// Import the controller
const authController = require('../controllers/authController');

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
        jest.clearAllMocks();
    });

    /**
     * REGISTER TESTS
     */
    describe('register', () => {
        const mockUserData = {
            nama: 'Test User',
            username: 'testu',
            password: 'password123',
            role: 'MAHASISWA'
        };

        test('should register a new user successfully', async () => {
            prisma.user.findUnique.mockResolvedValue(null); // Username valid (not taken)
            bcrypt.hash.mockResolvedValue('hashed_password');
            prisma.user.create.mockResolvedValue({
                id_user: 1,
                ...mockUserData,
                role: 'MAHASISWA'
            });

            const req = createMockReq(mockUserData);
            const res = createMockRes();

            await authController.register(req, res);

            expect(prisma.user.findUnique).toHaveBeenCalledWith({ where: { username: 'testu' } });
            expect(bcrypt.hash).toHaveBeenCalledWith('password123', 10);
            expect(prisma.user.create).toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(201);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                message: 'User created successfully'
            }));
        });

        test('should fail if username already exists', async () => {
            prisma.user.findUnique.mockResolvedValue({ id_user: 1 }); // User exists

            const req = createMockReq(mockUserData);
            const res = createMockRes();

            await authController.register(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Username already exists'
            });
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
            prisma.user.findUnique.mockResolvedValue(mockUser);
            bcrypt.compare.mockResolvedValue(true);
            jwt.sign.mockReturnValue('mock_token');

            const req = createMockReq(mockCredentials);
            const res = createMockRes();

            await authController.login(req, res);

            expect(prisma.user.findUnique).toHaveBeenCalled();
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
            prisma.user.findUnique.mockResolvedValue(null);

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
            prisma.user.findUnique.mockResolvedValue(mockUser);
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
            prisma.user.update.mockResolvedValue({});

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
                message: 'New password must be at least 6 characters'
            }));
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
