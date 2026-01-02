const express = require('express');
const {
    // Matakuliah
    createMatakuliah,
    getAllMatakuliah,
    getMatakuliahById,
    updateMatakuliah,
    deleteMatakuliah,

    // Kelas
    createKelas,
    getAllKelas,
    getKelasByDosen,
    getKelasHariIni,
    getKelasWithHari,
    getKelasById,
    updateKelas,
    deleteAllKelas,
    deleteKelas,

    // Peserta Kelas
    daftarKelas,
    dropKelas,
    getKelasKu,
    getPesertaKelas,
    adminAddPeserta,

    // Absensi
    openAbsensi,
    createAbsensi,
    getAbsensiKu,
    getAbsensiKelas,
    getAbsensiStats,

    // Sesi Absensi
    getSesiAbsensiByKelas,
    getSesiAbsensiDetail,
    closeSesiAbsensi,
    getAbsensiKuWithHistory,

    // Jadwal Pengganti
    createJadwalPengganti,
    getJadwalPenggantiByKelas,
    deleteJadwalPengganti
} = require('../controllers/akademikController');

const { validateRequired } = require('../middlewares/validationMiddleware');
const { protect, authorize } = require('../middlewares/authMiddleware');

const {
    generateLaporanSesiPdf,
    generateLaporanKelasPdf
} = require('../controllers/laporanController');

const router = express.Router();

// ==================== LAPORAN ROUTES ====================
// PDF Report for Sessions
router.get('/laporan/sesi/:id/pdf', protect, authorize('DOSEN', 'ADMIN'), generateLaporanSesiPdf);

// PDF Report for Class Recap
router.get('/laporan/kelas/:id/pdf', protect, authorize('DOSEN', 'ADMIN'), generateLaporanKelasPdf);


// ==================== MATAKULIAH ROUTES ====================

router.post('/matakuliah',
    protect,
    authorize('ADMIN'),
    validateRequired(['nama_matakuliah', 'kode_matakuliah']),
    createMatakuliah
);

router.get('/matakuliah',
    protect,
    getAllMatakuliah
);

router.get('/matakuliah/:id',
    protect,
    getMatakuliahById
);

router.put('/matakuliah/:id',
    protect,
    authorize('ADMIN'),
    updateMatakuliah
);

router.delete('/matakuliah/:id',
    protect,
    authorize('ADMIN'),
    deleteMatakuliah
);

// ==================== KELAS ROUTES ====================
router.post('/kelas',
    protect,
    authorize('ADMIN', 'DOSEN'),
    validateRequired(['id_matakuliah', 'id_dosen', 'jam_mulai', 'jam_berakhir', 'nama_kelas', 'ruangan']),
    createKelas
);

router.get('/kelas',
    protect,
    getAllKelas
);

router.get('/kelas/dosen',
    protect,
    authorize('DOSEN'),
    getKelasByDosen
);

// Get kelas yang berlangsung hari ini (filtered by user role)
router.get('/kelas/hari-ini',
    protect,
    getKelasHariIni
);

// Get all kelas with hari info grouped by day (for weekly schedule)
router.get('/kelas/jadwal-mingguan',
    protect,
    getKelasWithHari
);

// ==================== JADWAL PENGGANTI ROUTES ====================

// Create jadwal pengganti (LIBUR or GANTI_JADWAL)
router.post('/kelas/:id/jadwal-pengganti',
    protect,
    authorize('DOSEN', 'ADMIN'),
    validateRequired(['tanggal_asli', 'status', 'alasan']),
    createJadwalPengganti
);

// Get jadwal pengganti by kelas
router.get('/kelas/:id/jadwal-pengganti',
    protect,
    getJadwalPenggantiByKelas
);

// Delete jadwal pengganti
router.delete('/jadwal-pengganti/:id',
    protect,
    authorize('DOSEN', 'ADMIN'),
    deleteJadwalPengganti
);


// Delete ALL kelas (ADMIN ONLY)
router.delete('/kelas/delete-all',
    protect,
    authorize('ADMIN'),
    deleteAllKelas
);

// Delete kelas (ID specific)
router.delete('/kelas/:id',
    protect,
    authorize('ADMIN', 'DOSEN'), // Dosen can only delete their own class (checked in controller)
    deleteKelas
);

// ==================== PESERTA KELAS ROUTES ====================
// PENTING: Routes dengan path spesifik harus di atas routes dengan params (:id)
router.get('/kelas/ku',
    protect,
    authorize('MAHASISWA'),
    getKelasKu
);

router.post('/kelas/daftar',
    protect,
    authorize('MAHASISWA'),
    validateRequired(['id_kelas']),
    daftarKelas
);

router.delete('/kelas/:id/drop',
    protect,
    authorize('MAHASISWA'),
    dropKelas
);

// Routes dengan :id harus di bawah routes dengan path spesifik
router.get('/kelas/:id',
    protect,
    getKelasById
);

router.put('/kelas/:id',
    protect,
    authorize('ADMIN', 'DOSEN'),
    updateKelas
);

router.delete('/kelas/:id',
    protect,
    authorize('ADMIN', 'DOSEN'),
    deleteKelas
);

router.get('/kelas/:id/peserta',
    protect,
    authorize('DOSEN', 'ADMIN'),
    getPesertaKelas
);

router.post('/kelas/peserta/add',
    protect,
    authorize('ADMIN'),
    validateRequired(['id_kelas', 'id_mahasiswa']),
    adminAddPeserta
);

//TODO: Route untuk GET kelas hari ini

// ==================== ABSENSI ROUTES ====================
router.post('/open-absensi',
    protect,
    authorize('DOSEN', 'ADMIN'),
    validateRequired(['id_kelas', 'type_absensi', 'mulai', 'selesai']),
    openAbsensi
);

router.post('/absensi',
    protect,
    authorize('MAHASISWA'),
    validateRequired(['id_kelas', 'id_sesi_absensi', 'latitude', 'longitude']),
    createAbsensi
);

router.get('/absensi/ku',
    protect,
    getAbsensiKu
);

router.get('/absensi/kelas/:id',
    protect,
    authorize('DOSEN', 'ADMIN'),
    getAbsensiKelas
);

router.get('/absensi/kelas/:id/stats',
    protect,
    authorize('DOSEN', 'ADMIN'),
    getAbsensiStats
);

// ==================== SESI ABSENSI ROUTES ====================
// Get all sesi absensi for a kelas
router.get('/kelas/:id/sesi',
    protect,
    authorize('DOSEN', 'ADMIN'),
    getSesiAbsensiByKelas
);

// Get attendance detail for a specific sesi
router.get('/absensi/sesi/:id',
    protect,
    authorize('DOSEN', 'ADMIN'),
    getSesiAbsensiDetail
);

// Close a sesi absensi
router.put('/absensi/sesi/:id/close',
    protect,
    authorize('DOSEN', 'ADMIN'),
    closeSesiAbsensi
);

// Get mahasiswa attendance history with all sessions
router.get('/absensi/ku/history',
    protect,
    getAbsensiKuWithHistory
);

module.exports = router;
