const express = require('express');
const { registerKendaraan, getKendaraan, deleteKendaraan, verifyKendaraan, getAllUnverifiedKendaraan, getAllKendaraan, getHistoriPengajuan, rejectKendaraan, resubmitKendaraan } = require('../controllers/kendaraanController');
const { uploadFields, validateFileSize, requireFile } = require('../middlewares/multerMiddleware');
const { validateZod } = require('../middlewares/validationMiddleware');
const { registerKendaraanSchema, verifyKendaraanSchema, rejectKendaraanSchema } = require('../middlewares/zodSchemas');
const { protect, authorize } = require('../middlewares/authMiddleware');
const router = express.Router();

router.post('/register',
    uploadFields([
        { name: 'fotoKendaraan', maxCount: 3 }, // wajib 3 foto kendaraan
        { name: 'fotoSTNK', maxCount: 1 }        // Wajib 1 foto STNK
    ]),
    protect,
    validateZod(registerKendaraanSchema), // id_user tidak perlu, ambil dari token
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
    deleteKendaraan
);

router.post('/verify',
    protect,
    authorize('ADMIN'),
    validateZod(verifyKendaraanSchema),
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

// Note: Use GET / instead of /all-my-kendaraan - route removed to avoid duplication
// Route untuk admin menolak pengajuan dengan feedback
router.post('/reject',
    protect,
    authorize('ADMIN'),
    validateZod(rejectKendaraanSchema),
    rejectKendaraan
);

router.put('/:id_kendaraan/resubmit',
    protect,
    uploadFields([
        { name: 'fotoKendaraan', maxCount: 3 },
        { name: 'fotoSTNK', maxCount: 1 }
    ]),
    validateFileSize,
    resubmitKendaraan
);

module.exports = router;
