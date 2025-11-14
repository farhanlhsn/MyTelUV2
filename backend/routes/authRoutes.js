const express = require('express');
const {login, register, getMe} = require('../controllers/authController');
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

module.exports = router;