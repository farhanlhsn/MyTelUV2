const { z } = require('zod');

// Auth Schemas
const registerSchema = z.object({
    nama: z.string().min(1, "Nama is required"),
    username: z.string()
        .min(3, "Username must be at least 3 characters")
        .max(30, "Username max 30 characters")
        .regex(/^[a-zA-Z][a-zA-Z0-9_]*$/, "Username must start with a letter and contain only letters, numbers, and underscores"),
    password: z.string()
        .min(6, "Password must be at least 6 characters")
        .regex(/^(?=.*[A-Za-z])(?=.*\d)/, "Password must contain at least one letter and one number"),
    role: z.enum(['MAHASISWA', 'DOSEN']).optional()
});

const loginSchema = z.object({
    username: z.string().min(1, "Username is required"),
    password: z.string().min(1, "Password is required")
});

const updateProfileSchema = z.object({
    nama: z.string().min(1, "Nama is required")
});

const changePasswordSchema = z.object({
    oldPassword: z.string().min(1, "Old password is required"),
    newPassword: z.string()
        .min(6, "New password must be at least 6 characters")
        .regex(/^(?=.*[A-Za-z])(?=.*\d)/, "Password must contain at least one letter and one number")
});

const adminResetPasswordSchema = z.object({
    id_user: z.union([z.number(), z.string()]),
    new_password: z.string().min(6, "New password must be at least 6 characters")
});

const fcmTokenSchema = z.object({
    fcm_token: z.string()
        .min(100, "FCM token too short")
        .max(300, "FCM token too long")
        .regex(/^[a-zA-Z0-9:_\-]+$/, "Invalid FCM token format")
});

// Kendaraan Schemas
const registerKendaraanSchema = z.object({
    plat_nomor: z.string().min(1, "Plat nomor is required")
        .transform(val => val.toUpperCase().replace(/[\s\-]/g, '')),
    nama_kendaraan: z.string().min(1, "Nama kendaraan is required")
});

const verifyKendaraanSchema = z.object({
    id_kendaraan: z.union([z.number(), z.string()]),
    id_user: z.union([z.number(), z.string()])
});

const rejectKendaraanSchema = z.object({
    id_kendaraan: z.union([z.number(), z.string()]),
    id_user: z.union([z.number(), z.string()]),
    feedback: z.string().min(1, "Feedback is required")
});

// Biometrik Schemas
const addBiometrikSchema = z.object({
    id_user: z.union([z.number(), z.string()])
});

const biometrikAbsenSchema = z.object({
    latitude: z.union([z.number(), z.string()]),
    longitude: z.union([z.number(), z.string()]),
    id_sesi_absensi: z.union([z.number(), z.string()]).optional()
});

// Akademik Schemas
const createMatakuliahSchema = z.object({
    nama_matakuliah: z.string().min(1, "Nama matakuliah is required"),
    kode_matakuliah: z.string().min(1, "Kode matakuliah is required")
});

const createKelasSchema = z.object({
    id_matakuliah: z.union([z.number(), z.string()]),
    id_dosen: z.union([z.number(), z.string()]),
    jam_mulai: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$/, "Invalid time format"),
    jam_berakhir: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$/, "Invalid time format"),
    nama_kelas: z.string().min(1, "Nama kelas is required"),
    ruangan: z.string().min(1, "Ruangan is required"),
    hari: z.union([z.number(), z.string()]).optional()
});

const createJadwalPenggantiSchema = z.object({
    tanggal_asli: z.string().min(1, "Tanggal asli is required"),
    status: z.string().min(1, "Status is required"),
    alasan: z.string().min(1, "Alasan is required"),
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
    mulai: z.string().min(1, "Waktu mulai is required"),
    selesai: z.string().min(1, "Waktu selesai is required"),
    latitude: z.union([z.number(), z.string()]).optional(),
    longitude: z.union([z.number(), z.string()]).optional(),
    radius_meter: z.union([z.number(), z.string()]).optional(),
    require_face: z.boolean().or(z.string()).optional()
});

const createAbsensiSchema = z.object({
    id_kelas: z.union([z.number(), z.string()]),
    id_sesi_absensi: z.union([z.number(), z.string()]),
    latitude: z.union([z.number(), z.string()]),
    longitude: z.union([z.number(), z.string()])
});

module.exports = {
    registerSchema,
    loginSchema,
    updateProfileSchema,
    changePasswordSchema,
    adminResetPasswordSchema,
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
    createAbsensiSchema
};
