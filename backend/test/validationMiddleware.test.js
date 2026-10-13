const { z } = require('zod');
const { validateZod } = require('../middlewares/validationMiddleware');
const schemas = require('../middlewares/zodSchemas');

const createRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

// Runs a schema through validateZod and returns what the next handler would see.
const run = async (schema, body) => {
    const req = { body };
    const res = createRes();
    const next = jest.fn();
    await validateZod(schema)(req, res, next);
    return { req, res, next };
};

describe('validateZod', () => {
    test('is exported once and writes the parsed output back to req.body', async () => {
        const { req, res, next } = await run(schemas.registerKendaraanSchema, {
            plat_nomor: 'b 1234-xyz',
            nama_kendaraan: 'Honda Beat'
        });

        expect(next).toHaveBeenCalledTimes(1);
        expect(next).toHaveBeenCalledWith();
        expect(res.status).not.toHaveBeenCalled();
        expect(req.body.plat_nomor).toBe('B1234XYZ');
        expect(req.body.nama_kendaraan).toBe('Honda Beat');
    });

    test('strips fields that the schema does not declare', async () => {
        const { req, next } = await run(schemas.loginSchema, {
            username: 'budi',
            password: 'Rahasia123',
            role: 'ADMIN',
            isAdmin: true
        });

        expect(next).toHaveBeenCalledTimes(1);
        expect(req.body).toEqual({ username: 'budi', password: 'Rahasia123' });
    });

    test('rejects an invalid body with 400 and joined messages', async () => {
        const { res, next } = await run(schemas.loginSchema, { username: '', password: '' });

        expect(next).not.toHaveBeenCalled();
        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith({
            status: 'error',
            message: 'Username wajib diisi, Password wajib diisi'
        });
    });

    test('names the missing field in Indonesian when the schema has no custom message', async () => {
        const { res } = await run(schemas.daftarKelasSchema, {});

        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith({
            status: 'error',
            message: 'id_kelas wajib diisi'
        });
    });

    test('rejects a missing body (Express 5 leaves req.body undefined)', async () => {
        const { res, next } = await run(schemas.loginSchema, undefined);

        expect(next).not.toHaveBeenCalled();
        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json.mock.calls[0][0].status).toBe('error');
    });

    test('rejects a plate that is empty once normalised', async () => {
        const { res, next } = await run(schemas.registerKendaraanSchema, {
            plat_nomor: '---',
            nama_kendaraan: 'Honda Beat'
        });

        expect(next).not.toHaveBeenCalled();
        expect(res.status).toHaveBeenCalledWith(400);
    });

    test('supports async refinements', async () => {
        const schema = z.object({ code: z.string() }).refine(async (v) => v.code === 'ok', 'Kode salah');
        const { res, next } = await run(schema, { code: 'nope' });

        expect(next).not.toHaveBeenCalled();
        expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Kode salah' });
    });

    test('reads messages from error.issues when error.errors is absent (zod v4 shape)', async () => {
        const v4Error = new Error('boom');
        v4Error.issues = [{ message: 'Pesan satu' }, { message: 'Pesan dua' }];
        const schema = { parseAsync: jest.fn().mockRejectedValue(v4Error) };
        const { res, next } = await run(schema, {});

        expect(next).not.toHaveBeenCalled();
        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Pesan satu, Pesan dua' });
    });

    test('reads messages from error.errors when error.issues is absent', async () => {
        const legacyError = new Error('boom');
        legacyError.errors = [{ message: 'Satu' }, { message: 'Dua' }];
        const schema = { parseAsync: jest.fn().mockRejectedValue(legacyError) };
        const { res } = await run(schema, {});

        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith({ status: 'error', message: 'Satu, Dua' });
    });

    test('forwards unexpected (non-validation) errors to next', async () => {
        const boom = new Error('database down');
        const schema = { parseAsync: jest.fn().mockRejectedValue(boom) };
        const { res, next } = await run(schema, {});

        expect(res.status).not.toHaveBeenCalled();
        expect(next).toHaveBeenCalledWith(boom);
    });
});

// Zod output is authoritative, so any req.body field a controller reads but its schema omits
// silently becomes undefined. Each sample body below contains every field the consuming
// controller destructures from req.body and must come out of validation with all keys intact.
const longFcmToken = 'a1b2c3d4:' + 'x'.repeat(120);
const jam = { mulai: '2026-10-14T01:00:00.000Z', selesai: '2026-10-14T03:00:00.000Z' };

const schemaCases = [
    {
        schema: 'registerSchema',
        consumer: 'authController.register',
        body: { nama: 'Budi', username: 'budi_1', password: 'Rahasia123', role: 'MAHASISWA', nim_nip: '13012100012' }
    },
    {
        schema: 'loginSchema',
        consumer: 'authController.login',
        body: { username: 'budi_1', password: 'Rahasia123' }
    },
    {
        schema: 'refreshTokenSchema',
        consumer: 'authController.refreshToken',
        body: { refresh_token: 'refresh-token-value' }
    },
    {
        schema: 'updateProfileSchema',
        consumer: 'authController.updateProfile',
        body: { nama: 'Budi Santoso' }
    },
    {
        schema: 'changePasswordSchema',
        consumer: 'authController.changePassword',
        body: { oldPassword: 'Rahasia123', newPassword: 'Baru12345' }
    },
    {
        schema: 'adminResetPasswordSchema',
        consumer: 'authController.adminResetPassword',
        body: { id_user: 7, new_password: 'Baru12345' }
    },
    {
        schema: 'forgotPasswordSchema',
        consumer: 'authController.requestPasswordReset',
        body: { username: 'budi_1' }
    },
    {
        schema: 'resetPasswordSchema',
        consumer: 'authController.resetPasswordWithToken',
        body: { token: 'reset-token', newPassword: 'Baru12345' }
    },
    {
        schema: 'fcmTokenSchema',
        consumer: 'authController.registerFcmToken',
        body: { fcm_token: longFcmToken }
    },
    {
        schema: 'registerKendaraanSchema',
        consumer: 'kendaraanController.registerKendaraan (multipart)',
        body: { plat_nomor: 'd 5678-abc', nama_kendaraan: 'Honda Beat' },
        expected: { plat_nomor: 'D5678ABC', nama_kendaraan: 'Honda Beat' }
    },
    {
        schema: 'verifyKendaraanSchema',
        consumer: 'kendaraanController.verifyKendaraan',
        body: { id_kendaraan: 3, id_user: '9' }
    },
    {
        schema: 'rejectKendaraanSchema',
        consumer: 'kendaraanController.rejectKendaraan',
        body: { id_kendaraan: 3, id_user: 9, feedback: 'Foto STNK buram' }
    },
    {
        schema: 'addBiometrikSchema',
        consumer: 'biometrikController.addBiometrik',
        body: { id_user: 9 }
    },
    {
        // multipart: every value is a string, is_mock_location must come out as a real boolean
        schema: 'biometrikAbsenSchema',
        consumer: 'biometrikController.biometrikAbsen (multipart)',
        body: {
            latitude: '-6.97',
            longitude: '107.63',
            id_sesi_absensi: '12',
            liveness_token: 'liveness-token',
            is_mock_location: 'false'
        },
        expected: {
            latitude: -6.97,
            longitude: 107.63,
            id_sesi_absensi: 12,
            liveness_token: 'liveness-token',
            is_mock_location: false
        }
    },
    {
        schema: 'createMatakuliahSchema',
        consumer: 'akademikController.createMatakuliah',
        body: { nama_matakuliah: 'Pemrograman Web', kode_matakuliah: 'IF1234' }
    },
    {
        schema: 'createKelasSchema',
        consumer: 'akademikController.createKelas',
        body: {
            id_matakuliah: 1,
            id_dosen: 2,
            jam_mulai: '08:00:00',
            jam_berakhir: '10:00:00',
            nama_kelas: 'IF-01',
            ruangan: 'A101',
            hari: 3,
            kapasitas: 40
        }
    },
    {
        schema: 'createJadwalPenggantiSchema',
        consumer: 'akademikController.createJadwalPengganti',
        body: {
            id_kelas: 5,
            tanggal_asli: '2026-10-14',
            status: 'GANTI_JADWAL',
            alasan: 'Dosen dinas luar',
            tanggal_ganti: '2026-10-16',
            jam_mulai_ganti: '09:00:00',
            jam_berakhir_ganti: '11:00:00',
            ruangan_ganti: 'B202'
        }
    },
    {
        schema: 'daftarKelasSchema',
        consumer: 'akademikController.daftarKelas',
        body: { id_kelas: 5 }
    },
    {
        schema: 'adminAddPesertaSchema',
        consumer: 'akademikController.adminAddPeserta',
        body: { id_kelas: 5, id_mahasiswa: [11, '12'] }
    },
    {
        schema: 'openAbsensiSchema',
        consumer: 'akademikController.openAbsensi',
        body: {
            id_kelas: 5,
            ...jam,
            latitude: -6.97,
            longitude: 107.63,
            radius_meter: 100,
            require_face: true
        }
    },
    {
        schema: 'createAbsensiSchema',
        consumer: 'akademikController.createAbsensi',
        body: {
            id_kelas: 5,
            id_sesi_absensi: 21,
            latitude: -6.97,
            longitude: 107.63,
            is_mock_location: true
        }
    }
];

describe('zodSchemas keep every field its controller reads', () => {
    it('covers every schema exported by zodSchemas.js', () => {
        expect(schemaCases.map((c) => c.schema).sort()).toEqual(Object.keys(schemas).sort());
    });

    it.each(schemaCases.map((c) => [c.schema, c.consumer, c]))('%s (%s)', async (name, consumer, testCase) => {
        const { req, res, next } = await run(schemas[name], testCase.body);

        expect(res.status).not.toHaveBeenCalled();
        expect(next).toHaveBeenCalledWith();
        const expected = testCase.expected || testCase.body;
        for (const key of Object.keys(testCase.body)) {
            expect(req.body).toHaveProperty(key);
        }
        expect(req.body).toEqual(expected);
    });
});

describe('zodSchemas boolean and numeric coercion', () => {
    const absen = (extra) => ({ id_kelas: 5, id_sesi_absensi: 21, latitude: -6.97, longitude: 107.63, ...extra });

    test.each([
        ['true', true],
        ['false', false],
        [true, true],
        [false, false]
    ])('is_mock_location %j becomes boolean %j (never Boolean("false") === true)', async (input, output) => {
        const { req, next } = await run(schemas.createAbsensiSchema, absen({ is_mock_location: input }));

        expect(next).toHaveBeenCalledTimes(1);
        expect(req.body.is_mock_location).toBe(output);
    });

    test('is_mock_location is optional', async () => {
        const { req, next } = await run(schemas.createAbsensiSchema, absen({}));

        expect(next).toHaveBeenCalledTimes(1);
        expect(req.body).not.toHaveProperty('is_mock_location');
    });

    test('rejects an is_mock_location value that is neither a boolean nor "true"/"false"', async () => {
        const { res, next } = await run(schemas.createAbsensiSchema, absen({ is_mock_location: 'maybe' }));

        expect(next).not.toHaveBeenCalled();
        expect(res.status).toHaveBeenCalledWith(400);
    });

    test.each([
        ['true', true],
        ['false', false]
    ])('openAbsensi require_face %j becomes boolean %j', async (input, output) => {
        const { req } = await run(schemas.openAbsensiSchema, {
            id_kelas: 5,
            ...jam,
            require_face: input
        });

        expect(req.body.require_face).toBe(output);
    });

    test('kapasitas arrives as a string and is coerced to a number', async () => {
        const { req, next } = await run(schemas.createKelasSchema, {
            id_matakuliah: 1,
            id_dosen: 2,
            jam_mulai: '08:00:00',
            jam_berakhir: '10:00:00',
            nama_kelas: 'IF-01',
            ruangan: 'A101',
            kapasitas: '40'
        });

        expect(next).toHaveBeenCalledTimes(1);
        expect(req.body.kapasitas).toBe(40);
    });

    test('kapasitas is optional but must be a positive whole number when given', async () => {
        const base = {
            id_matakuliah: 1,
            id_dosen: 2,
            jam_mulai: '08:00:00',
            jam_berakhir: '10:00:00',
            nama_kelas: 'IF-01',
            ruangan: 'A101'
        };
        const omitted = await run(schemas.createKelasSchema, base);
        expect(omitted.next).toHaveBeenCalledTimes(1);
        expect(omitted.req.body).not.toHaveProperty('kapasitas');

        for (const bad of [0, -5, 'abc', 12.5]) {
            const { res, next } = await run(schemas.createKelasSchema, { ...base, kapasitas: bad });
            expect(next).not.toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(400);
        }
    });
});
