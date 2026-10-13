/**
 * TEST_MODE swaps real face/plate verification for stubs, so the backend must refuse to boot
 * with it in production.
 *
 *  - shouldRefuseStart is the pure decision, tested for every combination
 *  - one real child process proves server.js actually applies it: the guard sits right after dotenv,
 *    before any route, database client or listener is loaded, so a refusing child exits straight
 *    away with code 1; a child that does not refuse is killed by the timeout and the test fails
 *  - that the guard stays quiet for NODE_ENV=production without TEST_MODE is covered in-process by
 *    server.health.test.js (it loads server.js in production mode and asserts process.exit is not called)
 */
const path = require('path');
const { spawnSync } = require('child_process');
const { shouldRefuseStart } = require('../utils/startupGuard');

const SERVER_FILE = path.resolve(__dirname, '../server.js');

const startServer = (env) =>
    spawnSync(process.execPath, [SERVER_FILE], {
        cwd: path.dirname(SERVER_FILE),
        env: { ...process.env, ...env },
        encoding: 'utf8',
        timeout: 10000,
        killSignal: 'SIGKILL',
    });

describe('shouldRefuseStart', () => {
    test('refuses NODE_ENV=production with TEST_MODE=true', () => {
        expect(shouldRefuseStart({ NODE_ENV: 'production', TEST_MODE: 'true' })).toBe(true);
    });

    test('does not refuse NODE_ENV=production without TEST_MODE', () => {
        expect(shouldRefuseStart({ NODE_ENV: 'production' })).toBe(false);
        expect(shouldRefuseStart({ NODE_ENV: 'production', TEST_MODE: 'false' })).toBe(false);
        expect(shouldRefuseStart({ NODE_ENV: 'production', TEST_MODE: '' })).toBe(false);
    });

    test('does not refuse TEST_MODE=true outside production', () => {
        expect(shouldRefuseStart({ NODE_ENV: 'test', TEST_MODE: 'true' })).toBe(false);
        expect(shouldRefuseStart({ NODE_ENV: 'development', TEST_MODE: 'true' })).toBe(false);
        expect(shouldRefuseStart({ TEST_MODE: 'true' })).toBe(false);
    });

    test('only the exact string "true" counts', () => {
        expect(shouldRefuseStart({ NODE_ENV: 'production', TEST_MODE: 'TRUE' })).toBe(false);
        expect(shouldRefuseStart({ NODE_ENV: 'production', TEST_MODE: '1' })).toBe(false);
    });

    test('reads process.env by default', () => {
        const original = { NODE_ENV: process.env.NODE_ENV, TEST_MODE: process.env.TEST_MODE };
        try {
            process.env.NODE_ENV = 'production';
            process.env.TEST_MODE = 'true';
            expect(shouldRefuseStart()).toBe(true);
        } finally {
            process.env.NODE_ENV = original.NODE_ENV;
            if (original.TEST_MODE === undefined) delete process.env.TEST_MODE;
            else process.env.TEST_MODE = original.TEST_MODE;
        }
    });
});

describe('server startup guard', () => {
    test('exits with code 1 when NODE_ENV=production and TEST_MODE=true', () => {
        const result = startServer({ NODE_ENV: 'production', TEST_MODE: 'true' });

        expect(result.status).toBe(1);
        expect(result.stderr).toContain('TEST_MODE=true is not allowed');
    }, 30000);
});
