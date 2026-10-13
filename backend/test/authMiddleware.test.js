/**
 * protect / authenticateToken: what req.user carries. GET /auth/me answers from req.user, so the
 * push preference the app shows in its settings must be loaded here.
 */
process.env.JWT_SECRET = 'test_secret';

const mockPrisma = {
    user: { findUnique: jest.fn() },
};

jest.mock('../utils/prisma', () => mockPrisma);

const jwt = require('jsonwebtoken');
const { protect, authenticateToken } = require('../middlewares/authMiddleware');

const token = () => jwt.sign({ id: 7 }, process.env.JWT_SECRET, { expiresIn: '1h' });

describe('authenticateToken', () => {
    beforeEach(() => {
        mockPrisma.user.findUnique.mockReset().mockResolvedValue({ id_user: 7, push_notifications_enabled: false });
    });

    test('loads the push notification preference together with the user', async () => {
        const user = await authenticateToken(token());

        const { where, select } = mockPrisma.user.findUnique.mock.calls[0][0];
        expect(where).toEqual({ id_user: 7, deletedAt: null });
        expect(select).toMatchObject({
            id_user: true,
            username: true,
            nama: true,
            role: true,
            nim_nip: true,
            push_notifications_enabled: true
        });
        expect(user.push_notifications_enabled).toBe(false);
    });

    test('still never selects secrets', async () => {
        await authenticateToken(token());

        const { select } = mockPrisma.user.findUnique.mock.calls[0][0];
        expect(select.password).toBeUndefined();
        expect(select.fcm_token).toBeUndefined();
    });
});

describe('protect', () => {
    test('puts the loaded user (with the push preference) on req.user', async () => {
        const dbUser = { id_user: 7, username: 'budi', nama: 'Budi', role: 'MAHASISWA', nim_nip: null, push_notifications_enabled: true };
        mockPrisma.user.findUnique.mockReset().mockResolvedValue(dbUser);
        const req = { headers: { authorization: `Bearer ${token()}` } };
        const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
        const next = jest.fn();

        await protect(req, res, next);

        expect(next).toHaveBeenCalledTimes(1);
        expect(req.user).toEqual(dbUser);
    });
});
