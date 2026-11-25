const { pythonServiceHeaders } = require('../utils/pythonServiceHeaders');

describe('pythonServiceHeaders', () => {
    const saved = {};
    const KEYS = ['FACE_API_KEY', 'PLATE_API_KEY', 'ANOMALY_API_KEY'];

    beforeEach(() => {
        KEYS.forEach((k) => {
            saved[k] = process.env[k];
            delete process.env[k];
        });
    });

    afterEach(() => {
        KEYS.forEach((k) => {
            if (saved[k] === undefined) delete process.env[k];
            else process.env[k] = saved[k];
        });
    });

    test.each([
        ['face', 'FACE_API_KEY'],
        ['plate', 'PLATE_API_KEY'],
        ['anomaly', 'ANOMALY_API_KEY'],
    ])('%s service gets X-API-Key from %s', (service, envName) => {
        process.env[envName] = `${service}-key`;

        expect(pythonServiceHeaders(service)['X-API-Key']).toBe(`${service}-key`);
    });

    test('a service only ever gets its own key', () => {
        process.env.FACE_API_KEY = 'face-key';
        process.env.PLATE_API_KEY = 'plate-key';
        process.env.ANOMALY_API_KEY = 'anomaly-key';

        expect(pythonServiceHeaders('anomaly')['X-API-Key']).toBe('anomaly-key');
        expect(pythonServiceHeaders('plate')['X-API-Key']).toBe('plate-key');
    });

    test('keeps the extra headers and cannot be given a different X-API-Key', () => {
        process.env.FACE_API_KEY = 'face-key';

        const headers = pythonServiceHeaders('face', {
            'Content-Type': 'application/json',
            'X-API-Key': 'from-caller',
        });

        expect(headers).toEqual({ 'Content-Type': 'application/json', 'X-API-Key': 'face-key' });
    });

    test('sends an empty X-API-Key when the key is not configured', () => {
        expect(pythonServiceHeaders('face')).toEqual({ 'X-API-Key': '' });
    });

    test('never adds an X-Test-Mode header, even when TEST_MODE=true', () => {
        const originalTestMode = process.env.TEST_MODE;
        process.env.TEST_MODE = 'true';
        try {
            const names = Object.keys(pythonServiceHeaders('plate')).map((h) => h.toLowerCase());
            expect(names).not.toContain('x-test-mode');
        } finally {
            if (originalTestMode === undefined) delete process.env.TEST_MODE;
            else process.env.TEST_MODE = originalTestMode;
        }
    });

    test('rejects an unknown service name', () => {
        expect(() => pythonServiceHeaders('nope')).toThrow('Unknown Python service: nope');
    });
});
