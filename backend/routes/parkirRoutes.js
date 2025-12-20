const express = require('express');
const { getHistoriParkir, getAllParkiran, getAnalitikParkiran, createParkiran, updateParkiran, deleteParkiran } = require('../controllers/parkirController');
const { protect, authorize } = require('../middlewares/authMiddleware');
const router = express.Router();

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
