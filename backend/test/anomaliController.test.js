/**
 * Unit Testing - Anomaly Controller
 * 
 * @author MyTelUV2 Team
 * @date 2026-05-18
 */

jest.mock('../utils/prisma', () => ({
    kelas: { findUnique: jest.fn() },
    pesertaKelas: { findMany: jest.fn() },
    absensi: { findMany: jest.fn() },
    sesiAbsensi: { findMany: jest.fn(), count: jest.fn() },
    laporanAnomali: { findFirst: jest.fn(), findMany: jest.fn(), updateMany: jest.fn(), createMany: jest.fn(), update: jest.fn() },
    systemSetting: { findUnique: jest.fn(), upsert: jest.fn() },
    $transaction: jest.fn(),
    $queryRaw: jest.fn(),
}));

jest.mock('axios');

const prisma = require('../utils/prisma');
const axios = require('axios');
const anomaliController = require('../controllers/anomaliController');
const { globalAnomalyQueue } = require('../utils/TaskQueue');

const createMockReq = (body = {}, user = { id_user: 1, role: 'DOSEN' }, params = {}, query = {}, headers = {}) => ({
    body,
    user,
    params,
    query,
    headers
});

const createMockRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

describe('Anomaly Controller Tests', () => {

    beforeEach(() => {
        jest.clearAllMocks();
    });

    describe('analyzeKelasAttendance', () => {
        test('should fail if class is not found', async () => {
            const req = createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 999 });
            const res = createMockRes();

            prisma.kelas.findUnique.mockResolvedValue(null);

            await anomaliController.analyzeKelasAttendance(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                message: 'Kelas tidak ditemukan'
            }));
        });

        test('should fail if user is unauthorized Dosen', async () => {
            const req = createMockReq({}, { id_user: 2, role: 'DOSEN' }, { id_kelas: 1 });
            const res = createMockRes();

            prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1 });

            await anomaliController.analyzeKelasAttendance(req, res);

            expect(res.status).toHaveBeenCalledWith(403);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                message: 'Anda tidak memiliki akses untuk menganalisis kelas ini'
            }));
        });

        test('should analyze class attendance successfully', async () => {
            const req = createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 });
            const res = createMockRes();

            prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1 });
            prisma.systemSetting.findUnique.mockResolvedValue(null); // Will fallback to default thresholds
            
            const mockPeserta = [
                { mahasiswa: { id_user: 10, nama: 'Student A' } },
                { mahasiswa: { id_user: 11, nama: 'Student B' } }
            ];
            const mockAbsensi = [
                { id_user: 10, id_sesi_absensi: 1, createdAt: new Date() }
            ];
            const mockSesi = [
                { id_sesi_absensi: 1, mulai: new Date(), selesai: new Date() }
            ];

            prisma.$transaction.mockResolvedValue([mockPeserta, mockAbsensi, mockSesi]);
            prisma.laporanAnomali.updateMany.mockResolvedValue({ count: 1 });
            prisma.laporanAnomali.createMany.mockResolvedValue({ count: 1 });

            await anomaliController.analyzeKelasAttendance(req, res);

            expect(prisma.$transaction).toHaveBeenCalled();
            expect(prisma.laporanAnomali.updateMany).toHaveBeenCalled();
            expect(prisma.laporanAnomali.createMany).toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(200);
        });
    });

    describe('updateLaporanAnomali', () => {
        test('should fail if status is invalid', async () => {
            const req = createMockReq({ status: 'INVALID' }, { id_user: 1, role: 'DOSEN' }, { id_anomali: 1 });
            const res = createMockRes();

            await anomaliController.updateLaporanAnomali(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
        });

        test('should fail if anomaly report not found', async () => {
            const req = createMockReq({ status: 'REVIEWED' }, { id_user: 1, role: 'DOSEN' }, { id_anomali: 999 });
            const res = createMockRes();

            prisma.laporanAnomali.findFirst.mockResolvedValue(null);

            await anomaliController.updateLaporanAnomali(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
        });

        test('should update status and notes successfully', async () => {
            const req = createMockReq({ status: 'RESOLVED', catatan_dosen: 'Verified medical checkup' }, { id_user: 1, role: 'DOSEN' }, { id_anomali: 1 });
            const res = createMockRes();

            const mockLaporan = {
                id_anomali: 1,
                id_kelas: 10,
                kelas: { id_dosen: 1 }
            };

            prisma.laporanAnomali.findFirst.mockResolvedValue(mockLaporan);
            prisma.laporanAnomali.update.mockResolvedValue({ id_anomali: 1, status: 'RESOLVED', catatan_dosen: 'Verified medical checkup' });

            await anomaliController.updateLaporanAnomali(req, res);

            expect(prisma.laporanAnomali.update).toHaveBeenCalledWith(expect.objectContaining({
                where: { id_anomali: 1 },
                data: expect.objectContaining({
                    status: 'RESOLVED',
                    catatan_dosen: 'Verified medical checkup'
                })
            }));
            expect(res.status).toHaveBeenCalledWith(200);
        });
    });

    describe('5xx responses never leak error.message', () => {
        const leaky = new Error('connect ECONNREFUSED db.internal.example:5432 password=hunter2');
        let errorSpy;

        beforeEach(() => {
            errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
        });

        afterEach(() => errorSpy.mockRestore());

        const expectGeneric500 = (res) => {
            expect(res.status).toHaveBeenCalledWith(500);
            expect(res.json).toHaveBeenCalledWith({
                status: 'error',
                message: 'Terjadi kesalahan pada server'
            });
            expect(JSON.stringify(res.json.mock.calls)).not.toMatch(/ECONNREFUSED|hunter2/);
            expect(errorSpy).toHaveBeenCalled(); // the real error is logged, not returned
        };

        test('analyzeKelasAttendance (sync) when saving the analysis fails', async () => {
            const req = createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 });
            const res = createMockRes();

            prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1 });
            prisma.systemSetting.findUnique.mockResolvedValue(null);
            prisma.$transaction.mockResolvedValueOnce([[{ mahasiswa: { id_user: 10, nama: 'Student A' } }], [], []]);
            prisma.laporanAnomali.updateMany.mockRejectedValueOnce(leaky);

            await anomaliController.analyzeKelasAttendance(req, res);

            expectGeneric500(res);
        });

        test('updateAnomalySettings when the database write fails', async () => {
            const req = createMockReq({ threshold_jarang_hadir: 50 }, { id_user: 1, role: 'ADMIN' });
            const res = createMockRes();
            prisma.systemSetting.upsert.mockRejectedValueOnce(leaky);

            await anomaliController.updateAnomalySettings(req, res);

            expectGeneric500(res);
        });

        test('getJobStatus replaces the raw error of a FAILED job', async () => {
            const statusSpy = jest.spyOn(globalAnomalyQueue, 'getJobStatus').mockReturnValue({
                id: 'anomaly_kelas_1_100',
                status: 'FAILED',
                progress: 100,
                ownerId: 5,
                error: leaky.message
            });
            try {
                const req = createMockReq({}, { id_user: 5, role: 'DOSEN' }, { jobId: 'anomaly_kelas_1_100' });
                const res = createMockRes();

                await anomaliController.getJobStatus(req, res);

                expect(res.status).toHaveBeenCalledWith(200);
                const { data } = res.json.mock.calls[0][0];
                expect(data.status).toBe('FAILED');
                expect(data.error).toBe('Terjadi kesalahan pada server');
                expect(JSON.stringify(data)).not.toMatch(/ECONNREFUSED|hunter2/);
            } finally {
                statusSpy.mockRestore();
            }
        });
    });

    describe('async analysis jobs: ownership', () => {
        let statusSpy;

        const job = {
            id: 'anomaly_kelas_1_100',
            status: 'COMPLETED',
            progress: 100,
            ownerId: 5,
            result: [{ id_user: 10, nama: 'Student A', type_anomali: 'TIDAK_HADIR_BERULANG' }]
        };

        afterEach(() => {
            if (statusSpy) statusSpy.mockRestore();
            statusSpy = undefined;
        });

        test('analyzeKelasAttendance (async) stores the requesting user as the job owner', async () => {
            const addJobSpy = jest.spyOn(globalAnomalyQueue, 'addJob').mockImplementation(() => ({}));
            try {
                const req = createMockReq({}, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 }, { async: 'true' });
                const res = createMockRes();

                prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1 });
                prisma.$transaction.mockResolvedValue([[{ mahasiswa: { id_user: 10, nama: 'Student A' } }], [], []]);

                await anomaliController.analyzeKelasAttendance(req, res);

                expect(res.status).toHaveBeenCalledWith(202);
                expect(addJobSpy).toHaveBeenCalledWith(expect.any(String), expect.any(Function), 1);
            } finally {
                addJobSpy.mockRestore();
            }
        });

        test('TaskQueue.addJob records the owner on the job', () => {
            const { TaskQueue } = require('../utils/TaskQueue');
            const queue = new TaskQueue(1);

            const info = queue.addJob('job-with-owner', async () => 'done', 7);

            expect(info.ownerId).toBe(7);
            expect(queue.getJobStatus('job-with-owner').ownerId).toBe(7);
        });

        test('getJobStatus returns the job to its owner without leaking ownerId', async () => {
            statusSpy = jest.spyOn(globalAnomalyQueue, 'getJobStatus').mockReturnValue(job);
            const req = createMockReq({}, { id_user: 5, role: 'DOSEN' }, { jobId: job.id });
            const res = createMockRes();

            await anomaliController.getJobStatus(req, res);

            expect(res.status).toHaveBeenCalledWith(200);
            const payload = res.json.mock.calls[0][0];
            expect(payload.data).toMatchObject({ id: job.id, status: 'COMPLETED' });
            expect(payload.data).not.toHaveProperty('ownerId');
        });

        test('getJobStatus returns 404 for a different DOSEN', async () => {
            statusSpy = jest.spyOn(globalAnomalyQueue, 'getJobStatus').mockReturnValue(job);
            const req = createMockReq({}, { id_user: 6, role: 'DOSEN' }, { jobId: job.id });
            const res = createMockRes();

            await anomaliController.getJobStatus(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
            expect(JSON.stringify(res.json.mock.calls[0][0])).not.toContain('Student A');
        });

        test('getJobStatus lets an ADMIN read any job', async () => {
            statusSpy = jest.spyOn(globalAnomalyQueue, 'getJobStatus').mockReturnValue(job);
            const req = createMockReq({}, { id_user: 1, role: 'ADMIN' }, { jobId: job.id });
            const res = createMockRes();

            await anomaliController.getJobStatus(req, res);

            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('getJobStatus returns 404 for an unknown job', async () => {
            statusSpy = jest.spyOn(globalAnomalyQueue, 'getJobStatus').mockReturnValue(null);
            const req = createMockReq({}, { id_user: 5, role: 'DOSEN' }, { jobId: 'nope' });
            const res = createMockRes();

            await anomaliController.getJobStatus(req, res);

            expect(res.status).toHaveBeenCalledWith(404);
        });

        test('a job without an owner is only visible to ADMIN', async () => {
            statusSpy = jest.spyOn(globalAnomalyQueue, 'getJobStatus').mockReturnValue({ ...job, ownerId: null });
            const dosenRes = createMockRes();
            await anomaliController.getJobStatus(createMockReq({}, { id_user: 5, role: 'DOSEN' }, { jobId: job.id }), dosenRes);
            expect(dosenRes.status).toHaveBeenCalledWith(404);

            const adminRes = createMockRes();
            await anomaliController.getJobStatus(createMockReq({}, { id_user: 1, role: 'ADMIN' }, { jobId: job.id }), adminRes);
            expect(adminRes.status).toHaveBeenCalledWith(200);
        });
    });
});
