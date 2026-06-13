const express = require('express');
const { getHistoriParkir, getAllParkiran, getAnalitikParkiran, createParkiran, updateParkiran, deleteParkiran, processEdgeEntry, reconcileKapasitas, exportParkirLogs, manualOverride } = require('../controllers/parkirController');
const { protect, authorize } = require('../middlewares/authMiddleware');
const { protectEdgeDevice } = require('../middlewares/edgeAuthMiddleware');
const { edgeLimiter } = require('../middlewares/rateLimiterMiddleware');
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
// Accepts two images: 'image' (plate) and 'face_image' (optional face capture)
router.post('/edge-entry',
    protectEdgeDevice,
    edgeLimiter,
    upload.fields([
        { name: 'image', maxCount: 1 },
        { name: 'face_image', maxCount: 1 }
    ]),
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

// Reconcile kapasitas parkiran (Admin only)
router.post('/:id/reconcile',
    protect,
    authorize('ADMIN'),
    reconcileKapasitas
);

// Export log parkir sebagai CSV (Admin only)
// Query: ?parkiran_id=&from=2024-01-01&to=2024-12-31
router.get('/export',
    protect,
    authorize('ADMIN'),
    exportParkirLogs
);

// Manual gate override (Admin only) — force entry/exit for a vehicle
router.post('/:id/override',
    protect,
    authorize('ADMIN'),
    manualOverride
);

module.exports = router;
