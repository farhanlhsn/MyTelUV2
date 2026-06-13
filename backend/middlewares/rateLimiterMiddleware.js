const { rateLimit, ipKeyGenerator } = require('express-rate-limit');

// General API rate limiter
exports.generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: process.env.NODE_ENV === 'production' ? 500 : 1000,
  message: {
    status: "error",
    message: 'Too many requests from this IP, please try again later.'
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  skip: (req) => {
    // Skip rate limiting for edge device endpoints
    if (req.path.includes('/edge-entry')) {
      return true;
    }
    // Skip rate limiting for localhost in development
    if (process.env.NODE_ENV !== 'production') {
      const ip = req.ip || req.connection.remoteAddress;
      return ip === '127.0.0.1' || ip === '::1' || ip === '::ffff:127.0.0.1';
    }
    return false;
  }
});

// Strict rate limiter for authentication endpoints
exports.authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // limit each IP to 5 requests per windowMs for auth
  message: {
    status: "error",
    message: 'Too many authentication attempts, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Rate limiter for biometric endpoints
exports.biometrikLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 5, // limit each user/IP to 5 requests per minute
  keyGenerator: (req) => req.user?.id_user
    ? `user:${req.user.id_user}`
    : `ip:${ipKeyGenerator(req.ip)}`,
  message: {
    status: "error",
    message: 'Terlalu banyak percobaan absensi. Coba lagi dalam 1 menit.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});
// Rate limiter for edge device
exports.edgeLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 60, // limit to 60 requests per minute
  message: {
    status: "error",
    message: 'Too many requests from edge device, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});
