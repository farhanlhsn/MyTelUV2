/**
 * Unit Testing - Parkir Controller
 * 
 * @author MyTelUV2 Team
 * @date 2026-01-04
 */

// Mock dependencies
jest.mock('../utils/prisma', () => ({
    kendaraan: { findMany: jest.fn(), findFirst: jest.fn() },
    logParkir: { count: jest.fn(), findMany: jest.fn(), findFirst: jest.fn(), create: jest.fn(), update: jest.fn() },
    parkiran: { findUnique: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
    $queryRaw: jest.fn(),
    $executeRaw: jest.fn(),
    $executeRawUnsafe: jest.fn(),
    $transaction: jest.fn(),
}));

jest.mock('../utils/r2FileHandler', () => ({
    uploadFile: jest.fn(),
}));

jest.mock('../utils/firebase', () => ({
    sendParkingNotification: jest.fn().mockResolvedValue(true),
}));

jest.mock('../utils/auditLogger', () => ({
    logAudit: jest.fn(),
}));

// Python AI service calls go through the dedicated client (utils/pythonClient), not the global axios
jest.mock('../utils/pythonClient', () => ({ pythonClient: { get: jest.fn(), post: jest.fn() } }));

// Import modules
const { pythonClient } = require('../utils/pythonClient');
const prisma = require('../utils/prisma');
const { uploadFile } = require('../utils/r2FileHandler');
const { sendParkingNotification } = require('../utils/firebase');
const { logAudit } = require('../utils/auditLogger');
const parkirController = require('../controllers/parkirController');

// The controller logs every edge request ([Edge Entry], [Face Upload]); keep the test output clean
let consoleLogSpy;
beforeEach(() => {
    consoleLogSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
});
afterEach(() => {
    consoleLogSpy.mockRestore();
});

// Helper functions
const createMockReq = (body = {}, headers = {}, file = null) => ({
    body,
    headers,
    file,
    user: { id_user: 1 }, // Default user for other endpoints
    query: {},
    params: {},
    app: {
        get: jest.fn().mockReturnValue(null) // Mock Socket.io getter
    }
});

const createMockRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

// Transaction client handed to interactive $transaction callbacks (prisma.$transaction(async (tx) => ...)).
const tx = {
    $queryRaw: jest.fn(),
    $executeRaw: jest.fn(),
    logParkir: { findFirst: jest.fn(), create: jest.fn() },
};

const resetEdgeMocks = () => {
    jest.clearAllMocks();
    prisma.kendaraan.findFirst.mockReset();
    prisma.$queryRaw.mockReset();
    prisma.$executeRaw.mockReset();
    prisma.logParkir.findFirst.mockReset();
    prisma.logParkir.create.mockReset();
    tx.$queryRaw.mockReset().mockResolvedValue([{ id_kendaraan: 1 }]); // the FOR UPDATE row lock
    tx.$executeRaw.mockReset();
    tx.logParkir.findFirst.mockReset();
    tx.logParkir.create.mockReset();
    prisma.$transaction.mockReset().mockImplementation(async (callback) => callback(tx));
    process.env.EDGE_DEVICE_SECRET = 'secret123';
};

const parkiranRow = (overrides = {}) => ({
    id_parkiran: 1,
    nama_parkiran: 'Gedung A',
    kapasitas: 100,
    live_kapasitas: 50,
    ...overrides
});

const kendaraanRow = (overrides = {}) => ({
    id_kendaraan: 1,
    plat_nomor: 'D1234ABC',
    nama_kendaraan: 'Beat',
    user: { id_user: 1, nama: 'User', deletedAt: null },
    ...overrides
});

// In-memory stand-in for the database as seen from inside a transaction. It models the row lock the controller
// takes (SELECT ... FOR UPDATE on the kendaraan row): transactions run one after another, and each one sees what
// the previous one committed. Lets a test fire two requests "at the same time".
const installLockingTransactions = ({ live, logs = [] }) => {
    let liveValue = live;
    let queue = Promise.resolve();
    const store = {
        logs: logs.map((log, i) => ({ id_log_parkir: i + 1, ...log })),
        live: () => liveValue
    };
    const lockedTx = {
        $queryRaw: jest.fn().mockResolvedValue([{ id_kendaraan: 1 }]),
        $executeRaw: jest.fn(async (strings) => {
            liveValue = /live_kapasitas \+ 1/.test(strings.join('?')) ? liveValue + 1 : Math.max(0, liveValue - 1);
            return 1;
        }),
        logParkir: {
            findFirst: jest.fn(async ({ where }) => {
                const match = [...store.logs].reverse().find((log) =>
                    log.id_kendaraan === where.id_kendaraan
                    && (where.id_parkiran === undefined || log.id_parkiran === where.id_parkiran));
                return match || null;
            }),
            create: jest.fn(async ({ data }) => {
                const row = { id_log_parkir: store.logs.length + 1, ...data };
                store.logs.push(row);
                return row;
            })
        }
    };
    prisma.$transaction.mockImplementation((callback) => {
        const run = queue.then(() => callback(lockedTx));
        queue = run.catch(() => {});
        return run;
    });
    return store;
};

describe('Parkir Controller - processEdgeEntry', () => {

    beforeEach(resetEdgeMocks);

    const validHeaders = { 'x-edge-secret': 'secret123' };
    const validBody = {
        plate_text: 'D 1234 ABC',
        parkiran_id: '1',
        gate_type: 'MASUK'
    };

    /**
     * AUTH & VALIDATION
     */
    test('should Deny if secret is invalid', async () => {
        const req = createMockReq(validBody, { 'x-edge-secret': 'wrong' });
        const res = createMockRes();
        await parkirController.processEdgeEntry(req, res);
        expect(res.status).toHaveBeenCalledWith(401);
    });

    test('should Deny if fields missing', async () => {
        const req = createMockReq({}, validHeaders);
        const res = createMockRes();
        await parkirController.processEdgeEntry(req, res);
        expect(res.status).toHaveBeenCalledWith(400);
    });

    /**
     * PLATE LOOKUP
     */
    describe('plate lookup', () => {
        test('looks the vehicle up by the normalised plate (all non-alphanumerics removed)', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(null);
            const req = createMockReq({ ...validBody, plate_text: 'd-1234/abc.' }, validHeaders);

            await parkirController.processEdgeEntry(req, createMockRes());

            expect(prisma.kendaraan.findFirst).toHaveBeenCalledWith(expect.objectContaining({
                where: { plat_nomor: 'D1234ABC', statusVerif: true, deletedAt: null }
            }));
        });

        test('also selects the owner deletedAt so a deactivated account can be refused', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(null);

            await parkirController.processEdgeEntry(createMockReq(validBody, validHeaders), createMockRes());

            expect(prisma.kendaraan.findFirst).toHaveBeenCalledWith(expect.objectContaining({
                include: { user: { select: expect.objectContaining({ deletedAt: true }) } }
            }));
        });

        describe('owner account deactivated', () => {
            const deactivatedOwnerVehicle = () => kendaraanRow({
                user: { id_user: 1, nama: 'User', deletedAt: new Date('2026-09-01T00:00:00Z') }
            });

            test('denies MASUK with 403 and writes a PARKIR_PEMILIK_NONAKTIF audit entry', async () => {
                prisma.kendaraan.findFirst.mockResolvedValue(deactivatedOwnerVehicle());
                const req = createMockReq(validBody, validHeaders);
                req.ip = '10.0.0.7';
                const res = createMockRes();

                await parkirController.processEdgeEntry(req, res);

                expect(res.status).toHaveBeenCalledWith(403);
                expect(res.json).toHaveBeenCalledWith({
                    status: 'error',
                    message: 'Akun pemilik kendaraan tidak aktif',
                    data: { gate_action: 'DENY' }
                });
                expect(logAudit).toHaveBeenCalledTimes(1);
                expect(logAudit).toHaveBeenCalledWith({
                    action: 'PARKIR_PEMILIK_NONAKTIF',
                    performedBy: null,
                    targetUserId: 1,
                    details: 'Plat D1234ABC ditolak masuk di parkiran 1: akun pemilik tidak aktif',
                    ip: '10.0.0.7'
                });
                expect(prisma.$transaction).not.toHaveBeenCalled();
                expect(sendParkingNotification).not.toHaveBeenCalled();
            });

            test('lets the car leave on KELUAR when it is inside: exit logged, capacity decremented', async () => {
                prisma.kendaraan.findFirst.mockResolvedValue(deactivatedOwnerVehicle());
                prisma.$queryRaw.mockResolvedValueOnce([parkiranRow({ live_kapasitas: 10 })]);
                tx.logParkir.findFirst.mockResolvedValue({ type: 'MASUK' });
                tx.logParkir.create.mockResolvedValue({ id_log_parkir: 101 });
                tx.$executeRaw.mockResolvedValue(1);
                const res = createMockRes();

                await parkirController.processEdgeEntry(createMockReq({ ...validBody, gate_type: 'KELUAR' }, validHeaders), res);

                expect(res.status).toHaveBeenCalledWith(200);
                expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                    status: 'success',
                    data: expect.objectContaining({ gate_action: 'OPEN' })
                }));
                expect(tx.logParkir.create).toHaveBeenCalledWith({
                    data: expect.objectContaining({ id_kendaraan: 1, id_parkiran: 1, type: 'KELUAR' })
                });
                expect(tx.$executeRaw).toHaveBeenCalledTimes(1);
                expect(tx.$executeRaw.mock.calls[0][0].join('')).toMatch(/live_kapasitas - 1/);
                expect(logAudit).not.toHaveBeenCalled();
            });

            test('a KELUAR for a car that is not inside is still denied by the normal exit rule', async () => {
                prisma.kendaraan.findFirst.mockResolvedValue(deactivatedOwnerVehicle());
                prisma.$queryRaw.mockResolvedValueOnce([parkiranRow()]);
                tx.logParkir.findFirst.mockResolvedValue({ type: 'KELUAR' });
                const res = createMockRes();

                await parkirController.processEdgeEntry(createMockReq({ ...validBody, gate_type: 'KELUAR' }, validHeaders), res);

                expect(res.status).toHaveBeenCalledWith(400);
                expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ data: { gate_action: 'DENY' } }));
                expect(tx.logParkir.create).not.toHaveBeenCalled();
                expect(tx.$executeRaw).not.toHaveBeenCalled();
            });
        });

        test('writes a PARKIR_PLAT_TIDAK_DIKENAL audit entry with the plate and parkiran id for an unknown plate', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(null);
            const req = createMockReq({ plate_text: 'x 99-zz', parkiran_id: '3', gate_type: 'MASUK' }, validHeaders);
            req.ip = '10.0.0.7';
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(logAudit).toHaveBeenCalledTimes(1);
            expect(logAudit).toHaveBeenCalledWith(expect.objectContaining({
                action: 'PARKIR_PLAT_TIDAK_DIKENAL',
                performedBy: null,
                details: 'Plat X99ZZ tidak dikenal di parkiran 3 (gate MASUK)',
                ip: '10.0.0.7'
            }));
            expect(res.status).toHaveBeenCalledWith(404);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                data: { gate_action: 'DENY' }
            }));
        });

        test('does not audit a recognised plate', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(kendaraanRow());
            prisma.$queryRaw.mockResolvedValueOnce([parkiranRow()]);
            tx.logParkir.findFirst.mockResolvedValue(null);
            tx.$executeRaw.mockResolvedValue(1);
            tx.logParkir.create.mockResolvedValue({ id_log_parkir: 1 });

            await parkirController.processEdgeEntry(createMockReq(validBody, validHeaders), createMockRes());

            expect(logAudit).not.toHaveBeenCalled();
        });
    });

    /**
     * ENTRY (MASUK) SCENARIOS
     */
    describe('Gate MASUK', () => {

        test('should Allow Entry if valid and not full', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(kendaraanRow());
            prisma.$queryRaw.mockResolvedValueOnce([parkiranRow()]);
            tx.logParkir.findFirst.mockResolvedValue(null); // not inside
            tx.$executeRaw.mockResolvedValue(1); // atomic capacity update
            tx.logParkir.create.mockResolvedValue({ id_log_parkir: 100 });
            uploadFile.mockResolvedValue({ fileUrl: 'http://img.com' });

            const req = createMockReq(validBody, validHeaders, { buffer: 'buf', originalname: 'a.jpg' });
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(prisma.$transaction).toHaveBeenCalledTimes(1);
            expect(typeof prisma.$transaction.mock.calls[0][0]).toBe('function'); // interactive transaction
            expect(tx.$executeRaw).toHaveBeenCalledTimes(1);
            expect(tx.logParkir.create).toHaveBeenCalledWith({
                data: expect.objectContaining({ id_kendaraan: 1, id_parkiran: 1, id_user: 1, type: 'MASUK' })
            });
            // nothing of the entry runs outside the transaction
            expect(prisma.$executeRaw).not.toHaveBeenCalled();
            expect(prisma.logParkir.create).not.toHaveBeenCalled();
            expect(sendParkingNotification).toHaveBeenCalledWith(1, 'MASUK', expect.anything(), 'Gedung A');
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                data: expect.objectContaining({
                    gate_action: 'OPEN'
                })
            }));
        });

        test('locks the vehicle row first, then re-reads the last log inside the transaction', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(kendaraanRow());
            prisma.$queryRaw.mockResolvedValueOnce([parkiranRow()]);
            tx.logParkir.findFirst.mockResolvedValue(null);
            tx.$executeRaw.mockResolvedValue(1);
            tx.logParkir.create.mockResolvedValue({ id_log_parkir: 100 });

            await parkirController.processEdgeEntry(createMockReq(validBody, validHeaders), createMockRes());

            expect(tx.$queryRaw).toHaveBeenCalledTimes(1);
            expect(tx.$queryRaw.mock.calls[0][0].join('')).toMatch(/FROM kendaraan[\s\S]*FOR UPDATE/);
            expect(tx.$queryRaw.mock.calls[0][1]).toBe(1);
            expect(tx.logParkir.findFirst).toHaveBeenCalledWith(expect.objectContaining({
                where: { id_kendaraan: 1 }
            }));
            // lock -> re-read -> capacity update -> create log
            const order = [
                tx.$queryRaw.mock.invocationCallOrder[0],
                tx.logParkir.findFirst.mock.invocationCallOrder[0],
                tx.$executeRaw.mock.invocationCallOrder[0],
                tx.logParkir.create.mock.invocationCallOrder[0]
            ];
            expect(order).toEqual([...order].sort((a, b) => a - b));
            // the unlocked read outside the transaction is gone
            expect(prisma.logParkir.findFirst).not.toHaveBeenCalled();
        });

        test('should Deny Entry if Parking Full', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(kendaraanRow());
            prisma.$queryRaw.mockResolvedValueOnce([parkiranRow({ live_kapasitas: 100 })]); // FULL
            tx.logParkir.findFirst.mockResolvedValue(null);
            tx.$executeRaw.mockResolvedValue(0); // conditional capacity update matched no row

            const req = createMockReq(validBody, validHeaders);
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                data: expect.objectContaining({
                    gate_action: 'DENY'
                }),
                message: expect.stringContaining('penuh')
            }));
            expect(tx.logParkir.create).not.toHaveBeenCalled();
            expect(sendParkingNotification).not.toHaveBeenCalled();
        });

        test('should Deny Entry if Already Inside', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(kendaraanRow());
            prisma.$queryRaw.mockResolvedValueOnce([parkiranRow()]);

            // Last log was entry -> car is inside
            tx.logParkir.findFirst.mockResolvedValue({ type: 'MASUK' });

            const req = createMockReq(validBody, validHeaders);
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                data: expect.objectContaining({
                    gate_action: 'DENY'
                }),
                message: expect.stringContaining('sudah berada di dalam')
            }));
            expect(tx.$executeRaw).not.toHaveBeenCalled(); // capacity untouched
            expect(tx.logParkir.create).not.toHaveBeenCalled();
            expect(sendParkingNotification).not.toHaveBeenCalled();
        });

        test('should Deny if Vehicle Not Found', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(null);
            const req = createMockReq(validBody, validHeaders);
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);
            expect(res.status).toHaveBeenCalledWith(404);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                data: expect.objectContaining({
                    gate_action: 'DENY'
                }),
                message: expect.stringContaining('tidak terdaftar')
            }));
        });

        test('two simultaneous entries of the same vehicle produce exactly one entry', async () => {
            const store = installLockingTransactions({ live: 50 });
            prisma.kendaraan.findFirst.mockResolvedValue(kendaraanRow());
            prisma.$queryRaw.mockResolvedValue([parkiranRow()]);
            // Both requests read "not inside" outside the transaction, before either has committed.
            prisma.logParkir.findFirst.mockResolvedValue(null);
            const resA = createMockRes();
            const resB = createMockRes();

            await Promise.all([
                parkirController.processEdgeEntry(createMockReq(validBody, validHeaders), resA),
                parkirController.processEdgeEntry(createMockReq(validBody, validHeaders), resB)
            ]);

            const statuses = [resA, resB].map((r) => r.status.mock.calls[0][0]).sort();
            expect(statuses).toEqual([200, 400]);
            expect(store.logs).toHaveLength(1);
            expect(store.live()).toBe(51);
            expect(sendParkingNotification).toHaveBeenCalledTimes(1);
        });
    });

    /**
     * EXIT (KELUAR) SCENARIOS
     */
    describe('Gate KELUAR', () => {
        const exitBody = { ...validBody, gate_type: 'KELUAR' };

        test('should Allow Exit if vehicle is inside', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(kendaraanRow());
            prisma.$queryRaw.mockResolvedValueOnce([parkiranRow({ live_kapasitas: 10 })]);

            // Last log was MASUK -> car is inside
            tx.logParkir.findFirst.mockResolvedValue({ type: 'MASUK' });
            tx.logParkir.create.mockResolvedValue({ id_log_parkir: 101 });
            tx.$executeRaw.mockResolvedValue(1);

            const req = createMockReq(exitBody, validHeaders);
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(typeof prisma.$transaction.mock.calls[0][0]).toBe('function'); // interactive transaction
            expect(tx.$queryRaw.mock.calls[0][0].join('')).toMatch(/FOR UPDATE/);
            expect(tx.logParkir.findFirst).toHaveBeenCalledWith(expect.objectContaining({
                where: { id_kendaraan: 1, id_parkiran: 1 }
            }));
            expect(tx.logParkir.create).toHaveBeenCalledWith({
                data: expect.objectContaining({ id_kendaraan: 1, id_parkiran: 1, type: 'KELUAR' })
            });
            expect(tx.$executeRaw).toHaveBeenCalledTimes(1); // decrement, same transaction
            expect(prisma.$executeRaw).not.toHaveBeenCalled();
            expect(prisma.logParkir.create).not.toHaveBeenCalled();
            expect(sendParkingNotification).toHaveBeenCalledWith(1, 'KELUAR', expect.anything(), 'Gedung A');
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                data: expect.objectContaining({
                    gate_action: 'OPEN'
                })
            }));
        });

        test('should Deny Exit if vehicle not inside', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(kendaraanRow());
            prisma.$queryRaw.mockResolvedValueOnce([parkiranRow()]);

            // Last log was KELUAR or null -> car is outside
            tx.logParkir.findFirst.mockResolvedValue({ type: 'KELUAR' });

            const req = createMockReq(exitBody, validHeaders);
            const res = createMockRes();

            await parkirController.processEdgeEntry(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                data: expect.objectContaining({
                    gate_action: 'DENY'
                })
            }));
            expect(tx.logParkir.create).not.toHaveBeenCalled();
            expect(tx.$executeRaw).not.toHaveBeenCalled();
            expect(sendParkingNotification).not.toHaveBeenCalled();
        });

        test('should Deny Exit if the vehicle has no log in this parkiran', async () => {
            prisma.kendaraan.findFirst.mockResolvedValue(kendaraanRow());
            prisma.$queryRaw.mockResolvedValueOnce([parkiranRow()]);
            tx.logParkir.findFirst.mockResolvedValue(null);

            const res = createMockRes();
            await parkirController.processEdgeEntry(createMockReq(exitBody, validHeaders), res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(tx.logParkir.create).not.toHaveBeenCalled();
        });

        test('two simultaneous exits of the same vehicle produce exactly one exit', async () => {
            const store = installLockingTransactions({
                live: 10,
                logs: [{ id_kendaraan: 1, id_parkiran: 1, type: 'MASUK' }]
            });
            prisma.kendaraan.findFirst.mockResolvedValue(kendaraanRow());
            prisma.$queryRaw.mockResolvedValue([parkiranRow({ live_kapasitas: 10 })]);
            const resA = createMockRes();
            const resB = createMockRes();

            await Promise.all([
                parkirController.processEdgeEntry(createMockReq(exitBody, validHeaders), resA),
                parkirController.processEdgeEntry(createMockReq(exitBody, validHeaders), resB)
            ]);

            const statuses = [resA, resB].map((r) => r.status.mock.calls[0][0]).sort();
            expect(statuses).toEqual([200, 400]);
            expect(store.logs.filter((log) => log.type === 'KELUAR')).toHaveLength(1);
            expect(store.live()).toBe(9);
            expect(sendParkingNotification).toHaveBeenCalledTimes(1);
        });
    });
});

describe('Parkir Controller - create/update parkiran validation', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('should reject createParkiran if kapasitas is not numeric', async () => {
        const req = createMockReq({
            nama_parkiran: 'Gedung A',
            kapasitas: 'NaN',
            latitude: '-6.2',
            longitude: '106.8'
        });
        const res = createMockRes();

        await parkirController.createParkiran(req, res);

        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
            status: 'error',
            message: expect.stringContaining('Kapasitas')
        }));
        expect(prisma.$executeRaw).not.toHaveBeenCalled();
    });

    test('should reject updateParkiran if id is not numeric', async () => {
        const req = createMockReq({ nama_parkiran: 'Gedung B' });
        req.params = { id: 'abc' };
        const res = createMockRes();

        await parkirController.updateParkiran(req, res);

        expect(res.status).toHaveBeenCalledWith(400);
        expect(prisma.parkiran.findFirst).not.toHaveBeenCalled();
        expect(prisma.$executeRawUnsafe).not.toHaveBeenCalled();
    });

    test('should reject updateParkiran if longitude is out of range', async () => {
        prisma.parkiran.findFirst.mockResolvedValueOnce({ id_parkiran: 1 });

        const req = createMockReq({
            latitude: '-6.2',
            longitude: '181'
        });
        req.params = { id: '1' };
        const res = createMockRes();

        await parkirController.updateParkiran(req, res);

        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
            status: 'error',
            message: expect.stringContaining('Longitude')
        }));
        expect(prisma.$transaction).not.toHaveBeenCalled();
        expect(prisma.$executeRawUnsafe).not.toHaveBeenCalled();
    });

    test('should update parkiran without unsafe raw SQL', async () => {
        prisma.parkiran.findFirst
            .mockResolvedValueOnce({ id_parkiran: 1 })
            .mockResolvedValueOnce(null);
        prisma.parkiran.update.mockResolvedValue({ id_parkiran: 1 });
        prisma.$executeRaw.mockResolvedValue(1);
        prisma.$transaction.mockImplementation(async operations => Promise.all(operations));
        prisma.$queryRaw.mockResolvedValue([{
            id_parkiran: 1,
            nama_parkiran: 'Gedung Baru',
            kapasitas: 50,
            live_kapasitas: 0
        }]);

        const req = createMockReq({
            nama_parkiran: 'Gedung Baru',
            kapasitas: '50',
            latitude: '-6.2',
            longitude: '106.8'
        });
        req.params = { id: '1' };
        const res = createMockRes();

        await parkirController.updateParkiran(req, res);

        expect(prisma.parkiran.update).toHaveBeenCalledWith(expect.objectContaining({
            where: { id_parkiran: 1 },
            data: {
                nama_parkiran: 'Gedung Baru',
                kapasitas: 50
            }
        }));
        expect(prisma.$executeRaw).toHaveBeenCalled();
        expect(prisma.$executeRawUnsafe).not.toHaveBeenCalled();
        expect(res.status).toHaveBeenCalledWith(200);
    });
});

describe('Parkir Controller - exportParkirLogs & manualOverride', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    describe('exportParkirLogs', () => {
        test('should export CSV successfully if logs exist', async () => {
            const mockLogs = [
                {
                    id_log_parkir: 1,
                    timestamp: new Date('2026-05-18T10:00:00Z'),
                    type: 'MASUK',
                    confidence: 0.95,
                    image_url: 'http://img.com/1.jpg',
                    face_image_url: 'http://img.com/face1.jpg',
                    kendaraan: { plat_nomor: 'D1234ABC', nama_kendaraan: 'Mobil Honda' },
                    user: { nama: 'Farhan', username: 'farhan' },
                    parkiran: { nama_parkiran: 'Gedung A' }
                }
            ];

            prisma.logParkir.findMany.mockResolvedValue(mockLogs);

            const req = createMockReq();
            req.query = { parkiran_id: '1', from: '2026-05-01', to: '2026-05-31' };
            
            const res = {
                status: jest.fn().mockReturnThis(),
                setHeader: jest.fn(),
                send: jest.fn()
            };

            await parkirController.exportParkirLogs(req, res);

            expect(prisma.logParkir.findMany).toHaveBeenCalledWith(expect.objectContaining({
                where: expect.objectContaining({
                    id_parkiran: 1,
                    timestamp: expect.objectContaining({
                        gte: expect.any(Date),
                        lte: expect.any(Date)
                    })
                })
            }));
            expect(res.setHeader).toHaveBeenCalledWith('Content-Type', 'text/csv; charset=utf-8');
            expect(res.setHeader).toHaveBeenCalledWith('Content-Disposition', expect.stringContaining('attachment; filename='));
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.send).toHaveBeenCalledWith(expect.stringContaining('"ID Log","Timestamp","Tipe","Plat Nomor","Kendaraan","User","Username","Parkiran"'));
        });

        test('should return 404 if no logs found', async () => {
            prisma.logParkir.findMany.mockResolvedValue([]);

            const req = createMockReq();
            const res = createMockRes();

            await parkirController.exportParkirLogs(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                message: expect.stringContaining('Tidak ada data')
            }));
        });

        const csvRow = (id) => ({
            id_log_parkir: id,
            timestamp: new Date('2026-05-18T10:00:00Z'),
            type: 'MASUK',
            confidence: null,
            image_url: null,
            face_image_url: null,
            kendaraan: { plat_nomor: 'D1234ABC', nama_kendaraan: 'Beat' },
            user: { nama: 'Farhan', username: 'farhan' },
            parkiran: { nama_parkiran: 'Gedung A' }
        });

        const csvRes = () => ({ status: jest.fn().mockReturnThis(), setHeader: jest.fn(), send: jest.fn(), json: jest.fn() });

        test('caps the export at 10,000 rows even without a date filter', async () => {
            prisma.logParkir.findMany.mockResolvedValue([csvRow(1)]);
            const req = createMockReq();
            req.query = {};

            await parkirController.exportParkirLogs(req, csvRes());

            expect(prisma.logParkir.findMany).toHaveBeenCalledWith(expect.objectContaining({
                take: 10001, // one more than the cap, to know whether anything was left out
                orderBy: { timestamp: 'desc' }
            }));
        });

        const plateCount = (csv) => csv.split('"D1234ABC"').length - 1;

        test('exactly 10,000 matching rows are exported in full and not flagged as truncated', async () => {
            prisma.logParkir.findMany.mockResolvedValue(Array.from({ length: 10000 }, (_, i) => csvRow(i + 1)));
            const req = createMockReq();
            req.query = {};
            const res = csvRes();

            await parkirController.exportParkirLogs(req, res);

            expect(res.setHeader).not.toHaveBeenCalledWith('X-Export-Truncated', expect.anything());
            expect(plateCount(res.send.mock.calls[0][0])).toBe(10000);
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('a 10,001st row exports only 10,000 rows and sets X-Export-Truncated', async () => {
            prisma.logParkir.findMany.mockResolvedValue(Array.from({ length: 10001 }, (_, i) => csvRow(i + 1)));
            const req = createMockReq();
            req.query = {};
            const res = csvRes();

            await parkirController.exportParkirLogs(req, res);

            expect(res.setHeader).toHaveBeenCalledWith('X-Export-Truncated', 'true');
            const csv = res.send.mock.calls[0][0];
            expect(plateCount(csv)).toBe(10000);
            expect(csv).toContain('10000,"2026');
            expect(csv).not.toContain('10001,"2026'); // the extra (oldest) row is dropped
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('does not flag an export that is under the cap', async () => {
            prisma.logParkir.findMany.mockResolvedValue([csvRow(1), csvRow(2)]);
            const req = createMockReq();
            req.query = {};
            const res = csvRes();

            await parkirController.exportParkirLogs(req, res);

            expect(res.setHeader).not.toHaveBeenCalledWith('X-Export-Truncated', expect.anything());
        });
    });

    describe('manualOverride', () => {
        test('should allow manual override entry successfully', async () => {
            prisma.$queryRaw.mockResolvedValue([{
                id_parkiran: 1,
                nama_parkiran: 'Gedung A',
                kapasitas: 10,
                live_kapasitas: 5
            }]);

            prisma.kendaraan.findFirst.mockResolvedValue({
                id_kendaraan: 2,
                plat_nomor: 'D9999XYZ',
                user: { id_user: 5, nama: 'Budi' }
            });

            prisma.$executeRaw.mockResolvedValue(1); // successfully incremented capacity
            prisma.logParkir.create.mockResolvedValue({ id_log_parkir: 150 });

            // Mock Socket.io
            const mockIo = { emit: jest.fn() };
            const req = createMockReq({ plat_nomor: 'D 9999 XYZ', gate_type: 'MASUK' });
            req.params = { id: '1' };
            req.app.get.mockReturnValue(mockIo);

            // Re-mock prisma queryRaw for socket capacity check
            prisma.$queryRaw.mockResolvedValueOnce([{
                id_parkiran: 1,
                nama_parkiran: 'Gedung A',
                kapasitas: 10,
                live_kapasitas: 5
            }]).mockResolvedValueOnce([{
                live_kapasitas: 6
            }]);

            const res = createMockRes();

            await parkirController.manualOverride(req, res);

            expect(prisma.$executeRaw).toHaveBeenCalled();
            expect(prisma.logParkir.create).toHaveBeenCalled();
            expect(mockIo.emit).toHaveBeenCalledWith('parking_update', expect.objectContaining({
                id_parkiran: 1,
                live_kapasitas: 6,
                kapasitas: 10
            }));
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                message: expect.stringContaining('Override berhasil')
            }));
        });

        test('should allow manual override exit successfully', async () => {
            prisma.$queryRaw.mockResolvedValueOnce([{
                id_parkiran: 1,
                nama_parkiran: 'Gedung A',
                kapasitas: 10,
                live_kapasitas: 5
            }]);

            prisma.kendaraan.findFirst.mockResolvedValue({
                id_kendaraan: 2,
                plat_nomor: 'D9999XYZ',
                user: { id_user: 5 }
            });

            prisma.logParkir.create.mockResolvedValue({ id_log_parkir: 151 });

            const mockIo = { emit: jest.fn() };
            const req = createMockReq({ plat_nomor: 'D9999XYZ', gate_type: 'KELUAR' });
            req.params = { id: '1' };
            req.app.get.mockReturnValue(mockIo);

            prisma.$queryRaw.mockResolvedValueOnce([{
                live_kapasitas: 4
            }]);

            const res = createMockRes();

            await parkirController.manualOverride(req, res);

            expect(prisma.$executeRaw).toHaveBeenCalled(); // decrements capacity
            expect(mockIo.emit).toHaveBeenCalledWith('parking_update', expect.objectContaining({
                id_parkiran: 1,
                live_kapasitas: 4
            }));
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('should fail if required fields are missing', async () => {
            const req = createMockReq({});
            const res = createMockRes();

            await parkirController.manualOverride(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
        });

        test('should fail if vehicle not found', async () => {
            prisma.$queryRaw.mockResolvedValue([{ id_parkiran: 1, kapasitas: 10 }]);
            prisma.kendaraan.findFirst.mockResolvedValue(null);

            const req = createMockReq({ plat_nomor: 'UNKNOWN', gate_type: 'MASUK' });
            const res = createMockRes();

            await parkirController.manualOverride(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
            expect(logAudit).not.toHaveBeenCalled();
        });

        describe('audit and plate normalisation', () => {
            const setup = () => {
                prisma.$queryRaw.mockReset().mockResolvedValue([{
                    id_parkiran: 4, nama_parkiran: 'Gedung D', kapasitas: 10, live_kapasitas: 5
                }]);
                prisma.$executeRaw.mockReset().mockResolvedValue(1);
                prisma.kendaraan.findFirst.mockReset().mockResolvedValue({
                    id_kendaraan: 2, plat_nomor: 'D9999XYZ', user: { id_user: 5, nama: 'Budi' }
                });
                prisma.logParkir.create.mockReset().mockResolvedValue({ id_log_parkir: 150 });
                const req = createMockReq({ plat_nomor: 'd 9999-xyz', gate_type: 'MASUK' });
                req.user = { id_user: 42 };
                req.ip = '10.0.0.9';
                req.params = { id: '4' };
                return req;
            };

            test('writes a PARKIR_MANUAL_OVERRIDE audit entry carrying the admin id', async () => {
                const req = setup();
                const res = createMockRes();

                await parkirController.manualOverride(req, res);

                expect(logAudit).toHaveBeenCalledTimes(1);
                expect(logAudit).toHaveBeenCalledWith({
                    action: 'PARKIR_MANUAL_OVERRIDE',
                    performedBy: 42,
                    targetUserId: 5,
                    details: 'Override MASUK plat D9999XYZ di parkiran 4 (log 150)',
                    ip: '10.0.0.9'
                });
                expect(res.status).toHaveBeenCalledWith(200);
            });

            test('looks the vehicle up by the normalised plate', async () => {
                const req = setup();

                await parkirController.manualOverride(req, createMockRes());

                expect(prisma.kendaraan.findFirst).toHaveBeenCalledWith(expect.objectContaining({
                    where: { plat_nomor: 'D9999XYZ', deletedAt: null }
                }));
            });

            test('does not audit an override that was refused because the parkiran is full', async () => {
                const req = setup();
                prisma.$executeRaw.mockResolvedValue(0);
                const res = createMockRes();

                await parkirController.manualOverride(req, res);

                expect(res.status).toHaveBeenCalledWith(400);
                expect(logAudit).not.toHaveBeenCalled();
            });
        });
    });
});

describe('Parkir Controller - getHistoriParkir', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        prisma.kendaraan.findMany.mockReset().mockResolvedValue([{ id_kendaraan: 7 }]);
        prisma.logParkir.count.mockReset().mockResolvedValue(0);
        prisma.logParkir.findMany.mockReset().mockResolvedValue([]);
    });

    test('only returns logs written for the requesting user, even on a reused kendaraan row', async () => {
        const req = createMockReq();
        req.user = { id_user: 11 };
        const res = createMockRes();

        await parkirController.getHistoriParkir(req, res);

        const expectedWhere = { id_kendaraan: { in: [7] }, id_user: 11 };
        expect(prisma.logParkir.count).toHaveBeenCalledWith({ where: expectedWhere });
        expect(prisma.logParkir.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: expectedWhere }));
        expect(res.status).toHaveBeenCalledWith(200);
    });
});

describe('Parkir Controller - reconcileKapasitas', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        prisma.$queryRaw.mockReset().mockResolvedValue([{ actual_count: '4' }]);
        prisma.$executeRaw.mockReset().mockResolvedValue(1);
        prisma.parkiran.findUnique.mockReset().mockResolvedValue({ kapasitas: 10 });
    });

    test('recomputes live_kapasitas from the logs and broadcasts the new value', async () => {
        const mockIo = { emit: jest.fn() };
        const req = createMockReq();
        req.params = { id: '2' };
        req.app.get.mockReturnValue(mockIo);
        const res = createMockRes();

        await parkirController.reconcileKapasitas(req, res);

        expect(prisma.$executeRaw).toHaveBeenCalledTimes(1);
        expect(mockIo.emit).toHaveBeenCalledWith('parking_update', {
            id_parkiran: 2,
            live_kapasitas: 4,
            kapasitas: 10
        });
        expect(res.status).toHaveBeenCalledWith(200);
        expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ data: { live_kapasitas: 4 } }));
    });
});

describe('Parkir Controller - processEdgeEntry plate OCR fallback and test mode', () => {
    const originalTestMode = process.env.TEST_MODE;
    const originalPlateApiKey = process.env.PLATE_API_KEY;

    beforeEach(() => {
        jest.clearAllMocks();
        process.env.EDGE_DEVICE_SECRET = 'secret123';
        pythonClient.post.mockReset().mockResolvedValue({ data: { success: false } });
        prisma.kendaraan.findFirst.mockReset().mockResolvedValue(null);
    });

    afterEach(() => {
        if (originalTestMode === undefined) delete process.env.TEST_MODE;
        else process.env.TEST_MODE = originalTestMode;
        if (originalPlateApiKey === undefined) delete process.env.PLATE_API_KEY;
        else process.env.PLATE_API_KEY = originalPlateApiKey;
    });

    // The edge device sends no plate_text, so the controller falls back to the plate OCR service.
    const sendWithClientTestModeHeader = async () => {
        const req = createMockReq(
            { parkiran_id: '1', gate_type: 'MASUK' },
            { 'x-edge-secret': 'secret123', 'x-test-mode': 'true' }
        );
        req.files = { image: [{ buffer: Buffer.from('img'), originalname: 'plate.jpg', mimetype: 'image/jpeg', size: 3 }] };
        await parkirController.processEdgeEntry(req, createMockRes());
        expect(pythonClient.post).toHaveBeenCalledTimes(1);
        return pythonClient.post.mock.calls[0][2].headers;
    };

    test('does not forward the client x-test-mode header to the plate service', async () => {
        delete process.env.TEST_MODE;

        const headers = await sendWithClientTestModeHeader();

        expect(Object.keys(headers).map((h) => h.toLowerCase())).not.toContain('x-test-mode');
    });

    test('sends no X-Test-Mode header even when TEST_MODE=true is in the backend environment (the plate service decides from its own env)', async () => {
        process.env.TEST_MODE = 'true';

        const headers = await sendWithClientTestModeHeader();

        expect(Object.keys(headers).map((h) => h.toLowerCase())).not.toContain('x-test-mode');
    });

    test('sends X-API-Key from PLATE_API_KEY to the plate service', async () => {
        process.env.PLATE_API_KEY = 'plate-secret-key';

        const headers = await sendWithClientTestModeHeader();

        expect(headers['X-API-Key']).toBe('plate-secret-key');
    });
});
