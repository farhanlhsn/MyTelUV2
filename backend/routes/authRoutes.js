const express = require('express');
const { login, register, getMe, updateProfile, changePassword, getAllUsers } = require('../controllers/authController');
const { validateRequired, validatePassword } = require('../middlewares/validationMiddleware');
const { protect, authorize } = require('../middlewares/authMiddleware');
const router = express.Router();

router.post('/register',
    validateRequired(['nama', 'username', 'password']),
    validatePassword,
    register
);

router.post('/login',
    validateRequired(['username', 'password']),
    login
);

router.get('/me',
    protect,
    getMe
);

router.get('/users',
    protect,
    authorize('ADMIN'),
    getAllUsers
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

module.exports = router;