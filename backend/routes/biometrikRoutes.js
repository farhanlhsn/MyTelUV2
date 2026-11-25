const express = require("express");
const multer = require("multer");
const path = require("path");
const {
  addBiometrik,
  deleteBiometrik,
  editBiometrik,
  verifyWajah,
  scanWajah,
  biometrikAbsen,
  getMyBiometrikStatus,
} = require("../controllers/biometrikController");
const { protect, authorize } = require("../middlewares/authMiddleware");
const { validateRequired } = require("../middlewares/validationMiddleware");

const router = express.Router();

// Configure multer for file uploads
const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  // Accept images only
  const allowedTypes = /jpeg|jpg|png/;
  const extname = allowedTypes.test(
    path.extname(file.originalname).toLowerCase(),
  );
  const mimetype = allowedTypes.test(file.mimetype);

  if (mimetype && extname) {
    return cb(null, true);
  } else {
    cb(new Error("Hanya file gambar JPEG, JPG, atau PNG yang diizinkan"));
  }
};

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 2 * 1024 * 1024, // 2MB limit for memory buffer safety
  },
  fileFilter: fileFilter,
});

const { biometrikLimiter } = require("../middlewares/rateLimiterMiddleware");

// Routes - ADMIN ONLY untuk add/edit/delete (kampus yang daftarin)
router.post(
  "/add",
  protect,
  authorize("ADMIN"),
  upload.single("image"),
  validateRequired(["id_user"]),
  addBiometrik,
);

router.delete("/delete/:id_user", protect, authorize("ADMIN"), deleteBiometrik);

router.put(
  "/edit/:id_user",
  protect,
  authorize("ADMIN"),
  upload.single("image"),
  editBiometrik,
);

// Verify - semua authenticated user bisa akses (non-ADMIN hanya mencocokkan wajahnya sendiri)
router.post(
  "/verify",
  protect,
  biometrikLimiter,
  upload.single("image"),
  verifyWajah,
);

// Scan - ADMIN dan DOSEN saja; DOSEN wajib mengirim id_kelas kelas yang diampu
router.post(
  "/scan",
  protect,
  authorize("ADMIN", "DOSEN"),
  biometrikLimiter,
  upload.single("image"),
  scanWajah,
);

// Own biometric status (is a face enrolled?) - any authenticated user
router.get("/status", protect, getMyBiometrikStatus);

// Biometric attendance - MAHASISWA absen pakai wajah
router.post(
  "/request-liveness-token",
  protect,
  authorize("MAHASISWA"),
  biometrikLimiter,
  require("../controllers/biometrikController").requestLivenessToken,
);

router.post(
  "/absen",
  protect,
  authorize("MAHASISWA"),
  biometrikLimiter,
  upload.single("image"),
  validateRequired(["latitude", "longitude"]),
  biometrikAbsen,
);

module.exports = router;
