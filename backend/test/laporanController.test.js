/**
 * Unit Testing - Laporan Controller
 */

jest.mock('../utils/prisma', () => ({
  sesiAbsensi: { findUnique: jest.fn(), findMany: jest.fn(), count: jest.fn() },
  pesertaKelas: { findMany: jest.fn() },
  absensi: { findMany: jest.fn() },
  kelas: { findUnique: jest.fn() },
}));

jest.mock('fs', () => ({
  existsSync: jest.fn().mockReturnValue(false),
}));

jest.mock('pdfkit-table', () => {
  return jest.fn().mockImplementation(() => {
    const doc = {
      page: { width: 595, height: 842 },
      y: 120,
      pipe: jest.fn(),
      end: jest.fn(),
      save: jest.fn().mockReturnThis(),
      restore: jest.fn().mockReturnThis(),
      rect: jest.fn().mockReturnThis(),
      roundedRect: jest.fn().mockReturnThis(),
      fill: jest.fn().mockReturnThis(),
      moveTo: jest.fn().mockReturnThis(),
      lineTo: jest.fn().mockReturnThis(),
      strokeColor: jest.fn().mockReturnThis(),
      lineWidth: jest.fn().mockReturnThis(),
      stroke: jest.fn().mockReturnThis(),
      image: jest.fn().mockReturnThis(),
      font: jest.fn().mockReturnThis(),
      fontSize: jest.fn().mockReturnThis(),
      fillColor: jest.fn().mockReturnThis(),
      text: jest.fn().mockReturnThis(),
      table: jest.fn().mockResolvedValue(undefined),
    };

    return doc;
  });
});

jest.mock('exceljs', () => {
  const createCell = () => ({
    value: null,
    font: null,
    fill: null,
    border: null,
    alignment: null,
  });

  const createRow = (values = []) => {
    const cells = values.map((value) => ({ value }));
    return {
      values,
      font: null,
      eachCell: (callback) => cells.forEach((cell, index) => callback(cell, index + 1)),
      getCell: (index) => {
        if (!cells[index - 1]) {
          cells[index - 1] = createCell();
        }
        return cells[index - 1];
      },
    };
  };

  const workbook = {
    creator: null,
    created: null,
    xlsx: { write: jest.fn().mockResolvedValue(undefined) },
    addWorksheet: jest.fn().mockImplementation(() => {
      const cells = new Map();
      return {
        mergeCells: jest.fn(),
        addRow: jest.fn().mockImplementation((values = []) => createRow(values)),
        getCell: jest.fn().mockImplementation((address) => {
          if (!cells.has(address)) {
            cells.set(address, createCell());
          }
          return cells.get(address);
        }),
        columns: [],
      };
    }),
  };

  return {
    Workbook: jest.fn().mockImplementation(() => workbook),
  };
});

const prisma = require('../utils/prisma');
const laporanController = require('../controllers/laporanController');

const createMockReq = (params = {}, user = { id_user: 1, role: 'DOSEN' }) => ({
  params,
  user,
});

const createMockRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  res.setHeader = jest.fn();
  return res;
};

describe('Laporan Controller Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('generateLaporanSesiPdf', () => {
    test('returns 400 for invalid session id', async () => {
      const req = createMockReq({ id: 'abc' });
      const res = createMockRes();

      await expect(laporanController.generateLaporanSesiPdf(req, res)).rejects.toThrow('ID Sesi tidak valid');
    });

    test('returns 404 when session is not found', async () => {
      prisma.sesiAbsensi.findUnique.mockResolvedValue(null);

      const req = createMockReq({ id: '1' });
      const res = createMockRes();

      await laporanController.generateLaporanSesiPdf(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        status: 'error',
        message: 'Sesi tidak ditemukan',
      }));
    });

    test('returns 403 when dosen is not the class owner', async () => {
      prisma.sesiAbsensi.findUnique.mockResolvedValue({
        id_sesi_absensi: 1,
        mulai: new Date('2026-01-01T08:00:00Z'),
        id_kelas: 10,
        kelas: {
          id_dosen: 2,
          nama_kelas: 'IF-01',
          matakuliah: { nama_matakuliah: 'Sistem Informasi' },
          dosen: { nama: 'Dosen Lain' },
        },
      });

      const req = createMockReq({ id: '1' }, { id_user: 1, role: 'DOSEN' });
      const res = createMockRes();

      await laporanController.generateLaporanSesiPdf(req, res);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        status: 'error',
        message: 'Anda tidak memiliki akses',
      }));
    });

    test('generates PDF when data is valid', async () => {
      prisma.sesiAbsensi.findUnique.mockResolvedValue({
        id_sesi_absensi: 1,
        mulai: new Date('2026-01-01T08:00:00Z'),
        id_kelas: 10,
        kelas: {
          id_dosen: 1,
          nama_kelas: 'IF-01',
          matakuliah: { nama_matakuliah: 'Sistem Informasi' },
          dosen: { nama: 'Dosen Test' },
        },
      });
      prisma.pesertaKelas.findMany.mockResolvedValue([
        { id_mahasiswa: 11, mahasiswa: { username: 'mhs1', nama: 'Mahasiswa 1' } },
      ]);
      prisma.absensi.findMany.mockResolvedValue([
        { id_user: 11, createdAt: new Date('2026-01-01T08:05:00Z') },
      ]);

      const req = createMockReq({ id: '1' });
      const res = createMockRes();

      await laporanController.generateLaporanSesiPdf(req, res);

      expect(res.setHeader).toHaveBeenCalledWith('Content-Type', 'application/pdf');
      expect(res.setHeader).toHaveBeenCalledWith(expect.stringContaining('Content-Disposition'), expect.any(String));
      expect(res.status).not.toHaveBeenCalledWith(400);
    });
  });

  describe('generateLaporanSesiExcel', () => {
    test('returns 400 for invalid session id', async () => {
      const req = createMockReq({ id: '0' });
      const res = createMockRes();

      await expect(laporanController.generateLaporanSesiExcel(req, res)).rejects.toThrow('ID Sesi tidak valid');
    });

    test('returns 404 when session is not found', async () => {
      prisma.sesiAbsensi.findUnique.mockResolvedValue(null);

      const req = createMockReq({ id: '1' });
      const res = createMockRes();

      await laporanController.generateLaporanSesiExcel(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
    });

    test('generates Excel when data is valid', async () => {
      prisma.sesiAbsensi.findUnique.mockResolvedValue({
        id_sesi_absensi: 1,
        mulai: new Date('2026-01-01T08:00:00Z'),
        id_kelas: 10,
        kelas: {
          id_dosen: 1,
          nama_kelas: 'IF-01',
          matakuliah: { nama_matakuliah: 'Sistem Informasi' },
          dosen: { nama: 'Dosen Test' },
        },
      });
      prisma.pesertaKelas.findMany.mockResolvedValue([
        { id_mahasiswa: 11, mahasiswa: { username: 'mhs1', nama: 'Mahasiswa 1' } },
      ]);
      prisma.absensi.findMany.mockResolvedValue([
        { id_user: 11, createdAt: new Date('2026-01-01T08:05:00Z') },
      ]);

      const req = createMockReq({ id: '1' });
      const res = createMockRes();

      await laporanController.generateLaporanSesiExcel(req, res);

      expect(res.setHeader).toHaveBeenCalledWith(
        'Content-Type',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(res.setHeader).toHaveBeenCalledWith(expect.stringContaining('Content-Disposition'), expect.any(String));
    });
  });

  describe('generateLaporanKelasPdf', () => {
    test('returns 404 when class is not found', async () => {
      prisma.kelas.findUnique.mockResolvedValue(null);

      const req = createMockReq({ id: '1' });
      const res = createMockRes();

      await laporanController.generateLaporanKelasPdf(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
    });
  });

  describe('generateLaporanKelasExcel', () => {
    test('returns 404 when class is not found', async () => {
      prisma.kelas.findUnique.mockResolvedValue(null);

      const req = createMockReq({ id: '1' });
      const res = createMockRes();

      await laporanController.generateLaporanKelasExcel(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
    });
  });
});