/**
 * Unit Testing - errors that originate in the face service reach the user in Indonesian
 *
 * The real service answers HTTP 400 {success:false, error:'<English text>'} for input problems
 * (no face, several faces, unreadable image). That is a result for the caller, not an outage:
 *  - it is shown as a 400 with an Indonesian message (never the English string),
 *  - it does not count against the circuit breaker (a few face-less photos must not take the
 *    face service offline for everybody).
 * Auth / server failures (401, 5xx, network) still throw, and so do the service's own internal failures
 * ("Error processing image: <exception>" arrives as the same HTTP 400 shape): they are logged, never
 * shown to the user, and count against the circuit breaker.
 */

jest.mock('../utils/prisma', () => ({
    user: { findUnique: jest.fn() },
    dataBiometrik: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        upsert: jest.fn(),
        update: jest.fn(),
    },
}));

jest.mock('../utils/pythonClient', () => ({ pythonClient: { get: jest.fn(), post: jest.fn() } }));

jest.mock('../utils/r2FileHandler', () => ({
    uploadFile: jest.fn().mockResolvedValue({ fileUrl: 'https://example.com/face.jpg' }),
    deleteFile: jest.fn().mockResolvedValue(true),
}));

jest.mock('../utils/auditLogger', () => ({
    logAudit: jest.fn(),
    BIOMETRIK_ACTIONS: { ADD: 'BIOMETRIK_ADD', EDIT: 'BIOMETRIK_EDIT', DELETE: 'BIOMETRIK_DELETE', ABSEN_SUCCESS: 'ABSEN_SUCCESS' },
}));

// A plain constructor (not jest.fn) so jest.resetAllMocks() in beforeEach cannot wipe it.
jest.mock('form-data', () => function FormDataMock() {
    this.append = () => {};
    this.getHeaders = () => ({ 'Content-Type': 'multipart/form-data' });
});

const prisma = require('../utils/prisma');
const { pythonClient } = require('../utils/pythonClient');
const {
    FACE_SERVICE_FALLBACK_MESSAGE,
    FACE_MATCH_FAILED_MESSAGE,
    FACE_SERVICE_FAILURE_MESSAGE,
} = require('../utils/faceServiceMessages');
const {
    addBiometrik,
    editBiometrik,
    verifyWajah,
    scanWajah,
} = require('../controllers/biometrikController');

const createReq = ({ body = {}, params = {}, user = { id_user: 1, role: 'ADMIN' } } = {}) => ({
    file: { buffer: Buffer.from('img'), originalname: 'face.jpg', mimetype: 'image/jpeg' },
    body,
    params,
    user,
    headers: {},
});

const createRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

// What axios throws for a non-2xx answer of the face service
const serviceAnswered = (status, data) => Object.assign(new Error(`Request failed with status code ${status}`), {
    response: { status, data },
});

const NO_FACE = { success: false, error: 'No face detected in image' };

// Everything a console spy received, objects included, as one string
const loggedText = (spy) => spy.mock.calls
    .flat()
    .map((arg) => (typeof arg === 'string' ? arg : JSON.stringify(arg)))
    .join(' ');

let logSpy;
let errorSpy;
let warnSpy;

beforeEach(() => {
    jest.resetAllMocks();
    logSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
    errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
    prisma.dataBiometrik.findMany.mockResolvedValue([]);
});

afterEach(() => {
    logSpy.mockRestore();
    errorSpy.mockRestore();
    warnSpy.mockRestore();
});

describe('addBiometrik', () => {
    beforeEach(() => {
        prisma.user.findUnique.mockResolvedValue({ id_user: 20, nama: 'Mhs 20' });
        prisma.dataBiometrik.findUnique.mockResolvedValue(null);
    });

    test('a 200 {success:false} result is shown in Indonesian', async () => {
        pythonClient.post.mockResolvedValueOnce({ data: NO_FACE });
        const res = createRes();

        await addBiometrik(createReq({ body: { id_user: '20' } }), res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(400);
        const { message } = res.json.mock.calls[0][0];
        expect(message).toMatch(/Wajah tidak terdeteksi/);
        expect(message).not.toMatch(/No face detected/);
    });

    test('an HTTP 400 {success:false} from the service becomes a 400 with an Indonesian message', async () => {
        pythonClient.post.mockRejectedValueOnce(serviceAnswered(400, NO_FACE));
        const res = createRes();
        const next = jest.fn();

        await addBiometrik(createReq({ body: { id_user: '20' } }), res, next);

        expect(next).not.toHaveBeenCalled();
        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith({
            status: 'error',
            message: expect.stringMatching(/Wajah tidak terdeteksi/),
        });
    });

    test('several faces in the photo is reported in Indonesian', async () => {
        pythonClient.post.mockRejectedValueOnce(serviceAnswered(400, {
            success: false,
            error: 'Multiple faces detected (2). Please provide image with single face.',
        }));
        const res = createRes();

        await addBiometrik(createReq({ body: { id_user: '20' } }), res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json.mock.calls[0][0].message).toMatch(/lebih dari satu wajah/);
    });

    test('an unknown service message falls back to the generic Indonesian message', async () => {
        pythonClient.post.mockRejectedValueOnce(serviceAnswered(400, {
            success: false,
            error: 'Some message this backend has no translation for',
        }));
        const res = createRes();

        await addBiometrik(createReq({ body: { id_user: '20' } }), res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith({ status: 'error', message: FACE_SERVICE_FALLBACK_MESSAGE });
    });

    test('a rejected input is logged as a warning with the service text', async () => {
        pythonClient.post.mockRejectedValueOnce(serviceAnswered(400, NO_FACE));

        await addBiometrik(createReq({ body: { id_user: '20' } }), createRes(), jest.fn());

        expect(warnSpy).toHaveBeenCalledWith(
            '[Biometrik] Face service rejected the input:',
            'No face detected in image',
        );
    });

    test('an internal service failure (HTTP 400 "Error processing image: ...") is thrown, not shown', async () => {
        pythonClient.post.mockRejectedValueOnce(serviceAnswered(400, {
            success: false,
            error: 'Error processing image: onnxruntime session crashed',
        }));
        const res = createRes();
        const next = jest.fn();

        await addBiometrik(createReq({ body: { id_user: '20' } }), res, next);

        expect(res.status).not.toHaveBeenCalled();
        expect(res.json).not.toHaveBeenCalled();
        expect(next).toHaveBeenCalledWith(expect.objectContaining({ message: FACE_SERVICE_FAILURE_MESSAGE }));
        // the real cause is logged server side, and not as a harmless rejected input
        expect(loggedText(errorSpy)).toContain('onnxruntime session crashed');
        expect(warnSpy).not.toHaveBeenCalledWith(
            '[Biometrik] Face service rejected the input:',
            expect.anything(),
        );
    });

    test('face-less photos never open the circuit breaker', async () => {
        // The breaker opens after 5 consecutive failures (FACE_CB_FAILURE_THRESHOLD default)
        for (let attempt = 0; attempt < 7; attempt += 1) {
            pythonClient.post.mockRejectedValueOnce(serviceAnswered(400, NO_FACE));
            const res = createRes();
            const next = jest.fn();

            await addBiometrik(createReq({ body: { id_user: '20' } }), res, next);

            expect(next).not.toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json.mock.calls[0][0].message).toMatch(/Wajah tidak terdeteksi/);
        }
    });

    test('a 401 from the service (wrong API key) is not shown as a user error', async () => {
        pythonClient.post.mockRejectedValueOnce(serviceAnswered(401, { success: false, error: 'Unauthorized' }));
        const res = createRes();
        const next = jest.fn();

        await addBiometrik(createReq({ body: { id_user: '20' } }), res, next);

        expect(res.status).not.toHaveBeenCalled();
        expect(next).toHaveBeenCalledWith(expect.any(Error));
    });
});

describe('editBiometrik', () => {
    test('an HTTP 400 {success:false} from the service becomes a 400 with an Indonesian message', async () => {
        prisma.dataBiometrik.findUnique.mockResolvedValue({ id_biometrik: 7, id_user: 20, deletedAt: null });
        pythonClient.post.mockRejectedValueOnce(serviceAnswered(400, {
            success: false,
            error: 'Failed to decode image',
        }));
        const res = createRes();

        await editBiometrik(createReq({ params: { id_user: '20' } }), res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith({
            status: 'error',
            message: expect.stringMatching(/Foto tidak dapat dibaca/),
        });
    });
});

describe('verifyWajah', () => {
    test('a failed detection is shown in Indonesian', async () => {
        pythonClient.post.mockResolvedValueOnce({ data: NO_FACE });
        const res = createRes();

        await verifyWajah(createReq(), res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json.mock.calls[0][0].message).toMatch(/Wajah tidak terdeteksi/);
    });

    test('a find-match error never carries the English service text', async () => {
        prisma.dataBiometrik.findMany.mockResolvedValue([
            { id_user: 10, face_embedding: [1, 0, 0], user: { id_user: 10, nama: 'A', username: 'a', role: 'MAHASISWA' } },
        ]);
        pythonClient.post
            .mockResolvedValueOnce({ data: { success: true, embedding: [1, 0, 0] } })
            .mockResolvedValueOnce({ data: { error: 'Error finding best match: shapes differ' } });
        const res = createRes();
        const next = jest.fn();

        await verifyWajah(createReq(), res, next);

        expect(res.status).not.toHaveBeenCalled();
        expect(next).toHaveBeenCalledWith(expect.objectContaining({ message: FACE_MATCH_FAILED_MESSAGE }));
        expect(next.mock.calls[0][0].message).not.toMatch(/best match|shapes/);
        expect(loggedText(errorSpy)).toContain('Error finding best match: shapes differ');
    });
});

describe('circuit breaker', () => {
    // The breaker lives in the controller module, so these tests load their own copy of the controller
    // (and of the mocked client it talks to): tripping it must not affect the other tests.
    const loadIsolatedController = () => {
        let controller;
        let client;
        jest.isolateModules(() => {
            client = require('../utils/pythonClient').pythonClient;
            controller = require('../controllers/biometrikController');
        });
        return { controller, client };
    };

    test('internal service failures count against the breaker; it opens after 5 and stops calling the service', async () => {
        const { controller, client } = loadIsolatedController();

        for (let attempt = 0; attempt < 5; attempt += 1) {
            client.post.mockRejectedValueOnce(serviceAnswered(400, {
                success: false,
                error: 'Error processing image: model crashed',
            }));
            const next = jest.fn();
            await controller.scanWajah(createReq(), createRes(), next);
            expect(next).toHaveBeenCalledWith(expect.objectContaining({ message: FACE_SERVICE_FAILURE_MESSAGE }));
        }
        expect(client.post).toHaveBeenCalledTimes(5);

        // 6th request: the circuit is open, the service is not called at all
        const res = createRes();
        const next = jest.fn();
        await controller.scanWajah(createReq(), res, next);

        expect(client.post).toHaveBeenCalledTimes(5);
        expect(res.status).not.toHaveBeenCalled();
        expect(next).toHaveBeenCalledWith(expect.objectContaining({
            message: expect.stringMatching(/offline secara protektif/),
        }));
    });

    test('input rejections never open the breaker', async () => {
        const { controller, client } = loadIsolatedController();

        for (let attempt = 0; attempt < 8; attempt += 1) {
            client.post.mockRejectedValueOnce(serviceAnswered(400, NO_FACE));
            const res = createRes();
            await controller.scanWajah(createReq(), res, jest.fn());
            expect(res.status).toHaveBeenCalledWith(400);
        }
        expect(client.post).toHaveBeenCalledTimes(8);
    });
});

describe('scanWajah', () => {
    test('no faces in the photo is shown in Indonesian', async () => {
        pythonClient.post.mockRejectedValueOnce(serviceAnswered(400, {
            success: false,
            error: 'No faces detected in image',
        }));
        const res = createRes();

        await scanWajah(createReq(), res, jest.fn());

        expect(res.status).toHaveBeenCalledWith(400);
        const { message } = res.json.mock.calls[0][0];
        expect(message).toMatch(/Tidak ada wajah/);
        expect(message).not.toMatch(/No faces detected/);
    });
});
