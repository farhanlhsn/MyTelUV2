const { rateLimit, ipKeyGenerator } = require('express-rate-limit');

// NOTE: these limiters rely on `app.set('trust proxy', ...)` in server.js so that `req.ip` is the real
// client IP (from Caddy's X-Forwarded-For) and not the reverse proxy's address.

// General API rate limiter. server.js mounts it on /api BEFORE any route-level `protect`, so
// `req.user` is not set yet and the key can only be the client IP. Many students share one campus
// NAT IP, so the budget is generous: it is a flood guard, not a per-user quota.
exports.generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000,
  keyGenerator: (req) => ipKeyGenerator(req.ip),
  message: {
    status: "error",
    message: 'Terlalu banyak permintaan. Coba lagi beberapa menit lagi.'
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

// Key for the auth limiter: client IP + lowercased username. Keying on the IP alone made every
// student behind the campus NAT share one 5-attempt bucket; adding the username keeps a brute-force
// attempt on one account limited without locking everybody else out.
// (ipKeyGenerator takes the IP *string*; it also folds IPv6 addresses into their /56 subnet.)
const authKeyGenerator = (req) => {
  const username = typeof req.body?.username === 'string' ? req.body.username.toLowerCase() : '';
  return `${ipKeyGenerator(req.ip)}:${username}`;
};
exports.authKeyGenerator = authKeyGenerator;

// Strict rate limiter for authentication endpoints (login, register)
exports.authLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 5, // limit each IP + username to 5 requests per windowMs
  keyGenerator: authKeyGenerator,
  message: {
    status: "error",
    message: 'Terlalu banyak percobaan autentikasi. Coba lagi beberapa menit lagi.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Limiter for the account recovery flows that have no username to key on
// (/forgot-password, /reset-password): 10 requests / 15 minutes per client IP
exports.sensitiveLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  keyGenerator: (req) => ipKeyGenerator(req.ip),
  message: {
    status: "error",
    message: 'Terlalu banyak permintaan. Coba lagi dalam 15 menit.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Limiter for /refresh only: every logged-in device calls it whenever its 1 h access token expires,
// and a whole campus can sit behind one NAT IP, so it gets 60 requests / 15 minutes per client IP.
// It has its own counter, so recovery-flow traffic (sensitiveLimiter) never locks out token refresh.
exports.refreshLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 60,
  keyGenerator: (req) => ipKeyGenerator(req.ip),
  message: {
    status: "error",
    message: 'Terlalu banyak permintaan refresh token. Coba lagi beberapa menit lagi.'
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
