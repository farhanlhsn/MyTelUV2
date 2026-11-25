/**
 * Socket.IO authentication: a client must present a valid JWT in `socket.handshake.auth.token`
 * (the same token and verification as the HTTP `protect` middleware) or the connection is refused
 * with `Unauthorized`.
 *
 *  - unit tests call the exported middleware function directly
 *  - the wiring test boots the real server.js io instance on an ephemeral port and speaks the
 *    Socket.IO wire protocol over a raw WebSocket, so it proves `io.use(socketAuth)` is mounted
 */
process.env.JWT_SECRET = 'test_secret';

const mockPrisma = {
    $queryRaw: jest.fn(),
    $disconnect: jest.fn(),
    user: { findUnique: jest.fn(), findFirst: jest.fn() },
};

jest.mock('../utils/prisma', () => mockPrisma);

// uuid v13 is ESM only, which jest cannot load without a transform
jest.mock('uuid', () => ({ v4: () => 'mocked-uuid-token' }));

const jwt = require('jsonwebtoken');
const WebSocket = require('ws');
const { socketAuth } = require('../middlewares/socketAuthMiddleware');

const activeUser = {
    id_user: 7, username: 'budi', nama: 'Budi', role: 'MAHASISWA', nim_nip: '1301200001',
};
const validToken = () => jwt.sign({ id: 7 }, process.env.JWT_SECRET, { expiresIn: '1h' });

const socketWith = (handshake) => ({ handshake });

const run = async (socket) => {
    const next = jest.fn();
    await socketAuth(socket, next);
    return next;
};

const expectUnauthorized = (next) => {
    expect(next).toHaveBeenCalledTimes(1);
    const [err] = next.mock.calls[0];
    expect(err).toBeInstanceOf(Error);
    expect(err.message).toBe('Unauthorized');
};

beforeEach(() => {
    mockPrisma.user.findUnique.mockReset().mockResolvedValue(activeUser);
});

describe('socketAuth middleware', () => {
    test('accepts a valid signed token and attaches the user to the socket', async () => {
        const socket = socketWith({ auth: { token: validToken() } });

        const next = await run(socket);

        expect(next).toHaveBeenCalledTimes(1);
        expect(next).toHaveBeenCalledWith(); // no error argument
        expect(socket.user).toEqual(activeUser);
    });

    test('looks the user up like the HTTP protect middleware (soft-deleted users excluded)', async () => {
        await run(socketWith({ auth: { token: validToken() } }));

        expect(mockPrisma.user.findUnique).toHaveBeenCalledWith(expect.objectContaining({
            where: { id_user: 7, deletedAt: null },
        }));
    });

    test('rejects a handshake without auth', async () => {
        expectUnauthorized(await run(socketWith({})));
        expect(mockPrisma.user.findUnique).not.toHaveBeenCalled();
    });

    test('rejects a handshake with auth but no token', async () => {
        expectUnauthorized(await run(socketWith({ auth: {} })));
        expectUnauthorized(await run(socketWith({ auth: { token: '' } })));
        expect(mockPrisma.user.findUnique).not.toHaveBeenCalled();
    });

    test('rejects a token that is not a string', async () => {
        expectUnauthorized(await run(socketWith({ auth: { token: { $ne: null } } })));
        expectUnauthorized(await run(socketWith({ auth: { token: 12345 } })));
        expect(mockPrisma.user.findUnique).not.toHaveBeenCalled();
    });

    test('ignores a token passed anywhere but handshake.auth', async () => {
        const token = validToken();

        const next = await run(socketWith({
            auth: {},
            query: { token },
            headers: { authorization: `Bearer ${token}` },
        }));

        expectUnauthorized(next);
    });

    test('rejects a malformed token', async () => {
        expectUnauthorized(await run(socketWith({ auth: { token: 'not-a-jwt' } })));
    });

    test('rejects a token signed with another secret', async () => {
        const forged = jwt.sign({ id: 7 }, 'some-other-secret', { expiresIn: '1h' });

        expectUnauthorized(await run(socketWith({ auth: { token: forged } })));
        expect(mockPrisma.user.findUnique).not.toHaveBeenCalled();
    });

    test('rejects an expired token', async () => {
        const expired = jwt.sign({ id: 7 }, process.env.JWT_SECRET, { expiresIn: -10 });

        expectUnauthorized(await run(socketWith({ auth: { token: expired } })));
    });

    test('rejects a valid token whose user is gone or deactivated', async () => {
        mockPrisma.user.findUnique.mockResolvedValue(null);

        expectUnauthorized(await run(socketWith({ auth: { token: validToken() } })));
    });

    test('fails closed when the database lookup throws, without leaking the error', async () => {
        mockPrisma.user.findUnique.mockRejectedValue(new Error('password authentication failed'));

        const next = await run(socketWith({ auth: { token: validToken() } }));

        expectUnauthorized(next);
    });
});

describe('Socket.IO server wiring', () => {
    let io;
    let port;
    let exitSpy;

    beforeAll(async () => {
        exitSpy = jest.spyOn(process, 'exit').mockImplementation(() => {});
        jest.spyOn(console, 'log').mockImplementation(() => {});
        const loaded = require('../server');
        io = loaded.io;
        await new Promise((resolve) => loaded.server.listen(0, '127.0.0.1', resolve));
        port = loaded.server.address().port;
    });

    afterAll(async () => {
        await io.close();
        jest.restoreAllMocks();
    });

    // Engine.IO packet "0" = open, Socket.IO packet "40<json>" = CONNECT with auth payload,
    // "44<json>" = CONNECT_ERROR. Resolves with how the server answered the CONNECT.
    const connect = (auth) => new Promise((resolve, reject) => {
        const ws = new WebSocket(`ws://127.0.0.1:${port}/socket.io/?EIO=4&transport=websocket`);
        const timer = setTimeout(() => {
            ws.terminate();
            reject(new Error('timed out waiting for the Socket.IO handshake'));
        }, 5000);
        const finish = (result) => {
            clearTimeout(timer);
            ws.terminate();
            resolve(result);
        };

        ws.on('error', (err) => {
            clearTimeout(timer);
            reject(err);
        });
        ws.on('message', (raw) => {
            const packet = raw.toString();
            if (packet.startsWith('0')) {
                ws.send(auth === undefined ? '40' : `40${JSON.stringify(auth)}`);
            } else if (packet.startsWith('40')) {
                finish({ connected: true });
            } else if (packet.startsWith('44')) {
                finish({ connected: false, error: JSON.parse(packet.slice(2)) });
            }
        });
    });

    test('a client without a token is refused with Unauthorized', async () => {
        const result = await connect(undefined);

        expect(result.connected).toBe(false);
        expect(result.error.message).toBe('Unauthorized');
    });

    test('a client with a bad token is refused with Unauthorized', async () => {
        const result = await connect({ token: 'garbage' });

        expect(result.connected).toBe(false);
        expect(result.error.message).toBe('Unauthorized');
    });

    test('a client with a valid token connects', async () => {
        const result = await connect({ token: validToken() });

        expect(result.connected).toBe(true);
        expect(exitSpy).not.toHaveBeenCalled();
    });
});
