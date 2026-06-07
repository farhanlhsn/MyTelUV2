const express = require('express');
const { login, logout, register, getMe, updateProfile, changePassword, getAllUsers, adminResetPassword, registerFcmToken } = require('../controllers/authController');
const { validateZod } = require('../middlewares/validationMiddleware');
const { registerSchema, loginSchema, updateProfileSchema, changePasswordSchema, adminResetPasswordSchema, fcmTokenSchema } = require('../middlewares/zodSchemas');
const { protect, authorize } = require('../middlewares/authMiddleware');
const { authLimiter } = require('../middlewares/rateLimiterMiddleware');
const router = express.Router();

router.post('/register',
    authLimiter,
    validateZod(registerSchema),
    register
);

router.post('/login',
    authLimiter,
    validateZod(loginSchema),
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
    validateZod(updateProfileSchema),
    updateProfile
);

router.put('/password',
    protect,
    validateZod(changePasswordSchema),
    changePassword
);

router.put('/admin/reset-password',
    protect,
    authorize('ADMIN'),
    validateZod(adminResetPasswordSchema),
    adminResetPassword
);

// FCM Token Registration
router.post('/fcm-token',
    protect,
    validateZod(fcmTokenSchema),
    registerFcmToken
);

module.exports = router;