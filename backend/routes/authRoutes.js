const express = require('express');
const {login, register, getMe} = require('../controllers/authController');
const { validateRequired, validatePassword } = require('../middlewares/validationMiddleware');
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
    getMe
);

module.exports = router;