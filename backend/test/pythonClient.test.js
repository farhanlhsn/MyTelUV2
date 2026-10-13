/**
 * Unit Testing - dedicated axios client for the Python AI services (utils/pythonClient.js)
 *
 * Covers the I5 hardening rule: retries are installed on a dedicated axios instance (never on the
 * global one) and only for idempotent reads (GET/HEAD). A POST carries a consumed multipart/form-data
 * stream and may already have been processed by the service, so it is never retried.
 */

const http = require('http');
const axios = require('axios');
const { pythonClient, shouldRetryPythonRequest } = require('../utils/pythonClient');

const networkError = (method, code = 'ECONNRESET') =>
    Object.assign(new Error(code), { code, config: { method } });

const timeoutError = (method) =>
    Object.assign(new Error('timeout of 10000ms exceeded'), { code: 'ECONNABORTED', config: { method } });

const statusError = (method, status) =>
    Object.assign(new Error(`status ${status}`), { config: { method }, response: { status } });

describe('pythonClient - shouldRetryPythonRequest', () => {
    test('never retries a POST, whatever went wrong', () => {
        expect(shouldRetryPythonRequest(networkError('post'))).toBe(false);
        expect(shouldRetryPythonRequest(networkError('post', 'ECONNREFUSED'))).toBe(false);
        expect(shouldRetryPythonRequest(timeoutError('post'))).toBe(false);
        expect(shouldRetryPythonRequest(statusError('post', 503))).toBe(false);
        expect(shouldRetryPythonRequest(statusError('post', 429))).toBe(false);
    });

    test('never retries other non-read methods', () => {
        for (const method of ['put', 'patch', 'delete', 'options']) {
            expect(shouldRetryPythonRequest(networkError(method))).toBe(false);
        }
    });

    test('does not retry when the method is unknown', () => {
        expect(shouldRetryPythonRequest({ code: 'ECONNRESET' })).toBe(false);
        expect(shouldRetryPythonRequest({ code: 'ECONNRESET', config: {} })).toBe(false);
    });

    test('retries a GET after a network error', () => {
        expect(shouldRetryPythonRequest(networkError('get'))).toBe(true);
        expect(shouldRetryPythonRequest(networkError('get', 'ECONNREFUSED'))).toBe(true);
        expect(shouldRetryPythonRequest(networkError('get', 'ETIMEDOUT'))).toBe(true);
    });

    test('retries a HEAD after a network error and the method is case-insensitive', () => {
        expect(shouldRetryPythonRequest(networkError('head'))).toBe(true);
        expect(shouldRetryPythonRequest(networkError('GET'))).toBe(true);
    });

    test('retries a GET that timed out or got a 5xx / 429', () => {
        expect(shouldRetryPythonRequest(timeoutError('get'))).toBe(true);
        expect(shouldRetryPythonRequest(statusError('get', 503))).toBe(true);
        expect(shouldRetryPythonRequest(statusError('get', 429))).toBe(true);
    });

    test('does not retry a GET that the service answered with a client error', () => {
        expect(shouldRetryPythonRequest(statusError('get', 400))).toBe(false);
        expect(shouldRetryPythonRequest(statusError('get', 401))).toBe(false);
        expect(shouldRetryPythonRequest(statusError('get', 404))).toBe(false);
    });

    test('does not retry a cancelled request', () => {
        expect(shouldRetryPythonRequest(networkError('get', 'ERR_CANCELED'))).toBe(false);
    });
});

describe('pythonClient - behaviour against a connection that always resets', () => {
    let server;
    let baseURL;
    let connections;
    let logSpy;

    beforeAll(async () => {
        // utils/pythonClient logs every retry attempt
        logSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
        server = http.createServer((req, res) => res.end('unreachable'));
        server.on('connection', (socket) => {
            connections += 1;
            socket.destroy();
        });
        await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
        baseURL = `http://127.0.0.1:${server.address().port}`;
    });

    afterAll(async () => {
        logSpy.mockRestore();
        await new Promise((resolve) => server.close(resolve));
    });

    beforeEach(() => {
        connections = 0;
    });

    // No back-off delay so the test stays fast
    const noDelay = { 'axios-retry': { retryDelay: () => 0 } };

    test('a POST is sent exactly once', async () => {
        await expect(pythonClient.post(`${baseURL}/detect-face`, 'body', noDelay)).rejects.toMatchObject({
            code: 'ECONNRESET',
        });
        expect(connections).toBe(1);
    });

    test('a GET is retried 3 times (4 attempts in total)', async () => {
        await expect(pythonClient.get(`${baseURL}/health`, noDelay)).rejects.toMatchObject({
            code: 'ECONNRESET',
        });
        expect(connections).toBe(4);
    });

    test('the global axios instance gets no retry behaviour from requiring the client', async () => {
        await expect(axios.get(`${baseURL}/health`)).rejects.toMatchObject({ code: 'ECONNRESET' });
        expect(connections).toBe(1);
        expect(pythonClient).not.toBe(axios);
    });
});
