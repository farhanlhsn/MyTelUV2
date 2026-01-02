const express = require('express');
const { login, logout, register, getMe, updateProfile, changePassword, getAllUsers, adminResetPassword, registerFcmToken } = require('../controllers/authController');
const { validateRequired, validatePassword, validateUsername } = require('../middlewares/validationMiddleware');
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

// FCM Token Registration
router.post('/fcm-token',
    protect,
    validateRequired(['fcm_token']),
    registerFcmToken
);

module.exports = router;