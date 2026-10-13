/**
 * server.js hygiene: the app is loadable without listening, /health leaks nothing and probes the
 * configured services, Swagger is off in production, 5xx responses are generic, and shutdown closes
 * Socket.IO and reacts to unhandled rejections / exceptions.
 *
 * One server (`base`) is shared by everything that reads process.env per request. Behaviour decided
 * while the module loads (Swagger, the shutdown flag) re-requires server.js (jest.resetModules).
 * Mocks live in `mock*` objects declared up front, so a re-required server keeps seeing the same instances.
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

// exceljs (pulled in by the laporan routes) is heavy and registers a process 'exit' listener on every
// load, which would trip MaxListenersExceededWarning when server.js is re-required.
jest.mock('exceljs', () => ({}));

const request = require('supertest');

const ORIGINAL_ENV = { ...process.env };
const SERVICE_ENV_KEYS = [
    'PYTHON_SERVICE_URL', 'FACE_API_URL', 'PLATE_API_URL', 'ANOMALY_SERVICE_URL', 'ENABLE_SWAGGER', 'TEST_MODE',
];

const setEnv = (env = {}) => {
    SERVICE_ENV_KEYS.forEach((key) => delete process.env[key]);
    Object.assign(process.env, env);
};

const loadServer = (env = {}) => {
    jest.resetModules();
    setEnv(env);
    return require('../server');
};

let base;
let logSpy;
let errorSpy;
let exitSpy;

beforeAll(() => {
    jest.spyOn(console, 'log').mockImplementation(() => {});
    base = loadServer();
    jest.restoreAllMocks();
});

beforeEach(() => {
    mockPrisma.$queryRaw.mockReset().mockResolvedValue([{ '?column?': 1 }]);
    mockPrisma.$disconnect.mockReset().mockResolvedValue(undefined);
    mockPrisma.user.findFirst.mockReset();
    mockPrisma.user.findUnique.mockReset();
    logSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
    errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    exitSpy = jest.spyOn(process, 'exit').mockImplementation(() => {});
});

afterEach(() => {
    jest.restoreAllMocks();
    Object.keys(process.env).forEach((key) => {
        if (!(key in ORIGINAL_ENV)) delete process.env[key];
    });
    Object.assign(process.env, ORIGINAL_ENV);
});

describe('server.js exports', () => {
    test('exports app, server and io without listening or exiting', () => {
        const { app, server, io } = base;

        expect(typeof app).toBe('function');
        expect(server.listening).toBe(false);
        expect(typeof io.use).toBe('function');
        expect(app.get('io')).toBe(io);
        expect(exitSpy).not.toHaveBeenCalled();
    });
});

describe('GET /health', () => {
    let fetchSpy;

    beforeEach(() => {
        fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue({ ok: true });
    });

    test('a database failure is reported as db "error" without any raw error text', async () => {
        const { app } = base;
        mockPrisma.$queryRaw.mockRejectedValue(new Error('password authentication failed for user "postgres"'));

        const res = await request(app).get('/health');

        expect(res.status).toBe(503);
        expect(res.body).toMatchObject({ status: 'degraded', db: 'error' });
        expect(JSON.stringify(res.body).toLowerCase()).not.toContain('password');
        expect(JSON.stringify(res.body)).not.toContain('postgres');
        // the real error is logged server side instead
        expect(errorSpy.mock.calls.flat().join(' ')).toContain('password authentication failed');
    });

    test('everything up => 200 with status, db and the three services', async () => {
        const { app } = base;

        const res = await request(app).get('/health');

        expect(res.status).toBe(200);
        expect(res.body).toMatchObject({
            status: 'ok',
            db: 'ok',
            services: { face: 'ok', plate: 'ok', anomaly: 'ok' },
        });
    });

    test('probes the services at the configured URLs', async () => {
        const { app } = base;
        setEnv({
            PYTHON_SERVICE_URL: 'http://face.internal:9001',
            PLATE_API_URL: 'http://plate.internal:9002/',
            ANOMALY_SERVICE_URL: 'http://anomaly.internal:9003',
        });

        await request(app).get('/health');

        const urls = fetchSpy.mock.calls.map(([url]) => url).sort();
        expect(urls).toEqual([
            'http://anomaly.internal:9003/health',
            'http://face.internal:9001/health',
            'http://plate.internal:9002/health',
        ]);
        fetchSpy.mock.calls.forEach(([, options]) => expect(options.signal).toBeInstanceOf(AbortSignal));
    });

    test('keeps the localhost defaults when nothing is configured', async () => {
        const { app } = base;
        setEnv();

        await request(app).get('/health');

        const urls = fetchSpy.mock.calls.map(([url]) => url).sort();
        expect(urls).toEqual([
            'http://localhost:5001/health',
            'http://localhost:5003/health',
            'http://localhost:5051/health',
        ]);
    });

    test('the face service falls back to FACE_API_URL, the variable the rest of the backend uses', async () => {
        const { app } = base;
        setEnv({ FACE_API_URL: 'http://face-recognition:5051' });

        await request(app).get('/health');

        expect(fetchSpy.mock.calls.map(([url]) => url)).toContain('http://face-recognition:5051/health');
    });

    test('an unreachable or failing service is reported as "error" without the raw error text', async () => {
        const { app } = base;
        fetchSpy.mockImplementation(async (url) => {
            if (url.includes(':5051')) throw new Error('connect ECONNREFUSED 10.0.0.5:5051');
            if (url.includes(':5001')) return { ok: false };
            return { ok: true };
        });

        const res = await request(app).get('/health');

        expect(res.status).toBe(200); // the database is up; a down AI service does not flip the API to 503
        expect(res.body.services).toEqual({ face: 'error', plate: 'error', anomaly: 'ok' });
        expect(JSON.stringify(res.body)).not.toContain('ECONNREFUSED');
    });

    test('does not require auth and is not counted by the API limiter (1000 / 15 min)', async () => {
        const { app } = base;

        const res = await request(app).get('/health').set('X-Forwarded-For', '203.0.113.50');

        expect(res.status).toBe(200);
        // only its own light limiter applies: 60 requests per minute
        expect(res.headers['ratelimit-limit']).toBe('60');
    });

    test('is rate limited per client IP: the 61st request in a minute gets 429 and skips the probes', async () => {
        const { app } = base;
        const ip = '203.0.113.51';

        let last;
        for (let i = 0; i < 60; i++) {
            last = await request(app).get('/health').set('X-Forwarded-For', ip);
            if (last.status !== 200) break;
        }
        expect(last.status).toBe(200);
        fetchSpy.mockClear();
        mockPrisma.$queryRaw.mockClear();

        const blocked = await request(app).get('/health').set('X-Forwarded-For', ip);

        expect(blocked.status).toBe(429);
        expect(blocked.body.status).toBe('error');
        expect(fetchSpy).not.toHaveBeenCalled();
        expect(mockPrisma.$queryRaw).not.toHaveBeenCalled();

        // another client is still served
        const other = await request(app).get('/health').set('X-Forwarded-For', '203.0.113.52');
        expect(other.status).toBe(200);
    });
});

describe('CORS', () => {
    test('exposes the CSV export headers so browser clients can read them', async () => {
        const { app } = base;

        const res = await request(app).get('/').set('Origin', 'http://localhost:3000');

        const exposed = res.headers['access-control-expose-headers'].split(',').map((h) => h.trim());
        expect(exposed).toEqual(expect.arrayContaining(['X-Export-Truncated', 'Content-Disposition']));
    });
});

describe('Swagger UI', () => {
    test('is mounted outside production', async () => {
        const { app } = base; // NODE_ENV=test

        const res = await request(app).get('/api/docs/');

        expect(res.status).toBe(200);
    });

    test('is not mounted in production by default', async () => {
        const { app } = loadServer({ NODE_ENV: 'production', TEST_MODE: 'false' });

        const res = await request(app).get('/api/docs/');

        expect(res.status).toBe(404);
        expect(exitSpy).not.toHaveBeenCalled();
    });

    test('is not mounted in production when ENABLE_SWAGGER is anything but "true"', async () => {
        const { app } = loadServer({ NODE_ENV: 'production', TEST_MODE: 'false', ENABLE_SWAGGER: 'false' });

        const res = await request(app).get('/api/docs/');

        expect(res.status).toBe(404);
    });

    test('is mounted in production when ENABLE_SWAGGER=true', async () => {
        const { app } = loadServer({ NODE_ENV: 'production', TEST_MODE: 'false', ENABLE_SWAGGER: 'true' });

        const res = await request(app).get('/api/docs/');

        expect(res.status).toBe(200);
    });
});

describe('global error handler', () => {
    const leaky = () => new Error('password authentication failed for user "postgres" at db.internal:5432');

    test('a 5xx is generic and Indonesian, whatever NODE_ENV is', async () => {
        const { app } = base;
        mockPrisma.user.findFirst.mockRejectedValue(leaky());

        const res = await request(app)
            .post('/api/v1/auth/login')
            .set('X-Forwarded-For', '198.51.100.20')
            .send({ username: 'budi', password: 'rahasia123' });

        expect(res.status).toBe(500);
        expect(res.body).toEqual({ status: 'error', message: 'Terjadi kesalahan pada server' });
        // the real error is logged, not returned
        expect(errorSpy.mock.calls.flat().join(' ')).toContain('password authentication failed');
    });

    test('an unknown route is still a JSON 404', async () => {
        const { app } = base;

        const res = await request(app).get('/api/v1/tidak-ada');

        expect(res.status).toBe(404);
        expect(res.body.status).toBe('error');
    });

    test('a client error such as malformed JSON keeps its 4xx status', async () => {
        const { app } = base;

        const res = await request(app)
            .post('/api/v1/auth/login')
            .set('Content-Type', 'application/json')
            .send('{"username": ');

        expect(res.status).toBe(400);
        expect(res.body.status).toBe('error');
    });
});

describe('graceful shutdown', () => {
    test('closes Socket.IO and the database, then exits 0', async () => {
        const { io, gracefulShutdown } = loadServer();
        const closeSpy = jest.spyOn(io, 'close').mockResolvedValue(undefined);

        await gracefulShutdown('SIGTERM');

        expect(closeSpy).toHaveBeenCalledTimes(1);
        expect(mockPrisma.$disconnect).toHaveBeenCalledTimes(1);
        expect(exitSpy).toHaveBeenCalledWith(0);
    });

    test('still exits when the database refuses to disconnect', async () => {
        const { io, gracefulShutdown } = loadServer();
        jest.spyOn(io, 'close').mockResolvedValue(undefined);
        mockPrisma.$disconnect.mockRejectedValue(new Error('already closed'));

        await gracefulShutdown('SIGTERM');

        expect(exitSpy).toHaveBeenCalledWith(0);
    });

    test('shuts down once even when signalled twice', async () => {
        const { io, gracefulShutdown } = loadServer();
        const closeSpy = jest.spyOn(io, 'close').mockResolvedValue(undefined);

        await Promise.all([gracefulShutdown('SIGTERM'), gracefulShutdown('SIGINT')]);

        expect(closeSpy).toHaveBeenCalledTimes(1);
        expect(exitSpy).toHaveBeenCalledTimes(1);
    });

    describe('process handlers', () => {
        const register = (registerProcessHandlers) => {
            const handlers = {};
            const onSpy = jest.spyOn(process, 'on').mockImplementation((event, handler) => {
                handlers[event] = handler;
                return process;
            });
            registerProcessHandlers();
            onSpy.mockRestore();
            return handlers;
        };

        test('registers SIGTERM, SIGINT, unhandledRejection and uncaughtException', () => {
            const { registerProcessHandlers } = loadServer();

            const handlers = register(registerProcessHandlers);

            expect(Object.keys(handlers).sort()).toEqual(
                ['SIGINT', 'SIGTERM', 'uncaughtException', 'unhandledRejection'],
            );
        });

        test('an unhandled rejection is logged and triggers a graceful shutdown with exit code 1', async () => {
            const { io, registerProcessHandlers } = loadServer();
            const closeSpy = jest.spyOn(io, 'close').mockResolvedValue(undefined);
            const handlers = register(registerProcessHandlers);

            await handlers.unhandledRejection(new Error('rejected somewhere'));

            expect(errorSpy.mock.calls.flat().join(' ')).toContain('rejected somewhere');
            expect(closeSpy).toHaveBeenCalledTimes(1);
            expect(exitSpy).toHaveBeenCalledWith(1);
        });

        test('an uncaught exception is logged and triggers a graceful shutdown with exit code 1', async () => {
            const { io, registerProcessHandlers } = loadServer();
            const closeSpy = jest.spyOn(io, 'close').mockResolvedValue(undefined);
            const handlers = register(registerProcessHandlers);

            await handlers.uncaughtException(new Error('thrown somewhere'));

            expect(errorSpy.mock.calls.flat().join(' ')).toContain('thrown somewhere');
            expect(closeSpy).toHaveBeenCalledTimes(1);
            expect(exitSpy).toHaveBeenCalledWith(1);
        });

        test('SIGTERM shuts down with exit code 0', async () => {
            const { io, registerProcessHandlers } = loadServer();
            jest.spyOn(io, 'close').mockResolvedValue(undefined);
            const handlers = register(registerProcessHandlers);

            await handlers.SIGTERM();

            expect(exitSpy).toHaveBeenCalledWith(0);
        });
    });
});
