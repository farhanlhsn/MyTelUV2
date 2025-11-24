const express = require('express');
const { registerKendaraan, getKendaraan, deleteKendaraan, verifyKendaraan, getAllUnverifiedKendaraan, getAllKendaraan, getHistoriPengajuan, rejectKendaraan, getAllMyKendaraan } = require('../controllers/kendaraanController');
const { uploadFields, validateFileSize, requireFile } = require('../middlewares/multerMiddleware');
const { validateRequired } = require('../middlewares/validationMiddleware');
const { protect, authorize } = require('../middlewares/authMiddleware');
const router = express.Router();

router.post('/register',
    uploadFields([
        { name: 'fotoKendaraan', maxCount: 3 }, // wajib 3 foto kendaraan
        { name: 'fotoSTNK', maxCount: 1 }        // Wajib 1 foto STNK
    ]),
    protect,
    validateRequired(['plat_nomor', 'nama_kendaraan']), // id_user tidak perlu, ambil dari token
    validateFileSize,  
    requireFile,       
    registerKendaraan  
);

router.get('/',
    protect,
    getKendaraan
);
router.delete('/:id_kendaraan',
    protect,
    validateRequired(['id_kendaraan']),
    deleteKendaraan
);

router.post('/verify',
    protect,
    authorize('ADMIN'),
    validateRequired(['id_kendaraan', 'id_user']),
    verifyKendaraan
);

router.get('/all-unverified',
    protect,
    authorize('ADMIN'),
    getAllUnverifiedKendaraan
);
router.get('/all-kendaraan',
    protect,
    authorize('ADMIN'),
    getAllKendaraan
);

// Route untuk user melihat histori pengajuan
router.get('/histori-pengajuan',
    protect,
    getHistoriPengajuan
);

// Route untuk user melihat semua kendaraan mereka
router.get('/all-my-kendaraan',
    protect,
    getAllMyKendaraan
);

// Route untuk admin menolak pengajuan dengan feedback
router.post('/reject',
    protect,
    authorize('ADMIN'),
    validateRequired(['id_kendaraan', 'id_user', 'feedback']),
    rejectKendaraan
);

module.exports = router;
