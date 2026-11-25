const express = require('express');
const multer = require('multer');
const {
    getAllPosts,
    getPostById,
    createPost,
    updatePost,
    deletePost,
    toggleLike,
    getComments,
    addComment,
    deleteComment,
    getMyPosts
} = require('../controllers/postController');
const { protect } = require('../middlewares/authMiddleware');
const router = express.Router();

// Multer config for media uploads. Files are buffered in memory, so keep the limits tight:
// at most 5 files per request, 5 MB each (worst case ~25 MB per request).
const MAX_MEDIA_FILES = 5;
const MAX_MEDIA_BYTES = 5 * 1024 * 1024;

const storage = multer.memoryStorage();
const upload = multer({
    storage,
    limits: { fileSize: MAX_MEDIA_BYTES, files: MAX_MEDIA_FILES },
    fileFilter: (req, file, cb) => {
        // Images (incl. gif) and videos only
        const allowedMimes = [
            'image/jpeg', 'image/png', 'image/gif', 'image/webp',
            'video/mp4', 'video/webm', 'video/quicktime'
        ];
        if (allowedMimes.includes(file.mimetype)) {
            cb(null, true);
        } else {
            const error = new Error('Invalid file type');
            error.code = 'INVALID_FILE_TYPE';
            cb(error, false);
        }
    }
});

// Turns multer's limit / file type errors into 400s with Indonesian messages
// instead of letting them fall through to the generic 500 handler.
const uploadErrorMessages = {
    LIMIT_FILE_SIZE: `Ukuran setiap file media maksimal ${MAX_MEDIA_BYTES / (1024 * 1024)} MB`,
    LIMIT_FILE_COUNT: `Maksimal ${MAX_MEDIA_FILES} file media per postingan`,
    LIMIT_UNEXPECTED_FILE: `Maksimal ${MAX_MEDIA_FILES} file media per postingan (field "media")`,
    INVALID_FILE_TYPE: 'Tipe file tidak didukung. Gunakan gambar (JPEG, PNG, GIF, WebP) atau video (MP4, WebM, MOV)'
};

const mediaFields = upload.fields([{ name: 'media', maxCount: MAX_MEDIA_FILES }]);

const uploadMedia = (req, res, next) => {
    mediaFields(req, res, (err) => {
        if (!err) return next();
        const message = uploadErrorMessages[err.code];
        if (message) {
            return res.status(400).json({ status: "error", message });
        }
        return next(err);
    });
};

// Post CRUD
router.get('/', protect, getAllPosts);
router.get('/me', protect, getMyPosts);
router.get('/:id', protect, getPostById);
router.post('/', protect, uploadMedia, createPost);
router.put('/:id', protect, uploadMedia, updatePost);
router.delete('/:id', protect, deletePost);

// Likes
router.post('/:id/like', protect, toggleLike);

// Comments
router.get('/:id/comments', protect, getComments);
router.post('/:id/comments', protect, addComment);
router.delete('/:id/comments/:commentId', protect, deleteComment);

module.exports = router;
