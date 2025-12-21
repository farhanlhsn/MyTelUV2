const express = require('express');
const { login, register, getMe, updateProfile, changePassword } = require('../controllers/authController');
const { validateRequired, validatePassword } = require('../middlewares/validationMiddleware');
const { protect } = require('../middlewares/authMiddleware');
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