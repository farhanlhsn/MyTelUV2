const express = require('express');
<<<<<<< Updated upstream
const { login, logout, register, getMe, updateProfile, changePassword, getAllUsers, adminResetPassword, registerFcmToken } = require('../controllers/authController');
const { validateRequired, validatePassword, validateUsername } = require('../middlewares/validationMiddleware');
=======
const { login, logout, register, getMe, updateProfile, changePassword, getAllUsers, adminResetPassword, registerFcmToken, refreshToken, deactivateUser, reactivateUser, updatePreferences, uploadProfilePicture, requestPasswordReset, resetPasswordWithToken } = require('../controllers/authController');
const { validateZod } = require('../middlewares/validationMiddleware');
const { registerSchema, loginSchema, updateProfileSchema, changePasswordSchema, adminResetPasswordSchema, fcmTokenSchema, refreshTokenSchema, forgotPasswordSchema, resetPasswordSchema } = require('../middlewares/zodSchemas');
>>>>>>> Stashed changes
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
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 } // 5MB limit
});

router.post('/profile-picture',
    protect,
    upload.single('image'),
    uploadProfilePicture
);

module.exports = router;