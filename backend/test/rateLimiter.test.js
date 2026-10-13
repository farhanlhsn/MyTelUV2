const express = require('express');
const request = require('supertest');
const {
    generalLimiter,
    authLimiter,
    sensitiveLimiter,
    authKeyGenerator
} = require('../middlewares/rateLimiterMiddleware');

// Same value server.js passes to app.set('trust proxy', ...): supertest connects from loopback,
// so a client IP sent in X-Forwarded-For is honoured and becomes req.ip.
const TRUST_PROXY = 'loopback, linklocal, uniquelocal';

// Each test uses its own client IP: the limiters keep counters in module-level memory stores.
let ipCounter = 0;
const freshIp = () => `203.0.113.${++ipCounter}`;

const buildApp = (mountPath, limiter) => {
    const app = express();
    app.set('trust proxy', TRUST_PROXY);
    app.use(express.json());
    app.post(mountPath, limiter, (req, res) => res.status(200).json({ status: 'success' }));
    app.get(mountPath, limiter, (req, res) => res.status(200).json({ status: 'success' }));
    return app;
};

const hit = (app, path, ip, body) => {
    const r = request(app).post(path).set('X-Forwarded-For', ip);
    return body ? r.send(body) : r;
};

describe('authKeyGenerator', () => {
    test('same IP, different usernames => different keys', () => {
        const a = authKeyGenerator({ ip: '203.0.113.7', body: { username: 'budi' } });
        const b = authKeyGenerator({ ip: '203.0.113.7', body: { username: 'sari' } });

        expect(a).not.toBe(b);
    });

    test('is case-insensitive on the username', () => {
        const lower = authKeyGenerator({ ip: '203.0.113.7', body: { username: 'budi' } });
        const mixed = authKeyGenerator({ ip: '203.0.113.7', body: { username: 'BuDi' } });

        expect(mixed).toBe(lower);
    });

    test('different IP, same username => different keys', () => {
        const a = authKeyGenerator({ ip: '203.0.113.7', body: { username: 'budi' } });
        const b = authKeyGenerator({ ip: '203.0.113.8', body: { username: 'budi' } });

        expect(a).not.toBe(b);
    });

    test('key is "<ip>:<lowercased username>"', () => {
        expect(authKeyGenerator({ ip: '203.0.113.7', body: { username: 'BuDi' } })).toBe('203.0.113.7:budi');
    });

    test('tolerates a missing or non-string body username', () => {
        expect(authKeyGenerator({ ip: '203.0.113.7' })).toBe('203.0.113.7:');
        expect(authKeyGenerator({ ip: '203.0.113.7', body: {} })).toBe('203.0.113.7:');
        expect(() => authKeyGenerator({ ip: '203.0.113.7', body: { username: { $ne: null } } })).not.toThrow();
    });

    test('groups IPv6 addresses of one /56 subnet into one key', () => {
        const a = authKeyGenerator({ ip: '2001:db8:abcd:12::1', body: { username: 'budi' } });
        const b = authKeyGenerator({ ip: '2001:db8:abcd:12::ffff', body: { username: 'budi' } });

        expect(a).toBe(b);
    });
});

describe('authLimiter', () => {
    test('allows 5 attempts per IP+username, blocks the 6th with 429 in the JSON envelope', async () => {
        const app = buildApp('/login', authLimiter);
        const ip = freshIp();

        for (let i = 0; i < 5; i++) {
            const res = await hit(app, '/login', ip, { username: 'budi' });
            expect(res.status).toBe(200);
        }

        const blocked = await hit(app, '/login', ip, { username: 'budi' });
        expect(blocked.status).toBe(429);
        expect(blocked.body.status).toBe('error');
        expect(typeof blocked.body.message).toBe('string');
    });

    test('a blocked username does not block another username from the same IP', async () => {
        const app = buildApp('/login', authLimiter);
        const ip = freshIp();

        for (let i = 0; i < 6; i++) await hit(app, '/login', ip, { username: 'budi' });

        const other = await hit(app, '/login', ip, { username: 'sari' });
        expect(other.status).toBe(200);
    });

    test('username case does not create a fresh bucket', async () => {
        const app = buildApp('/login', authLimiter);
        const ip = freshIp();

        for (let i = 0; i < 5; i++) await hit(app, '/login', ip, { username: 'budi' });

        const mixed = await hit(app, '/login', ip, { username: 'BUDI' });
        expect(mixed.status).toBe(429);
    });

    test('the same username from a different client IP is not blocked', async () => {
        const app = buildApp('/login', authLimiter);
        const ipA = freshIp();
        const ipB = freshIp();

        for (let i = 0; i < 6; i++) await hit(app, '/login', ipA, { username: 'budi' });

        const fromB = await hit(app, '/login', ipB, { username: 'budi' });
        expect(fromB.status).toBe(200);
    });
});

describe('sensitiveLimiter', () => {
    test('allows 10 requests per IP, blocks the 11th with 429', async () => {
        const app = buildApp('/refresh', sensitiveLimiter);
        const ip = freshIp();

        for (let i = 0; i < 10; i++) {
            const res = await hit(app, '/refresh', ip, { refresh_token: `t${i}` });
            expect(res.status).toBe(200);
        }

        const blocked = await hit(app, '/refresh', ip, { refresh_token: 't11' });
        expect(blocked.status).toBe(429);
        expect(blocked.body.status).toBe('error');
    });

    test('is keyed by IP only: rotating the request body does not escape it', async () => {
        const app = buildApp('/forgot-password', sensitiveLimiter);
        const ip = freshIp();

        for (let i = 0; i < 10; i++) await hit(app, '/forgot-password', ip, { username: `user${i}` });

        const blocked = await hit(app, '/forgot-password', ip, { username: 'another' });
        expect(blocked.status).toBe(429);
    });

    test('another client IP is unaffected', async () => {
        const app = buildApp('/reset-password', sensitiveLimiter);
        const ipA = freshIp();
        const ipB = freshIp();

        for (let i = 0; i < 11; i++) await hit(app, '/reset-password', ipA, { token: 'x' });

        const fromB = await hit(app, '/reset-password', ipB, { token: 'x' });
        expect(fromB.status).toBe(200);
    });
});

describe('generalLimiter', () => {
    test('allows 300 requests per 15 minutes per IP, blocks the 301st with 429', async () => {
        const app = buildApp('/api/anything', generalLimiter);
        const ip = freshIp();

        let last;
        for (let i = 0; i < 300; i++) {
            last = await request(app).get('/api/anything').set('X-Forwarded-For', ip);
            if (last.status !== 200) break;
        }
        expect(last.status).toBe(200);
        expect(last.headers['ratelimit-limit']).toBe('300');

        const blocked = await request(app).get('/api/anything').set('X-Forwarded-For', ip);
        expect(blocked.status).toBe(429);
        expect(blocked.body.status).toBe('error');
    });

    test('counts per client IP (not the proxy IP): another IP is unaffected', async () => {
        const app = buildApp('/api/anything', generalLimiter);
        const ipA = freshIp();
        const ipB = freshIp();

        await request(app).get('/api/anything').set('X-Forwarded-For', ipA);
        const a = await request(app).get('/api/anything').set('X-Forwarded-For', ipA);
        const b = await request(app).get('/api/anything').set('X-Forwarded-For', ipB);

        expect(a.headers['ratelimit-remaining']).toBe('298');
        expect(b.headers['ratelimit-remaining']).toBe('299');
    });

    test('keys by IP even when an earlier middleware set req.user (it runs before protect in server.js)', async () => {
        const app = express();
        app.set('trust proxy', TRUST_PROXY);
        let nextUser = 1;
        app.use((req, res, next) => { req.user = { id_user: nextUser++ }; next(); });
        app.get('/api/anything', generalLimiter, (req, res) => res.status(200).json({ status: 'success' }));
        const ip = freshIp();

        await request(app).get('/api/anything').set('X-Forwarded-For', ip);
        const second = await request(app).get('/api/anything').set('X-Forwarded-For', ip);

        expect(second.headers['ratelimit-remaining']).toBe('298');
    });

    test('never limits the edge device endpoint', async () => {
        const app = express();
        app.set('trust proxy', TRUST_PROXY);
        app.use('/api', generalLimiter);
        app.get('/api/parkir/edge-entry', (req, res) => res.status(200).json({ status: 'success' }));
        const ip = freshIp();

        const res = await request(app).get('/api/parkir/edge-entry').set('X-Forwarded-For', ip);
        expect(res.status).toBe(200);
        expect(res.headers['ratelimit-limit']).toBeUndefined();
    });
});
