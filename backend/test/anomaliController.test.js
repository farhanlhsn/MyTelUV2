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
    $transaction: jest.fn(),
}));

jest.mock('axios');

const prisma = require('../utils/prisma');
const axios = require('axios');
const anomaliController = require('../controllers/anomaliController');

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
        test('should fail if threshold is invalid', async () => {
            const req = createMockReq({ threshold: 1.5 }, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 });
            const res = createMockRes();

            await anomaliController.analyzeKelasAttendance(req, res);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'error',
                message: 'Threshold harus berupa angka antara 0.1 dan 1.0'
            }));
        });

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
            const req = createMockReq({ threshold: 0.6 }, { id_user: 1, role: 'DOSEN' }, { id_kelas: 1 });
            const res = createMockRes();

            prisma.kelas.findUnique.mockResolvedValue({ id_kelas: 1, id_dosen: 1 });
            
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

            axios.post.mockResolvedValue({
                data: {
                    success: true,
                    anomalies: [
                        { id_user: 11, type_anomali: 'TIDAK_HADIR_BERULANG', confidence: 0.8, description: 'Low attendance rate' }
                    ]
                }
            });

            await anomaliController.analyzeKelasAttendance(req, res);

            expect(prisma.$transaction).toHaveBeenCalled();
            expect(axios.post).toHaveBeenCalled();
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
});
