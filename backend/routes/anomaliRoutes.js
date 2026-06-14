const express = require('express');
const router = express.Router();
const { 
    analyzeKelasAttendance, 
    getLaporanAnomali, 
    updateLaporanAnomali, 
    getJobStatus,
    getAnomalySettings,
    updateAnomalySettings
} = require('../controllers/anomaliController');
const { protect, authorize } = require('../middlewares/authMiddleware');

router.get('/settings', protect, authorize('ADMIN'), getAnomalySettings);
router.put('/settings', protect, authorize('ADMIN'), updateAnomalySettings);
router.post('/analyze/:id_kelas', protect, authorize('DOSEN', 'ADMIN'), analyzeKelasAttendance);
router.get('/job-status/:jobId', protect, authorize('DOSEN', 'ADMIN'), getJobStatus);
router.get('/:id_kelas', protect, authorize('DOSEN', 'ADMIN'), getLaporanAnomali);
router.put('/:id_anomali', protect, authorize('DOSEN', 'ADMIN'), updateLaporanAnomali);

module.exports = router;