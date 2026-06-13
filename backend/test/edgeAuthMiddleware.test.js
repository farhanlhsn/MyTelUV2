const { protectEdgeDevice } = require('../middlewares/edgeAuthMiddleware');

const createResponse = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

describe('protectEdgeDevice', () => {
    const originalSecret = process.env.EDGE_DEVICE_SECRET;

    afterEach(() => {
        if (originalSecret === undefined) {
            delete process.env.EDGE_DEVICE_SECRET;
        } else {
            process.env.EDGE_DEVICE_SECRET = originalSecret;
        }
    });

    test('allows a device with the configured secret', () => {
        process.env.EDGE_DEVICE_SECRET = 'configured-edge-secret';
        const req = { get: jest.fn().mockReturnValue('configured-edge-secret') };
        const res = createResponse();
        const next = jest.fn();

        protectEdgeDevice(req, res, next);

        expect(next).toHaveBeenCalledTimes(1);
        expect(res.status).not.toHaveBeenCalled();
    });

    test('rejects a device with an invalid secret', () => {
        process.env.EDGE_DEVICE_SECRET = 'configured-edge-secret';
        const req = { get: jest.fn().mockReturnValue('invalid-secret') };
        const res = createResponse();
        const next = jest.fn();

        protectEdgeDevice(req, res, next);

        expect(res.status).toHaveBeenCalledWith(401);
        expect(next).not.toHaveBeenCalled();
    });

    test('fails closed when the server secret is not configured', () => {
        delete process.env.EDGE_DEVICE_SECRET;
        const req = { get: jest.fn().mockReturnValue('any-secret') };
        const res = createResponse();
        const next = jest.fn();

        protectEdgeDevice(req, res, next);

        expect(res.status).toHaveBeenCalledWith(503);
        expect(next).not.toHaveBeenCalled();
    });
});
