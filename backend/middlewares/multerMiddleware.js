const multer = require('multer');
const path = require('path');

// Simpan file di memori untuk di-upload ke R2
const storage = multer.memoryStorage();

// Allowed config per uploadType
const allowedTypes = {
  'fotoKendaraan': {
    mimeTypes: ['image/jpeg','image/jpg','image/png','image/webp'],
    extensions: ['.jpg','.jpeg','.png','.webp'],
    maxSize: 5 * 1024 * 1024 // 5MB
  },
  'fotoSTNK': {
    mimeTypes: ['image/jpeg','image/jpg','image/png','image/webp'],
    extensions: ['.jpg','.jpeg','.png','.webp'],
    maxSize: 5 * 1024 * 1024 // 5MB
  }
};

// File filter: cek mime + extension dan tulis metadata ke file
const fileFilter = (req, file, cb) => {
  // Gunakan fieldname dari multer (fotoKendaraan, fotoSTNK, dll)
  const uploadType = file.fieldname;
  
  if (!uploadType || !allowedTypes[uploadType]) {
    return cb(new Error(`Invalid upload field: ${uploadType || '(empty)'}. Allowed: ${Object.keys(allowedTypes).join(', ')}`), false);
  }

  const cfg = allowedTypes[uploadType];
  const ext = path.extname(file.originalname).toLowerCase();
  const validMime = cfg.mimeTypes.includes(file.mimetype);
  const validExt  = cfg.extensions.includes(ext);

  if (!validMime || !validExt) {
    return cb(new Error(`Invalid file type for ${uploadType}. Allowed: ${cfg.extensions.join(', ')}`), false);
  }

  file.uploadType = uploadType;
  file.maxSize = cfg.maxSize;
  cb(null, true);
};

// Helper untuk buat uploader dengan limit berbeda
const makeUploader = (filesLimit = 1, fileSize = 10 * 1024 * 1024) => multer({
  storage,
  fileFilter,
  limits: { files: filesLimit, fileSize }
});

// === Middleware builders (tak ada handler lokal; biarkan global error handler yang tangani) ===
const uploadSingle = (fieldName = 'file') => makeUploader(1).single(fieldName);
const uploadMultiple = (fieldName = 'files', maxCount = 10) => makeUploader(maxCount).array(fieldName, maxCount);
const uploadFields = (fields) => makeUploader(10).fields(fields); // fields: [{ name: 'field1', maxCount: 1 }]

// Validasi ukuran per file (untuk single & multiple)
const validateFileSize = (req, res, next) => {
  let filesToValidate = [];
  
  if (req.file) {
    filesToValidate = [req.file];
  } else if (req.files) {
    // Handle array (dari .array())
    if (Array.isArray(req.files)) {
      filesToValidate = req.files;
    } 
    // Handle object (dari .fields())
    else if (typeof req.files === 'object') {
      for (const fieldName in req.files) {
        filesToValidate = filesToValidate.concat(req.files[fieldName]);
      }
    }
  }
  
  for (const f of filesToValidate) {
    if (f.maxSize && f.size > f.maxSize) {
      const maxMB = Math.round(f.maxSize / (1024 * 1024));
      const msg = `File size exceeds ${maxMB}MB limit for ${f.uploadType}`;
      // lempar ke global error handler
      return next(new Error(msg));
    }
  }
  
  next();
};

// Pastikan ada file yang diupload
const requireFile = (req, res, next) => {
  const hasFile = req.file || 
    (req.files && (
      Array.isArray(req.files) ? req.files.length > 0 : Object.keys(req.files).length > 0
    ));
    
  if (!hasFile) {
    return next(new Error('No file uploaded'));
  }
  next();
};

module.exports = {
  uploadSingle,
  uploadMultiple,
  uploadFields,
  validateFileSize,
  requireFile
};