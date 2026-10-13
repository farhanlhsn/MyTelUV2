/**
 * TEST_MODE swaps real face/plate verification for stubs, so the backend must refuse to boot
 * with it in production.
 *
 * server.js is started in a child process on purpose: it listens on a port when loaded, and
 * Jest's transform cannot parse it at all because of duplicate top-level declarations. The guard
 * sits right after dotenv, before any route, database client or listener is loaded, so a refusing
 * child exits straight away; a child that does not refuse is killed by the timeout and the test fails.
 */
const path = require('path');
const { spawnSync } = require('child_process');

const SERVER_FILE = path.resolve(__dirname, '../server.js');

const startServer = (env) =>
    spawnSync(process.execPath, [SERVER_FILE], {
        cwd: path.dirname(SERVER_FILE),
        env: { ...process.env, ...env },
        encoding: 'utf8',
        timeout: 10000,
        killSignal: 'SIGKILL',
    });

describe('server startup guard', () => {
    test('exits with code 1 when NODE_ENV=production and TEST_MODE=true', () => {
        const result = startServer({ NODE_ENV: 'production', TEST_MODE: 'true' });

        expect(result.status).toBe(1);
        expect(result.stderr).toContain('TEST_MODE=true is not allowed');
    }, 30000);
});
