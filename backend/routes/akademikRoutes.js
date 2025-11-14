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
    getKelasById,
    updateKelas,
    deleteKelas,
    
    // Peserta Kelas
    daftarKelas,
    dropKelas,
    getKelasKu,
    getPesertaKelas,
    
    // Absensi
    openAbsensi,
    createAbsensi,
    getAbsensiKu,
    getAbsensiKelas,
    getAbsensiStats
} = require('../controllers/akademikController');

const { validateRequired } = require('../middlewares/validationMiddleware');
const { protect, authorize } = require('../middlewares/authMiddleware');

const router = express.Router();

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

// ==================== PESERTA KELAS ROUTES ====================
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

router.get('/kelas/ku',
    protect,
    authorize('MAHASISWA'),
    getKelasKu
);

router.get('/kelas/:id/peserta',
    protect,
    authorize('DOSEN', 'ADMIN'),
    getPesertaKelas
);

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

module.exports = router;


