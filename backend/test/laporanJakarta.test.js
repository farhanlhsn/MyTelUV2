/**
 * Unit Testing - Laporan (Excel) uses Asia/Jakarta time and counts only closed sessions on/after enrollment
 *
 * The real ExcelJS writes the workbook and the test reads it back, so the assertions see the cells
 * a dosen would see. Instants are explicit UTC, so the result does not depend on the machine time zone.
 */

jest.mock('../utils/prisma', () => ({
    sesiAbsensi: { findUnique: jest.fn(), findMany: jest.fn() },
    pesertaKelas: { findMany: jest.fn() },
    absensi: { findMany: jest.fn() },
    kelas: { findUnique: jest.fn() },
}));

const { PassThrough } = require('stream');
const ExcelJS = require('exceljs');
const prisma = require('../utils/prisma');
const { generateLaporanSesiExcel, generateLaporanKelasExcel } = require('../controllers/laporanController');

const admin = { id_user: 1, role: 'ADMIN' };

// Runs an Excel export handler against an in-memory response and parses the produced workbook
const runExcelExport = async (handler, req) => {
    const res = new PassThrough();
    res.headers = {};
    res.setHeader = (name, value) => { res.headers[name.toLowerCase()] = value; };
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);

    const chunks = [];
    res.on('data', (chunk) => chunks.push(chunk));
    const ended = new Promise((resolve) => res.on('end', resolve));

    const next = jest.fn();
    await handler(req, res, next);
    expect(next).not.toHaveBeenCalled();
    if (!res.writableEnded) res.end();
    await ended;

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(Buffer.concat(chunks));
    return { headers: res.headers, sheet: workbook.worksheets[0] };
};

const rowValues = (sheet, rowNumber) => sheet.getRow(rowNumber).values.slice(1);

describe('Laporan Excel - Asia/Jakarta and countable sessions', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('per-session export uses the Jakarta date and time', async () => {
        prisma.sesiAbsensi.findUnique.mockResolvedValue({
            id_sesi_absensi: 9,
            id_kelas: 1,
            // 01:30 WIB on Wednesday 14/10/2026, still Tuesday 13/10 in UTC
            mulai: new Date('2026-10-13T18:30:00Z'),
            kelas: { id_dosen: 5, nama_kelas: 'A', matakuliah: { nama_matakuliah: 'Basis Data' } }
        });
        prisma.pesertaKelas.findMany.mockResolvedValue([
            { id_mahasiswa: 10, mahasiswa: { username: '1301', nama: 'Budi' } }
        ]);
        prisma.absensi.findMany.mockResolvedValue([
            { id_user: 10, createdAt: new Date('2026-10-13T18:35:10Z') }
        ]);

        const { headers, sheet } = await runExcelExport(generateLaporanSesiExcel, { params: { id: '9' }, user: admin });

        expect(headers['content-disposition']).toContain('Sesi_A_2026-10-14.xlsx');
        expect(sheet.getCell('A2').value).toContain('Rabu, 14 Oktober 2026');
        expect(rowValues(sheet, 5)).toEqual([1, '1301', 'Budi', 'HADIR', '01.35.10']);
    });

    test('class recap counts only closed sessions on/after each enrollment', async () => {
        const HOUR = 60 * 60 * 1000;
        prisma.kelas.findUnique.mockResolvedValue({
            id_kelas: 1, id_dosen: 5, nama_kelas: 'A',
            matakuliah: { nama_matakuliah: 'Basis Data' }, dosen: { nama: 'Dosen' }
        });
        prisma.sesiAbsensi.findMany.mockResolvedValue([
            // Before Budi enrolled
            { id_sesi_absensi: 1, status: false, mulai: new Date('2020-01-10T01:00:00Z'), selesai: new Date('2020-01-10T03:00:00Z') },
            // 01:30 WIB on 2/3/2020 (1/3 in UTC), ended but never closed by hand
            { id_sesi_absensi: 2, status: true, mulai: new Date('2020-03-01T18:30:00Z'), selesai: new Date('2020-03-01T20:30:00Z') },
            // Still running
            { id_sesi_absensi: 3, status: true, mulai: new Date(Date.now() - HOUR), selesai: new Date(Date.now() + HOUR) }
        ]);
        prisma.pesertaKelas.findMany.mockResolvedValue([
            { id_mahasiswa: 10, createdAt: new Date('2020-02-01T00:00:00Z'), mahasiswa: { username: '1301', nama: 'Budi' } }
        ]);
        prisma.absensi.findMany.mockResolvedValue([
            { id_user: 10, id_sesi_absensi: 2 }
        ]);

        const { sheet } = await runExcelExport(generateLaporanKelasExcel, { params: { id: '1' }, user: admin });

        expect(rowValues(sheet, 4)[4]).toBe('2/3');
        // '-' marks a session that does not count for this student (before enrollment or still running)
        expect(rowValues(sheet, 5)).toEqual([1, '1301', 'Budi', '-', '✓', '-', 1, '100%']);
    });

    test('per-session export shows each status, counts IZIN/SAKIT as excused and leaves out late enrollees', async () => {
        prisma.sesiAbsensi.findUnique.mockResolvedValue({
            id_sesi_absensi: 9,
            id_kelas: 1,
            mulai: new Date('2026-10-14T01:00:00Z'),
            kelas: { id_dosen: 5, nama_kelas: 'A', matakuliah: { nama_matakuliah: 'Basis Data' } }
        });
        const enrolled = new Date('2026-10-01T00:00:00Z');
        prisma.pesertaKelas.findMany.mockResolvedValue([
            { id_mahasiswa: 10, createdAt: enrolled, mahasiswa: { username: '1301', nama: 'Budi' } },
            { id_mahasiswa: 11, createdAt: enrolled, mahasiswa: { username: '1302', nama: 'Cici' } },
            { id_mahasiswa: 12, createdAt: enrolled, mahasiswa: { username: '1303', nama: 'Dedi' } },
            { id_mahasiswa: 13, createdAt: enrolled, mahasiswa: { username: '1304', nama: 'Eka' } },
            // Enrolled after the session without a record: not part of this session
            { id_mahasiswa: 14, createdAt: new Date('2026-10-20T00:00:00Z'), mahasiswa: { username: '1305', nama: 'Fafa' } }
        ]);
        prisma.absensi.findMany.mockResolvedValue([
            { id_user: 10, status: 'HADIR', createdAt: new Date('2026-10-14T01:05:00Z') },
            { id_user: 11, status: 'TELAT', createdAt: new Date('2026-10-14T01:25:00Z') },
            { id_user: 12, status: 'SAKIT', createdAt: new Date('2026-10-14T05:00:00Z') }
        ]);

        const { sheet } = await runExcelExport(generateLaporanSesiExcel, { params: { id: '9' }, user: admin });

        expect(rowValues(sheet, 5)).toEqual([1, '1301', 'Budi', 'HADIR', '08.05.00']);
        expect(rowValues(sheet, 6)).toEqual([2, '1302', 'Cici', 'TELAT', '08.25.00']);
        expect(rowValues(sheet, 7)).toEqual([3, '1303', 'Dedi', 'SAKIT', '-']);
        expect(rowValues(sheet, 8)).toEqual([4, '1304', 'Eka', 'TIDAK HADIR', '-']);
        // Summary after one empty row
        expect(rowValues(sheet, 10)).toEqual(['', '', 'Total: 4 Mahasiswa', 'Hadir: 2', 'Tidak Hadir: 1', 'Izin/Sakit: 1']);
    });

    test('class recap marks TELAT/IZIN/SAKIT and leaves excused sessions out of the percentage', async () => {
        prisma.kelas.findUnique.mockResolvedValue({
            id_kelas: 1, id_dosen: 5, nama_kelas: 'A',
            matakuliah: { nama_matakuliah: 'Basis Data' }, dosen: { nama: 'Dosen' }
        });
        const closed = (id, day) => ({
            id_sesi_absensi: id, status: false,
            mulai: new Date(`2020-03-${day}T01:00:00Z`), selesai: new Date(`2020-03-${day}T03:00:00Z`)
        });
        prisma.sesiAbsensi.findMany.mockResolvedValue([closed(1, '02'), closed(2, '09'), closed(3, '16'), closed(4, '23'), closed(5, '30')]);
        prisma.pesertaKelas.findMany.mockResolvedValue([
            { id_mahasiswa: 10, createdAt: new Date('2020-02-01T00:00:00Z'), mahasiswa: { username: '1301', nama: 'Budi' } }
        ]);
        prisma.absensi.findMany.mockResolvedValue([
            { id_user: 10, id_sesi_absensi: 1, status: 'HADIR' },
            { id_user: 10, id_sesi_absensi: 2, status: 'TELAT' },
            { id_user: 10, id_sesi_absensi: 3, status: 'IZIN' },
            { id_user: 10, id_sesi_absensi: 4, status: 'ALPHA' }
        ]);

        const { sheet } = await runExcelExport(generateLaporanKelasExcel, { params: { id: '1' }, user: admin });

        // 2 present of 5 sessions minus 1 excused = 50%
        expect(rowValues(sheet, 5)).toEqual([1, '1301', 'Budi', '✓', 'T', 'I', '✗', '✗', 2, '50%']);
    });
});
