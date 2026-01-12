const express = require('express');
const router = express.Router();
const { analyzeKelasAttendance, getLaporanAnomali } = require('../controllers/anomaliController');
const { protect, authorize } = require('../middlewares/authMiddleware'); // Pastikan path ini benar sesuai struktur Anda

router.post('/analyze/:id_kelas', protect, authorize('DOSEN', 'ADMIN'), analyzeKelasAttendance);
router.get('/:id_kelas', protect, authorize('DOSEN', 'ADMIN'), getLaporanAnomali);

module.exports = router;