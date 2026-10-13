/**
 * Unit Testing - GET /biometrik/status (own biometric status)
 *
 * data: { terdaftar, diperbarui } for req.user.id_user; a soft-deleted row is "not registered".
 */

jest.mock('../utils/prisma', () => ({
    dataBiometrik: { findUnique: jest.fn() },
}));

// the controller module loads these at require time; none of them is used by the status endpoint
jest.mock('../utils/pythonClient', () => ({ pythonClient: { get: jest.fn(), post: jest.fn() } }));
jest.mock('../utils/r2FileHandler', () => ({ uploadFile: jest.fn(), deleteFile: jest.fn() }));
jest.mock('../utils/auditLogger', () => ({ logAudit: jest.fn(), BIOMETRIK_ACTIONS: {} }));

const prisma = require('../utils/prisma');
const { getMyBiometrikStatus } = require('../controllers/biometrikController');

const createReq = (id_user = 7) => ({ user: { id_user, role: 'MAHASISWA' }, headers: {} });

const createRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

const run = async (req) => {
    const res = createRes();
    await getMyBiometrikStatus(req, res, jest.fn());
    return res;
};

beforeEach(() => {
    prisma.dataBiometrik.findUnique.mockReset();
});

describe('getMyBiometrikStatus', () => {
    test('registered: terdaftar true with the ISO time of the last update', async () => {
        const updatedAt = new Date('2026-10-01T03:04:05.000Z');
        prisma.dataBiometrik.findUnique.mockResolvedValue({ deletedAt: null, updatedAt });

        const res = await run(createReq(7));

        expect(res.status).toHaveBeenCalledWith(200);
        const body = res.json.mock.calls[0][0];
        expect(body.status).toBe('success');
        expect(body.data).toEqual({ terdaftar: true, diperbarui: '2026-10-01T03:04:05.000Z' });
    });

    test('looks up the logged-in user only', async () => {
        prisma.dataBiometrik.findUnique.mockResolvedValue(null);

        await run(createReq(42));

        expect(prisma.dataBiometrik.findUnique).toHaveBeenCalledTimes(1);
        expect(prisma.dataBiometrik.findUnique.mock.calls[0][0].where).toEqual({ id_user: 42 });
    });

    test('not registered (no row): terdaftar false, diperbarui null', async () => {
        prisma.dataBiometrik.findUnique.mockResolvedValue(null);

        const res = await run(createReq());

        expect(res.status).toHaveBeenCalledWith(200);
        expect(res.json.mock.calls[0][0].data).toEqual({ terdaftar: false, diperbarui: null });
    });

    test('soft-deleted row: terdaftar false, diperbarui null', async () => {
        prisma.dataBiometrik.findUnique.mockResolvedValue({
            deletedAt: new Date('2026-10-02T00:00:00.000Z'),
            updatedAt: new Date('2026-10-02T00:00:00.000Z'),
        });

        const res = await run(createReq());

        expect(res.json.mock.calls[0][0].data).toEqual({ terdaftar: false, diperbarui: null });
    });

    test('never returns face data', async () => {
        prisma.dataBiometrik.findUnique.mockResolvedValue({
            deletedAt: null,
            updatedAt: new Date('2026-10-01T03:04:05.000Z'),
            face_embedding: [0.1, 0.2],
            photo_url: 'https://example.com/face.jpg',
        });

        const res = await run(createReq());

        const body = res.json.mock.calls[0][0];
        expect(Object.keys(body.data).sort()).toEqual(['diperbarui', 'terdaftar']);
        // the query itself only selects the two status columns
        expect(prisma.dataBiometrik.findUnique.mock.calls[0][0].select).toEqual({
            deletedAt: true,
            updatedAt: true,
        });
    });
});
