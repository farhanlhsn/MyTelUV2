/**
 * PUT /api/v1/akademik/absensi/sesi/:id/mahasiswa/:id_user — the dosen of the class (or an admin) sets a
 * student's attendance status by hand (e.g. while the face service is down). Route level: the real
 * route file, validation and controller run; Prisma, the audit log and Firebase are mocked.
 */
process.env.JWT_SECRET = 'test_secret';

jest.mock('../utils/prisma', () => ({
    user: { findUnique: jest.fn() },
    sesiAbsensi: { findFirst: jest.fn() },
    pesertaKelas: { findFirst: jest.fn() },
    absensi: { findUnique: jest.fn() },
    $transaction: jest.fn(),
    $queryRaw: jest.fn(),
    $executeRaw: jest.fn(),
}));

jest.mock('../utils/auditLogger', () => ({
    logAudit: jest.fn(),
    BIOMETRIK_ACTIONS: {},
}));

jest.mock('../utils/firebase', () => ({
    sendAbsensiNotification: jest.fn().mockResolvedValue(undefined),
    sendJadwalPenggantiNotification: jest.fn().mockResolvedValue(undefined),
}));

const express = require('express');
const jwt = require('jsonwebtoken');
const request = require('supertest');
const prisma = require('../utils/prisma');
const { logAudit } = require('../utils/auditLogger');
const akademikRoutes = require('../routes/akademikRoutes');

const app = express();
app.use(express.json());
app.use('/api/v1/akademik', akademikRoutes);
app.use((err, req, res, next) => res.status(err.statusCode || 500).json({ status: 'error', message: err.message }));

const OWN_DOSEN = { id_user: 5, role: 'DOSEN' };
const OTHER_DOSEN = { id_user: 6, role: 'DOSEN' };
const ADMIN = { id_user: 1, role: 'ADMIN' };
const MAHASISWA = { id_user: 10, role: 'MAHASISWA' };

const SESI = {
    id_sesi_absensi: 12,
    id_kelas: 3,
    type_absensi: 'REMOTE_ABSENSI',
    mulai: new Date('2026-10-14T01:00:00Z'),
    selesai: new Date('2026-10-14T03:00:00Z'),
    status: false,
    deletedAt: null,
    kelas: { id_kelas: 3, id_dosen: 5, nama_kelas: 'IF-01', deletedAt: null }
};

const url = (idSesi = 12, idUser = 10) => `/api/v1/akademik/absensi/sesi/${idSesi}/mahasiswa/${idUser}`;

const as = ({ id_user, role }) => {
    prisma.user.findUnique.mockResolvedValue({ id_user, username: 'u', nama: 'U', role, nim_nip: null });
    return { Authorization: `Bearer ${jwt.sign({ id: id_user }, process.env.JWT_SECRET)}` };
};

// Tagged-template raw calls whose SQL text contains `needle`
const rawCalls = (needle) =>
    prisma.$queryRaw.mock.calls.filter(([strings]) => Array.isArray(strings) && strings.join('?').includes(needle));

// Results of the successive UPDATE (existing record) and INSERT (new record) statements; [] = no row
const mockRows = ({ updates = [[{ id_absensi: 77, status_lama: 'HADIR', deleted_lama: null }]], inserts = [] } = {}) => {
    const updateResults = [...updates];
    const insertResults = [...inserts];
    prisma.$queryRaw.mockImplementation(async (strings) => {
        const sql = strings.join('?');
        if (sql.includes('UPDATE absensi')) return updateResults.length ? updateResults.shift() : [];
        if (sql.includes('INSERT INTO absensi')) return insertResults.length ? insertResults.shift() : [];
        return [];
    });
};

beforeEach(() => {
    jest.clearAllMocks();
    prisma.$transaction.mockImplementation(async (fn) => fn(prisma));
    prisma.sesiAbsensi.findFirst.mockResolvedValue(SESI);
    prisma.pesertaKelas.findFirst.mockResolvedValue({ id_mahasiswa: 10, id_kelas: 3, deletedAt: null });
    prisma.absensi.findUnique.mockImplementation(async ({ where }) => ({
        id_absensi: where.id_absensi,
        id_user: 10,
        id_kelas: 3,
        id_sesi_absensi: 12,
        type_absensi: 'REMOTE_ABSENSI',
        status: 'IZIN',
        keterangan: 'Surat izin orang tua',
        diubah_oleh: 5
    }));
    mockRows();
});

describe('PUT /absensi/sesi/:id/mahasiswa/:id_user (dosen override)', () => {
    test('the dosen of the class sets IZIN: 200 with the updated absensi and an ABSENSI_OVERRIDE audit entry', async () => {
        mockRows({ updates: [[{ id_absensi: 77, status_lama: 'ALPHA', deleted_lama: null }]] });

        const res = await request(app)
            .put(url())
            .set(as(OWN_DOSEN))
            .send({ status: 'IZIN', keterangan: 'Surat izin orang tua' });

        expect(res.status).toBe(200);
        expect(res.body.status).toBe('success');
        expect(res.body.data).toMatchObject({ id_absensi: 77, id_user: 10, id_sesi_absensi: 12, status: 'IZIN', diubah_oleh: 5 });
        expect(prisma.absensi.findUnique).toHaveBeenCalledWith(expect.objectContaining({ where: { id_absensi: 77 } }));

        expect(logAudit).toHaveBeenCalledTimes(1);
        const entry = logAudit.mock.calls[0][0];
        expect(entry).toMatchObject({ action: 'ABSENSI_OVERRIDE', performedBy: 5, targetUserId: 10 });
        expect(entry.details).toContain('ALPHA');
        expect(entry.details).toContain('IZIN');
        expect(entry.details).toContain('12');
    });

    test('an existing record is locked, updated and its previous status returned by one statement', async () => {
        await request(app).put(url()).set(as(OWN_DOSEN)).send({ status: 'SAKIT', keterangan: 'Demam' });

        expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function));
        const [update] = rawCalls('UPDATE absensi');
        const sql = update[0].join('?');
        expect(sql).toMatch(/FOR UPDATE/);
        expect(sql).toMatch(/RETURNING[\s\S]*status_lama/);
        expect(sql).toMatch(/"deletedAt" = NULL/);
        expect(update.slice(1)).toEqual(expect.arrayContaining(['SAKIT', 'Demam', 5, 10, 12]));
        expect(rawCalls('INSERT INTO absensi')).toHaveLength(0);
        expect(logAudit.mock.calls[0][0].details).toMatch(/status_lama=HADIR status_baru=SAKIT/);
    });

    test('a student without any record gets one; the audit shows there was no previous status', async () => {
        mockRows({ updates: [[]], inserts: [[{ id_absensi: 78 }]] });

        const res = await request(app).put(url()).set(as(OWN_DOSEN)).send({ status: 'HADIR' });

        expect(res.status).toBe(200);
        expect(prisma.absensi.findUnique).toHaveBeenCalledWith(expect.objectContaining({ where: { id_absensi: 78 } }));
        expect(logAudit.mock.calls[0][0].details).toMatch(/status_lama=- /);
        const [insert] = rawCalls('INSERT INTO absensi');
        expect(insert[0].join('?')).toMatch(/ON CONFLICT \(id_user, id_sesi_absensi\) DO NOTHING/);
        // keterangan omitted: stored as NULL
        expect(insert.slice(1)).toEqual(expect.arrayContaining([10, 3, 12, 'HADIR', null, 5]));
    });

    test('a check-in committed between the update and the insert is updated and audited as the old status', async () => {
        // The UPDATE finds nothing, the INSERT loses to the check-in (DO NOTHING), the retried UPDATE finds it
        mockRows({
            updates: [[], [{ id_absensi: 80, status_lama: 'TELAT', deleted_lama: null }]],
            inserts: [[]]
        });

        const res = await request(app).put(url()).set(as(OWN_DOSEN)).send({ status: 'ALPHA' });

        expect(res.status).toBe(200);
        expect(rawCalls('UPDATE absensi')).toHaveLength(2);
        expect(prisma.absensi.findUnique).toHaveBeenCalledWith(expect.objectContaining({ where: { id_absensi: 80 } }));
        expect(logAudit.mock.calls[0][0].details).toMatch(/status_lama=TELAT status_baru=ALPHA/);
    });

    test('a soft-deleted record is restored; its old status is not reported as current', async () => {
        mockRows({ updates: [[{ id_absensi: 77, status_lama: 'HADIR', deleted_lama: new Date('2026-10-14T02:00:00Z') }]] });

        const res = await request(app).put(url()).set(as(OWN_DOSEN)).send({ status: 'IZIN' });

        expect(res.status).toBe(200);
        expect(logAudit.mock.calls[0][0].details).toMatch(/status_lama=- /);
    });

    test('the audit entry is written right after the commit, before the record is read back', async () => {
        await request(app).put(url()).set(as(OWN_DOSEN)).send({ status: 'IZIN' });

        expect(logAudit).toHaveBeenCalledTimes(1);
        expect(logAudit.mock.invocationCallOrder[0]).toBeLessThan(prisma.absensi.findUnique.mock.invocationCallOrder[0]);
    });

    test('an admin may override any class', async () => {
        const res = await request(app).put(url()).set(as(ADMIN)).send({ status: 'ALPHA' });

        expect(res.status).toBe(200);
        expect(logAudit.mock.calls[0][0]).toMatchObject({ action: 'ABSENSI_OVERRIDE', performedBy: 1 });
    });

    test('a dosen of another class gets 403 and nothing is written or audited', async () => {
        const res = await request(app).put(url()).set(as(OTHER_DOSEN)).send({ status: 'IZIN' });

        expect(res.status).toBe(403);
        expect(res.body.status).toBe('error');
        expect(prisma.$transaction).not.toHaveBeenCalled();
        expect(rawCalls('INSERT INTO absensi')).toHaveLength(0);
        expect(rawCalls('UPDATE absensi')).toHaveLength(0);
        expect(logAudit).not.toHaveBeenCalled();
    });

    test('a mahasiswa gets 403', async () => {
        const res = await request(app).put(url()).set(as(MAHASISWA)).send({ status: 'HADIR' });

        expect(res.status).toBe(403);
        expect(prisma.sesiAbsensi.findFirst).not.toHaveBeenCalled();
    });

    test('a student who is not enrolled in the class is 404', async () => {
        prisma.pesertaKelas.findFirst.mockResolvedValue(null);

        const res = await request(app).put(url()).set(as(OWN_DOSEN)).send({ status: 'IZIN' });

        expect(res.status).toBe(404);
        expect(res.body.message).toBe('Mahasiswa tidak terdaftar di kelas ini');
        expect(prisma.pesertaKelas.findFirst).toHaveBeenCalledWith(expect.objectContaining({
            where: expect.objectContaining({ id_kelas: 3, id_mahasiswa: 10, deletedAt: null })
        }));
        expect(rawCalls('INSERT INTO absensi')).toHaveLength(0);
        expect(rawCalls('UPDATE absensi')).toHaveLength(0);
        expect(logAudit).not.toHaveBeenCalled();
    });

    test('an unknown or deleted session is 404', async () => {
        prisma.sesiAbsensi.findFirst.mockResolvedValue(null);

        const res = await request(app).put(url(99)).set(as(OWN_DOSEN)).send({ status: 'IZIN' });

        expect(res.status).toBe(404);
        expect(prisma.sesiAbsensi.findFirst).toHaveBeenCalledWith(expect.objectContaining({
            where: expect.objectContaining({ id_sesi_absensi: 99, deletedAt: null })
        }));
    });

    test.each([
        ['an unknown status', { status: 'BOLOS' }],
        ['a lower-case status', { status: 'izin' }],
        ['a missing status', { keterangan: 'x' }],
        ['a keterangan over 255 characters', { status: 'IZIN', keterangan: 'a'.repeat(256) }]
    ])('%s is 400 before anything is read', async (_label, body) => {
        const res = await request(app).put(url()).set(as(OWN_DOSEN)).send(body);

        expect(res.status).toBe(400);
        expect(res.body.status).toBe('error');
        expect(prisma.sesiAbsensi.findFirst).not.toHaveBeenCalled();
        expect(logAudit).not.toHaveBeenCalled();
    });

    test('non-numeric ids are 400', async () => {
        const res = await request(app).put('/api/v1/akademik/absensi/sesi/abc/mahasiswa/10').set(as(OWN_DOSEN)).send({ status: 'IZIN' });

        expect(res.status).toBe(400);
        expect(prisma.sesiAbsensi.findFirst).not.toHaveBeenCalled();
    });
});
