const express = require('express');
const router = express.Router();
const { analyzeKelasAttendance, getLaporanAnomali, updateLaporanAnomali } = require('../controllers/anomaliController');
const { protect, authorize } = require('../middlewares/authMiddleware'); // Pastikan path ini benar sesuai struktur Anda

router.post('/analyze/:id_kelas', protect, authorize('DOSEN', 'ADMIN'), analyzeKelasAttendance);
router.get('/:id_kelas', protect, authorize('DOSEN', 'ADMIN'), getLaporanAnomali);
router.put('/:id_anomali', protect, authorize('DOSEN', 'ADMIN'), updateLaporanAnomali);

module.exports = router;