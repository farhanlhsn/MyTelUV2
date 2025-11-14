const express = require('express');
const { registerKendaraan, getKendaraan, deleteKendaraan, verifyKendaraan, getAllUnverifiedKendaraan, getAllKendaraan } = require('../controllers/kendaraanController');
const { uploadFields, validateFileSize, requireFile } = require('../middlewares/multerMiddleware');
const { validateRequired } = require('../middlewares/validationMiddleware');
const { protect, authorize } = require('../middlewares/authMiddleware');
const router = express.Router();

router.post('/register',
    uploadFields([
        { name: 'fotoKendaraan', maxCount: 3 }, // wajib 3 foto kendaraan
        { name: 'fotoSTNK', maxCount: 1 }        // Wajib 1 foto STNK
    ]),
    validateRequired(['plat_nomor', 'id_user']), 
    validateFileSize,  
    requireFile,       
    registerKendaraan  
);

router.get('/',
    protect,
    validateRequired(['id_user']),
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
module.exports = router;
