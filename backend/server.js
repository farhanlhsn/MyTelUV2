const express = require("express");
const path = require("path");
const fs = require("fs");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

// TEST_MODE replaces real face/plate verification with stubs. Refuse to boot with it in production.
// Runs right after dotenv (TEST_MODE may come from .env) and before any route or listener is loaded.
const { shouldRefuseStart } = require('./utils/startupGuard');
if (shouldRefuseStart()) {
    console.error('[FATAL] TEST_MODE=true is not allowed when NODE_ENV=production. Refusing to start.');
    process.exit(1);
}

const helmet = require('helmet');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const swaggerUi = require('swagger-ui-express');

// Import security middleware
const { generalLimiter, authLimiter, healthLimiter } = require('./middlewares/rateLimiterMiddleware');
const { sanitizeInput } = require('./middlewares/validationMiddleware');
const { socketAuth } = require('./middlewares/socketAuthMiddleware');
const { GENERIC_SERVER_ERROR } = require('./utils/serverError');

// Import routes
const authRoutes = require('./routes/authRoutes');
const kendaraanRoutes = require('./routes/kendaraanRoutes');
const akademikRoutes = require('./routes/akademikRoutes');
const biometrikRoutes = require('./routes/biometrikRoutes');
const parkirRoutes = require('./routes/parkirRoutes');
const postRoutes = require('./routes/postRoutes');
const anomaliRoutes = require('./routes/anomaliRoutes');

// Swagger lists every route and its schemas: serve it outside production, or when ENABLE_SWAGGER=true.
const swaggerEnabled = process.env.NODE_ENV !== 'production' || process.env.ENABLE_SWAGGER === 'true';
let swaggerSpec;
if (swaggerEnabled) {
    try {
        swaggerSpec = require('./utils/swagger');
    } catch (e) {
        console.warn('[Warning] Swagger setup failed or swagger.js not found yet');
    }
}

const app = express();
const port = process.env.PORT || 5050;

// Behind Caddy (and Docker networking) the TCP peer is the proxy, so without this every client shares
// one IP and the rate limiters key on the proxy. Trust only private/loopback hops by default;
// TRUST_PROXY overrides it (a hop count such as "1", or a comma separated list of IPs/subnets).
// This MUST be set before any rate limiter or anything else that reads req.ip.
const trustProxy = (process.env.TRUST_PROXY ?? '').trim() || 'loopback, linklocal, uniquelocal';
app.set('trust proxy', /^[0-9]+$/.test(trustProxy) ? Number(trustProxy) : trustProxy);

// CORS configuration
const corsOptions = {
    origin: function (origin, callback) {
        // Allow requests with no origin (mobile apps, Postman, etc.)
        if (!origin) return callback(null, true);

        const allowedOrigins = [
            'http://localhost:3000',
            'http://localhost:5173',
            'http://localhost:8080',
        ];

        if (process.env.FRONTEND_URL) {
            allowedOrigins.push(process.env.FRONTEND_URL);
        }

        const allowAllOrigins = process.env.CORS_ALLOW_ALL === 'true';
        if (allowedOrigins.indexOf(origin) !== -1 || allowAllOrigins) {
            callback(null, true);
        } else {
            callback(new Error('Not allowed by CORS'));
        }
    },
    credentials: true,
    optionsSuccessStatus: 200,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    exposedHeaders: ['X-Export-Truncated', 'Content-Disposition'],
};

app.use(cors(corsOptions));

// Security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            scriptSrc: ["'self'"],
            imgSrc: ["'self'", "data:", "https:"],
        },
    },
}));

app.use(express.json({ limit: '10mb' })); // Limit JSON payload size
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(sanitizeInput); // Sanitize all input


app.get('/', (req, res) => {
    res.send('Selamat datang di MyTelUV2!');
});

// Base URLs of the AI services, read per call so they follow the environment. The face service is
// PYTHON_SERVICE_URL, falling back to FACE_API_URL (the variable biometrikController and docker-compose use).
const trimSlash = (url) => url.replace(/\/+$/, '');
const serviceUrls = () => ({
    face: trimSlash(process.env.PYTHON_SERVICE_URL || process.env.FACE_API_URL || 'http://localhost:5051'),
    plate: trimSlash(process.env.PLATE_API_URL || 'http://localhost:5001'),
    anomaly: trimSlash(process.env.ANOMALY_SERVICE_URL || 'http://localhost:5003'),
});

// Health probes only ever report 'ok' or 'error': the cause (host names, credentials, driver messages)
// never reaches the response. A database failure is logged; an AI service that is down is just 'error'.
const checkDatabase = async () => {
    try {
        const prismaHealth = require('./utils/prisma');
        await prismaHealth.$queryRaw`SELECT 1`;
        return 'ok';
    } catch (e) {
        console.error('[Health] Database check failed:', e.message);
        return 'error';
    }
};

const checkService = async (baseUrl) => {
    try {
        const resp = await fetch(`${baseUrl}/health`, { signal: AbortSignal.timeout(3000) });
        return resp.ok ? 'ok' : 'error';
    } catch {
        return 'error';
    }
};

// Health Check Endpoint. Reachable from the internet through Caddy, hence its own light rate limit.
app.get('/health', healthLimiter, async (req, res) => {
    const urls = serviceUrls();
    const [db, face, plate, anomaly] = await Promise.all([
        checkDatabase(),
        checkService(urls.face),
        checkService(urls.plate),
        checkService(urls.anomaly),
    ]);

    // Only the database decides 200 vs 503; a down AI service is reported but does not take the API out of rotation.
    res.status(db === 'ok' ? 200 : 503).json({
        status: db === 'ok' ? 'ok' : 'degraded',
        db,
        services: { face, plate, anomaly },
        timestamp: new Date().toISOString(),
    });
});

if (swaggerSpec) {
    app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
}

// Support both /api and /api/v1 prefixes
const registerRoutes = (prefix) => {
    app.use(`${prefix}/auth`, authRoutes);
    app.use(`${prefix}/kendaraan`, kendaraanRoutes);
    app.use(`${prefix}/akademik`, akademikRoutes);
    app.use(`${prefix}/biometrik`, biometrikRoutes);
    app.use(`${prefix}/parkir`, parkirRoutes);
    app.use(`${prefix}/posts`, postRoutes);
    app.use(`${prefix}/anomali`, anomaliRoutes);
};

// General rate limit for the whole API (/api and /api/v1). Mounted AFTER /health and Swagger so those
// are never limited, and BEFORE the routers, so it counts per client IP (req.user is not set yet).
app.use('/api', generalLimiter);

registerRoutes('/api');
registerRoutes('/api/v1');

// 404 Handler
app.use((req, res) => {
    res.status(404).json({
        status: "error",
        message: `Rute ${req.method} ${req.originalUrl} tidak ditemukan`
    });
});

// Global Error Handler
app.use((err, req, res, next) => {
    console.error(`[ERROR] ${err.message}`, err.stack);

    if (res.headersSent) {
        return next(err);
    }

    // Multer errors (file too large, wrong type, etc.)
    if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({
            status: "error",
            message: "File terlalu besar"
        });
    }

    if (err.message?.includes('Not allowed by CORS')) {
        return res.status(403).json({
            status: "error",
            message: "Akses lintas asal tidak diizinkan"
        });
    }

    const status = [err.statusCode, err.status].find((s) => Number.isInteger(s) && s >= 400 && s < 600) || 500;

    // A 5xx never carries the raw error (database hosts, credentials, stack details): it is logged above.
    // Body-parser supplies English messages: select Indonesian text by its stable error type.
    const clientErrorMessages = {
        'entity.parse.failed': 'Format JSON tidak valid',
        'entity.too.large': 'Data permintaan terlalu besar',
        'entity.verify.failed': 'Data permintaan tidak dapat diverifikasi',
        'request.aborted': 'Permintaan dibatalkan sebelum selesai',
        'request.size.invalid': 'Ukuran data permintaan tidak sesuai',
        'parameters.too.many': 'Terlalu banyak parameter dalam permintaan',
        'charset.unsupported': 'Pengodean karakter tidak didukung',
        'encoding.unsupported': 'Pengodean data tidak didukung',
        'querystring.parse.rangeError': 'Struktur data permintaan terlalu dalam'
    };
    res.status(status).json({
        status: "error",
        message: status >= 500 ? GENERIC_SERVER_ERROR : (clientErrorMessages[err.type] || err.message)
    });
});

// Import and initialize scheduler for background tasks
const { initScheduler } = require('./utils/scheduler');

const server = http.createServer(app);
const io = new Server(server, { cors: corsOptions });

// Make io accessible in controllers
app.set('io', io);

// Only clients holding a valid JWT (auth: { token }) may connect; everyone else gets "Unauthorized".
io.use(socketAuth);

io.on('connection', (socket) => {
    console.log(`[WebSocket] Client connected: ${socket.id}`);
    socket.on('disconnect', () => {
        console.log(`[WebSocket] Client disconnected: ${socket.id}`);
    });
});

// Clean up orphaned files in uploads directory
function cleanupUploads() {
    const fs = require('fs');
    const uploadsDir = path.join(__dirname, 'uploads');
    if (fs.existsSync(uploadsDir)) {
        const files = fs.readdirSync(uploadsDir);
        let count = 0;
        const now = Date.now();
        files.forEach(file => {
            const filePath = path.join(uploadsDir, file);
            const stat = fs.statSync(filePath);
            // Delete files older than 1 hour
            if (now - stat.mtimeMs > 3600000) {
                fs.unlinkSync(filePath);
                count++;
            }
        });
        if (count > 0) {
            console.log(`[Startup] Cleaned up ${count} orphaned files in uploads/`);
        }
    }
}

// Periodic Python service health check
function startPythonHealthCheck() {
    const axios = require('axios');
    const pythonUrl = serviceUrls().face;
    setInterval(async () => {
        try {
            await axios.get(`${pythonUrl}/health`, { timeout: 3000 });
        } catch (error) {
            console.error('[HealthCheck] Python service is down or unresponsive:', error.message);
        }
    }, 5 * 60 * 1000); // Check every 5 minutes
}

// Graceful shutdown
let shuttingDown = false;

async function gracefulShutdown(signal, exitCode = 0) {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`\n[${signal}] Shutting down gracefully...`);

    // Force shutdown after 10s if graceful fails
    const forceExit = setTimeout(() => {
        console.error('[Shutdown] Forced exit after 10s timeout');
        process.exit(1);
    }, 10000);
    forceExit.unref();

    try {
        // Disconnects every Socket.IO client, then closes the underlying HTTP server
        await io.close();
        console.log('[Shutdown] Socket.IO and HTTP server closed');
    } catch (e) {
        console.error('[Shutdown] Error closing server:', e);
    }

    try {
        const prisma = require('./utils/prisma');
        await prisma.$disconnect();
        console.log('[Shutdown] Database disconnected');
    } catch (e) {
        console.error('[Shutdown] Error disconnecting database:', e);
    }

    clearTimeout(forceExit);
    process.exit(exitCode);
}

// Signals shut down cleanly; an unhandled rejection or uncaught exception leaves the process in an
// unknown state, so it is logged and the process is shut down gracefully with exit code 1 (the
// supervisor / docker restart policy then starts a fresh one).
function registerProcessHandlers() {
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));
    process.on('unhandledRejection', (reason) => {
        console.error('[FATAL] Unhandled promise rejection:', reason);
        return gracefulShutdown('unhandledRejection', 1);
    });
    process.on('uncaughtException', (err) => {
        console.error('[FATAL] Uncaught exception:', err);
        return gracefulShutdown('uncaughtException', 1);
    });
}

// Listen only when started as `node server.js`; requiring this file (tests) must not open a port.
if (require.main === module) {
    registerProcessHandlers();

    server.listen(port, '0.0.0.0', () => {
        console.log(`Server running on http://0.0.0.0:${port}`);
        console.log(`Local: http://localhost:${port}`);
        console.log(`Network: http://10.0.2.2:${port} (Android Emulator)`);

        // Initialize startup tasks
        cleanupUploads();
        if (process.env.NODE_ENV === 'production') {
            startPythonHealthCheck();
        }

        // Initialize scheduled tasks (auto-close sessions, etc.)
        if (process.env.NODE_ENV !== 'test') {
            initScheduler();
        }
    });
}

module.exports = { app, server, io, gracefulShutdown, registerProcessHandlers };
