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

// Multer config for media uploads
const storage = multer.memoryStorage();
const upload = multer({
    storage,
    limits: { fileSize: 50 * 1024 * 1024 }, // 50MB limit
    fileFilter: (req, file, cb) => {
        // Allow images, videos, gifs
        const allowedMimes = [
            'image/jpeg', 'image/png', 'image/gif', 'image/webp',
            'video/mp4', 'video/webm', 'video/quicktime'
        ];
        if (allowedMimes.includes(file.mimetype)) {
            cb(null, true);
        } else {
            cb(new Error('Invalid file type'), false);
        }
    }
});

// Post CRUD
router.get('/', protect, getAllPosts);
router.get('/me', protect, getMyPosts);
router.get('/:id', protect, getPostById);
router.post('/', protect, upload.fields([{ name: 'media', maxCount: 10 }]), createPost);
router.put('/:id', protect, updatePost);
router.delete('/:id', protect, deletePost);

// Likes
router.post('/:id/like', protect, toggleLike);

// Comments
router.get('/:id/comments', protect, getComments);
router.post('/:id/comments', protect, addComment);
router.delete('/:id/comments/:commentId', protect, deleteComment);

module.exports = router;
