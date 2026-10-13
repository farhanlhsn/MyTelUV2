/**
 * Unit Testing - utils/firebase push helpers
 *
 * Every helper honours the user's push_notifications_enabled preference, skips deactivated accounts,
 * and clears FCM tokens that Firebase reports as invalid.
 */

const mockSend = jest.fn();
const mockSendEachForMulticast = jest.fn();

jest.mock('firebase-admin', () => ({
    initializeApp: jest.fn(),
    credential: { cert: jest.fn(() => ({})) },
    messaging: jest.fn(() => ({ send: mockSend, sendEachForMulticast: mockSendEachForMulticast }))
}));

// A service account key "exists" whatever is (or is not) in backend/config on this machine
jest.mock('fs', () => {
    const actual = jest.requireActual('fs');
    const isKey = (p) => String(p).includes('adminsdk');
    return {
        ...actual,
        existsSync: jest.fn((p) => isKey(p) || actual.existsSync(p)),
        readFileSync: jest.fn((p, ...rest) => (isKey(p) ? '{"project_id":"test"}' : actual.readFileSync(p, ...rest)))
    };
});

jest.mock('../utils/prisma', () => ({
    user: { findUnique: jest.fn(), updateMany: jest.fn() },
    pesertaKelas: { findMany: jest.fn() }
}));

const prisma = require('../utils/prisma');
const firebase = require('../utils/firebase');

const INVALID_TOKEN_CODES = ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'];
const fcmError = (code) => Object.assign(new Error(`FCM error ${code}`), { code });

describe('utils/firebase', () => {
    let logSpy;
    let errorSpy;

    beforeEach(() => {
        jest.clearAllMocks();
        mockSend.mockReset().mockResolvedValue('projects/test/messages/1');
        mockSendEachForMulticast.mockReset();
        prisma.user.findUnique.mockReset();
        prisma.user.updateMany.mockReset().mockResolvedValue({ count: 1 });
        prisma.pesertaKelas.findMany.mockReset();
        logSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
        errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    });

    afterEach(() => {
        logSpy.mockRestore();
        errorSpy.mockRestore();
    });

    const activeUser = (overrides = {}) => ({
        fcm_token: 'token-1', push_notifications_enabled: true, deletedAt: null, ...overrides
    });

    describe('single-user helpers', () => {
        // Every helper that notifies one user, called for user 7
        const helpers = {
            sendUserNotification: () => firebase.sendUserNotification(7, 'Judul', 'Isi', { type: 'KENDARAAN_APPROVED' }),
            sendParkingNotification: () => firebase.sendParkingNotification(7, 'MASUK', { plat_nomor: 'D 1 A', nama_kendaraan: 'Motor' }, 'Gedung A'),
            sendSocialNotification: () => firebase.sendSocialNotification(7, 'LIKE', 'Budi', 'Halo semua')
        };

        test.each(Object.keys(helpers))('%s sends to an active user with push enabled', async (name) => {
            prisma.user.findUnique.mockResolvedValue(activeUser());

            const result = await helpers[name]();

            expect(result.success).toBe(true);
            expect(prisma.user.findUnique).toHaveBeenCalledWith(expect.objectContaining({
                where: { id_user: 7 },
                select: expect.objectContaining({ fcm_token: true, push_notifications_enabled: true, deletedAt: true })
            }));
            expect(mockSend).toHaveBeenCalledWith(expect.objectContaining({ token: 'token-1' }));
        });

        test.each(Object.keys(helpers))('%s skips a user who turned push notifications off', async (name) => {
            prisma.user.findUnique.mockResolvedValue(activeUser({ push_notifications_enabled: false }));

            const result = await helpers[name]();

            expect(result.success).toBe(false);
            expect(mockSend).not.toHaveBeenCalled();
        });

        test.each(Object.keys(helpers))('%s skips a deactivated account', async (name) => {
            prisma.user.findUnique.mockResolvedValue(activeUser({ deletedAt: new Date('2026-10-01T00:00:00Z') }));

            const result = await helpers[name]();

            expect(result.success).toBe(false);
            expect(mockSend).not.toHaveBeenCalled();
        });

        test('skips a user without an FCM token', async () => {
            prisma.user.findUnique.mockResolvedValue(activeUser({ fcm_token: null }));

            const result = await firebase.sendUserNotification(7, 'Judul', 'Isi');

            expect(result.success).toBe(false);
            expect(mockSend).not.toHaveBeenCalled();
        });

        test.each(INVALID_TOKEN_CODES)('clears the stored token when FCM answers %s', async (code) => {
            prisma.user.findUnique.mockResolvedValue(activeUser({ fcm_token: 'dead-token' }));
            mockSend.mockRejectedValueOnce(fcmError(code));

            const result = await firebase.sendUserNotification(7, 'Judul', 'Isi');

            expect(result.success).toBe(false);
            expect(prisma.user.updateMany).toHaveBeenCalledWith({
                where: { fcm_token: { in: ['dead-token'] } },
                data: { fcm_token: null }
            });
        });

        test('keeps the token on any other FCM error', async () => {
            prisma.user.findUnique.mockResolvedValue(activeUser());
            mockSend.mockRejectedValueOnce(fcmError('messaging/internal-error'));

            await firebase.sendUserNotification(7, 'Judul', 'Isi');

            expect(prisma.user.updateMany).not.toHaveBeenCalled();
        });

        test('only the preference-checking helpers are exported (no raw send-to-token)', () => {
            expect(firebase.sendPushNotification).toBeUndefined();
        });
    });

    describe('class-wide helpers (multicast)', () => {
        const peserta = (fcm_token, overrides = {}) => ({
            mahasiswa: { fcm_token, push_notifications_enabled: true, deletedAt: null, ...overrides }
        });

        test('only active students with push enabled receive the notification', async () => {
            prisma.pesertaKelas.findMany.mockResolvedValue([
                peserta('token-a'),
                peserta('token-off', { push_notifications_enabled: false }),
                peserta('token-gone', { deletedAt: new Date('2026-10-01T00:00:00Z') }),
                peserta(null),
                peserta('token-a') // same device twice
            ]);
            mockSendEachForMulticast.mockResolvedValue({ successCount: 1, failureCount: 0, responses: [{ success: true }] });

            const result = await firebase.sendAbsensiNotification(3, 'IF-45-01', 'Alpro');

            expect(result.success).toBe(true);
            expect(prisma.pesertaKelas.findMany).toHaveBeenCalledWith(expect.objectContaining({
                include: { mahasiswa: { select: expect.objectContaining({ fcm_token: true, push_notifications_enabled: true, deletedAt: true }) } }
            }));
            expect(mockSendEachForMulticast).toHaveBeenCalledWith(expect.objectContaining({ tokens: ['token-a'] }));
        });

        test('nobody to notify: FCM is not called', async () => {
            prisma.pesertaKelas.findMany.mockResolvedValue([peserta('token-off', { push_notifications_enabled: false })]);

            const result = await firebase.sendJadwalPenggantiNotification(3, {
                idJadwalPengganti: 1, namaKelas: 'IF-45-01', namaMatakuliah: 'Alpro', status: 'LIBUR',
                tanggalAsli: new Date('2026-10-14T00:00:00Z'), alasan: 'Rapat'
            });

            expect(result.success).toBe(false);
            expect(mockSendEachForMulticast).not.toHaveBeenCalled();
        });

        test('clears every token FCM reports as invalid, keeps the others', async () => {
            prisma.pesertaKelas.findMany.mockResolvedValue([peserta('ok'), peserta('unregistered'), peserta('busy'), peserta('malformed')]);
            mockSendEachForMulticast.mockResolvedValue({
                successCount: 1,
                failureCount: 3,
                responses: [
                    { success: true, messageId: 'm1' },
                    { success: false, error: fcmError('messaging/registration-token-not-registered') },
                    { success: false, error: fcmError('messaging/server-unavailable') },
                    { success: false, error: fcmError('messaging/invalid-registration-token') }
                ]
            });

            await firebase.sendAbsensiNotification(3, 'IF-45-01', 'Alpro');

            expect(prisma.user.updateMany).toHaveBeenCalledTimes(1);
            expect(prisma.user.updateMany).toHaveBeenCalledWith({
                where: { fcm_token: { in: ['unregistered', 'malformed'] } },
                data: { fcm_token: null }
            });
        });
    });
});
