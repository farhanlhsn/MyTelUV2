const express = require('express');
const { login, logout, register, getMe, updateProfile, changePassword, getAllUsers, adminResetPassword, registerFcmToken, refreshToken, deactivateUser, reactivateUser, updatePreferences, uploadProfilePicture, requestPasswordReset, resetPasswordWithToken } = require('../controllers/authController');
const { validateRequired, validatePassword, validateUsername, validateZod } = require('../middlewares/validationMiddleware');
const { registerSchema, loginSchema, updateProfileSchema, changePasswordSchema, adminResetPasswordSchema, fcmTokenSchema, refreshTokenSchema, forgotPasswordSchema, resetPasswordSchema } = require('../middlewares/zodSchemas');
const { protect, authorize } = require('../middlewares/authMiddleware');
const { authLimiter } = require('../middlewares/rateLimiterMiddleware');
const router = express.Router();

router.post('/register',
    authLimiter,
    validateRequired(['nama', 'username', 'password']),
    validateUsername,
    validatePassword,
    register
);

router.post('/login',
    authLimiter,
    validateRequired(['username', 'password']),
    login
);

router.post('/refresh',
    validateZod(refreshTokenSchema),
    refreshToken
);

// Password Reset Flow
router.post('/forgot-password', 
    validateZod(forgotPasswordSchema), 
    requestPasswordReset
);
router.post('/reset-password', 
    validateZod(resetPasswordSchema), 
    resetPasswordWithToken
);

router.get('/me',
    protect,
    getMe
);

router.post('/logout',
    protect,
    logout
);

router.get('/users',
    protect,
    authorize('ADMIN'),
    getAllUsers
);

router.put('/profile',
    protect,
    validateRequired(['nama']),
    updateProfile
);

router.put('/password',
    protect,
    validateRequired(['oldPassword', 'newPassword']),
    changePassword
);

router.put('/admin/reset-password',
    protect,
    authorize('ADMIN'),
    validateRequired(['id_user', 'new_password']),
    adminResetPassword
);

router.delete('/users/:id_user',
    protect,
    authorize('ADMIN'),
    deactivateUser
);

router.patch('/users/:id_user/reactivate',
    protect,
    authorize('ADMIN'),
    reactivateUser
);

// FCM Token Registration
router.post('/fcm-token',
    protect,
    validateRequired(['fcm_token']),
    registerFcmToken
);

// Preferences (Notifications)
router.put('/preferences',
    protect,
    updatePreferences
);

// Profile Picture
const multer = require('multer');
const path = require('path');

const allowedProfilePictureMimes = new Set([
    'image/jpeg',
    'image/png',
    'image/webp'
]);
const allowedProfilePictureExtensions = new Set(['.jpg', '.jpeg', '.png', '.webp']);

const profilePictureFileFilter = (req, file, cb) => {
    const extension = path.extname(file.originalname || '').toLowerCase();
    const hasAllowedMime = allowedProfilePictureMimes.has(file.mimetype);
    const hasAllowedExtension = allowedProfilePictureExtensions.has(extension);

    if (!hasAllowedMime || !hasAllowedExtension) {
        return cb(new Error('Invalid profile picture file type. Allowed: jpeg, png, webp'), false);
    }

    return cb(null, true);
};

const uploadProfilePictureImage = multer({
    storage: multer.memoryStorage(),
    limits: {
        files: 1,
        fileSize: 5 * 1024 * 1024
    },
    fileFilter: profilePictureFileFilter
});

router.post('/profile-picture',
    protect,
    uploadProfilePictureImage.single('image'),
    uploadProfilePicture
);

module.exports = router;
