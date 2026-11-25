const { z } = require('zod');
const { normalizePlate } = require('../utils/plate');
const { STATUS_KEHADIRAN } = require('../utils/akademikHelpers');

// The parsed output of these schemas replaces req.body (see validateZod), so every body field
// a controller reads MUST be declared here, otherwise it is stripped and arrives as undefined.

// Multipart bodies carry booleans as the strings "true"/"false". Do NOT use z.coerce.boolean():
// Boolean("false") === true, so it would turn every "false" into true.
const booleanLike = z.preprocess(
    (val) => (val === 'true' ? true : val === 'false' ? false : val),
    z.boolean()
);

// Auth Schemas
const registerSchema = z.object({
    nama: z.string().min(1, "Nama wajib diisi"),
    username: z.string()
        .min(3, "Username minimal 3 karakter")
        .max(30, "Username maksimal 30 karakter")
        .regex(/^[a-zA-Z][a-zA-Z0-9_]*$/, "Username harus diawali huruf dan hanya boleh berisi huruf, angka, dan garis bawah (_)"),
    password: z.string()
        .min(8, "Password minimal 8 karakter")
        .regex(/^(?=.*[A-Za-z])(?=.*\d)/, "Password harus mengandung minimal satu huruf dan satu angka"),
    // No `role`: public registration always creates a MAHASISWA (the controller never reads a role).
    // `email` must be declared here or the Zod output would strip it before the controller sees it.
    email: z.string().email().optional(),
    nim_nip: z.string()
        .regex(/^\d{11,12}$/, "NIM/NIP harus 11 atau 12 digit")
        .optional()
});

// Admin-created accounts: same fields and rules as public registration, plus an explicit role.
// This is the only place a DOSEN or ADMIN account can be created. The only difference from
// registerSchema is nim_nip: a student NIM keeps the 11-12 digit rule, but a lecturer / admin
// identifier may be an 18 digit NIP or a shorter NIDN, so those roles accept 8-20 digits
// (the DB column is VARCHAR(20)).
const adminCreateUserSchema = registerSchema
    .omit({ nim_nip: true })
    .extend({
        role: z.enum(['MAHASISWA', 'DOSEN', 'ADMIN']),
        nim_nip: z.string().optional()
    })
    .superRefine((data, ctx) => {
        if (data.nim_nip === undefined) return;
        const isStudent = data.role === 'MAHASISWA';
        const valid = isStudent ? /^\d{11,12}$/.test(data.nim_nip) : /^\d{8,20}$/.test(data.nim_nip);
        if (!valid) {
            ctx.addIssue({
                code: z.ZodIssueCode.custom,
                path: ['nim_nip'],
                message: isStudent ? "NIM/NIP harus 11 atau 12 digit" : "NIP/NIDN harus 8 sampai 20 digit"
            });
        }
    });

const loginSchema = z.object({
    username: z.string().min(1, "Username wajib diisi"),
    password: z.string().min(1, "Password wajib diisi")
});

const refreshTokenSchema = z.object({
    refresh_token: z.string().min(1, "Refresh token wajib diisi")
});

const updateProfileSchema = z.object({
    nama: z.string().min(1, "Nama wajib diisi")
});

const changePasswordSchema = z.object({
    oldPassword: z.string().min(1, "Password lama wajib diisi"),
    newPassword: z.string()
        .min(8, "Password minimal 8 karakter")
        .regex(/^(?=.*[A-Za-z])(?=.*\d)/, "Password harus mengandung minimal satu huruf dan satu angka")
});

const adminResetPasswordSchema = z.object({
    id_user: z.union([z.number(), z.string()]),
    new_password: z.string().min(8, "Password minimal 8 karakter")
});

const fcmTokenSchema = z.object({
    fcm_token: z.string()
        .min(100, "FCM token terlalu pendek")
        .max(300, "FCM token terlalu panjang")
        .regex(/^[a-zA-Z0-9:_\-]+$/, "Format FCM token tidak valid")
});

const forgotPasswordSchema = z.object({
    username: z.string().min(1, "Username wajib diisi")
});

const resetPasswordSchema = z.object({
    token: z.string().min(1, "Token wajib diisi"),
    newPassword: z.string()
        .min(8, "Password minimal 8 karakter")
        .regex(/^(?=.*[A-Za-z])(?=.*\d)/, "Password harus mengandung minimal satu huruf dan satu angka")
});

// Kendaraan Schemas
const registerKendaraanSchema = z.object({
    plat_nomor: z.string().min(1, "Plat nomor wajib diisi")
        .transform(normalizePlate)
        .refine(val => val.length > 0, "Plat nomor tidak valid"),
    nama_kendaraan: z.string().min(1, "Nama kendaraan wajib diisi")
});

const verifyKendaraanSchema = z.object({
    id_kendaraan: z.union([z.number(), z.string()]),
    id_user: z.union([z.number(), z.string()])
});

const rejectKendaraanSchema = z.object({
    id_kendaraan: z.union([z.number(), z.string()]),
    id_user: z.union([z.number(), z.string()]),
    feedback: z.string().min(1, "Alasan penolakan wajib diisi")
});

// Biometrik Schemas
const addBiometrikSchema = z.object({
    id_user: z.union([z.number(), z.string()])
});

// Multipart upload: numbers and booleans arrive as strings and are coerced here.
const biometrikAbsenSchema = z.object({
    latitude: z.coerce.number(),
    longitude: z.coerce.number(),
    id_sesi_absensi: z.coerce.number().int().positive().optional(),
    liveness_token: z.string().optional(),
    liveness_verified: booleanLike.optional(),
    is_mock_location: booleanLike.optional()
});

// Akademik Schemas
const createMatakuliahSchema = z.object({
    nama_matakuliah: z.string().min(1, "Nama matakuliah wajib diisi"),
    kode_matakuliah: z.string().min(1, "Kode matakuliah wajib diisi")
});

const createKelasSchema = z.object({
    id_matakuliah: z.union([z.number(), z.string()]),
    id_dosen: z.union([z.number(), z.string()]),
    jam_mulai: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$/, "Format jam mulai tidak valid (gunakan HH:MM:SS)"),
    jam_berakhir: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$/, "Format jam berakhir tidak valid (gunakan HH:MM:SS)"),
    nama_kelas: z.string().min(1, "Nama kelas wajib diisi"),
    ruangan: z.string().min(1, "Ruangan wajib diisi"),
    hari: z.union([z.number(), z.string()]).optional(),
    kapasitas: z.coerce.number().int("Kapasitas harus bilangan bulat").min(1, "Kapasitas minimal 1").optional()
});

const createJadwalPenggantiSchema = z.object({
    // No id_kelas: the class comes from the :id route parameter. The id_kelas the mobile app still
    // sends in the body is stripped here.
    tanggal_asli: z.string().min(1, "Tanggal asli wajib diisi"),
    status: z.string().min(1, "Status wajib diisi"),
    alasan: z.string().min(1, "Alasan wajib diisi"),
    tanggal_ganti: z.string().optional(),
    jam_mulai_ganti: z.string().optional(),
    jam_berakhir_ganti: z.string().optional(),
    ruangan_ganti: z.string().optional()
});

const daftarKelasSchema = z.object({
    id_kelas: z.union([z.number(), z.string()])
});

const adminAddPesertaSchema = z.object({
    id_kelas: z.union([z.number(), z.string()]),
    id_mahasiswa: z.union([
        z.number(),
        z.string(),
        z.array(z.union([z.number(), z.string()]))
    ])
});

const openAbsensiSchema = z.object({
    id_kelas: z.union([z.number(), z.string()]),
    mulai: z.string().min(1, "Waktu mulai wajib diisi"),
    selesai: z.string().min(1, "Waktu selesai wajib diisi"),
    latitude: z.union([z.number(), z.string()]).optional(),
    longitude: z.union([z.number(), z.string()]).optional(),
    radius_meter: z.union([z.number(), z.string()]).optional(),
    require_face: booleanLike.optional()
});

const createAbsensiSchema = z.object({
    id_kelas: z.union([z.number(), z.string()]),
    id_sesi_absensi: z.union([z.number(), z.string()]),
    latitude: z.union([z.number(), z.string()]),
    longitude: z.union([z.number(), z.string()]),
    is_mock_location: booleanLike.optional()
});

// PUT /absensi/sesi/:id/mahasiswa/:id_user - attendance status set by the DOSEN of the class or an ADMIN.
// The status check is a refine so its message is explicit (validateZod's fallback map would otherwise
// replace an enum error with the generic "status tidak valid").
const overrideAbsensiSchema = z.object({
    status: z.unknown().refine(
        (value) => STATUS_KEHADIRAN.includes(value),
        `Status harus salah satu dari ${STATUS_KEHADIRAN.join(', ')}`
    ),
    keterangan: z.string().max(255, "Keterangan maksimal 255 karakter").nullable().optional()
});

module.exports = {
    registerSchema,
    adminCreateUserSchema,
    loginSchema,
    refreshTokenSchema,
    updateProfileSchema,
    changePasswordSchema,
    adminResetPasswordSchema,
    forgotPasswordSchema,
    resetPasswordSchema,
    fcmTokenSchema,
    registerKendaraanSchema,
    verifyKendaraanSchema,
    rejectKendaraanSchema,
    addBiometrikSchema,
    biometrikAbsenSchema,
    createMatakuliahSchema,
    createKelasSchema,
    createJadwalPenggantiSchema,
    daftarKelasSchema,
    adminAddPesertaSchema,
    openAbsensiSchema,
    createAbsensiSchema,
    overrideAbsensiSchema
};
