const express = require('express');
const multer = require('multer');
const path = require('path');
const {
    addBiometrik,
    deleteBiometrik,
    editBiometrik,
    verifyWajah,
    scanWajah
} = require('../controllers/biometrikController');
const { protect, authorize } = require('../middlewares/authMiddleware');
const { validateRequired } = require('../middlewares/validationMiddleware');

const router = express.Router();

// Configure multer for file uploads
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/');
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'face-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const fileFilter = (req, file, cb) => {
    // Accept images only
    const allowedTypes = /jpeg|jpg|png/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
        return cb(null, true);
    } else {
        cb(new Error('Only image files (jpeg, jpg, png) are allowed!'));
    }
};

const upload = multer({
    storage: storage,
    limits: {
        fileSize: parseInt(process.env.MAX_FILE_SIZE || '10485760') // 10MB default
    },
    fileFilter: fileFilter
});

// Routes - ADMIN ONLY untuk add/edit/delete (kampus yang daftarin)
router.post('/add',
    protect,
    authorize('ADMIN'),
    upload.single('image'),
    validateRequired(['id_user']),
    addBiometrik
);

router.delete('/delete/:id_user',
    protect,
    authorize('ADMIN'),
    deleteBiometrik
);

router.put('/edit/:id_user',
    protect,
    authorize('ADMIN'),
    upload.single('image'),
    editBiometrik
);

// Verify & Scan - semua authenticated user bisa akses
router.post('/verify',
    protect,
    upload.single('image'),
    verifyWajah
);

router.post('/scan',
    protect,
    upload.single('image'),
    scanWajah
);

module.exports = router;
