const express = require('express');
const { getHistoriParkir, getAllParkiran, getAnalitikParkiran, createParkiran, updateParkiran, deleteParkiran, processEdgeEntry } = require('../controllers/parkirController');
const { protect, authorize } = require('../middlewares/authMiddleware');
const multer = require('multer');

// Configure multer for memory storage
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 5 * 1024 * 1024 // 5MB limit
    }
});

const router = express.Router();

// Edge device parking entry/exit (internal API - uses X-Edge-Secret header)
router.post('/edge-entry',
    upload.single('image'),
    processEdgeEntry
);

// Get histori parkir user
router.get('/histori',
    protect,
    getHistoriParkir
);

// Get semua parkiran dengan kapasitas
router.get('/all',
    protect,
    getAllParkiran
);

// Get analitik parkiran
router.get('/analitik',
    protect,
    getAnalitikParkiran
);

// Create lokasi parkiran baru (Admin only)
router.post('/',
    protect,
    authorize('ADMIN'),
    createParkiran
);

// Update lokasi parkiran (Admin only)
router.put('/:id',
    protect,
    authorize('ADMIN'),
    updateParkiran
);

// Delete lokasi parkiran (Admin only)
router.delete('/:id',
    protect,
    authorize('ADMIN'),
    deleteParkiran
);

module.exports = router;
