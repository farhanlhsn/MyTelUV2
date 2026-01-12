const jwt = require('jsonwebtoken');
const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma');

// Protect routes
exports.protect = asyncHandler(async (req, res, next) => {
  let token;

  // Only accept token from Authorization header 
  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }

  // Make sure token exists
  if (!token) {
    return res.status(401).json({
      status: "error",
      message: 'Not authorized to access this route'
    });
  }

  try {
    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Find user by ID from decoded token (exclude soft-deleted users)
    req.user = await prisma.user.findUnique({
      where: {
        id_user: decoded.id,
        deletedAt: null // Exclude soft-deleted users
      },
      select: {
        id_user: true,
        username: true,
        nama: true,
        role: true
      }
    });

    if (!req.user) {
      return res.status(401).json({ status: "error", message: 'User not found or has been deactivated' });
    }

    next();
  } catch (err) {
    return res.status(401).json({
      status: "error",
      message: 'Invalid or expired token'
    });
  }
});

// Grant access to specific roles
exports.authorize = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        status: "error",
        message: `User role ${req.user.role} is not authorized to access this route`
      });
    }
    next();
  };
};