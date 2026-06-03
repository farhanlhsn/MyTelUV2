const express = require("express");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });
const helmet = require('helmet');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const swaggerUi = require('swagger-ui-express');

//import security middleware
const { generalLimiter, authLimiter } = require('./middlewares/rateLimiterMiddleware');
const { sanitizeInput } = require('./middlewares/validationMiddleware');

const app = express();

// CORS configuration
const corsOptions = {
    origin: function (origin, callback) {
        // Allow requests with no origin (mobile apps, Postman, etc.)
        if (!origin) return callback(null, true);

        const allowedOrigins = [
            'http://localhost:3000',
            'http://localhost:5173',
            'http://localhost:8080',
            // Add your production domain here
            // 'https://yourdomain.com'
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

app.use(generalLimiter); // Apply rate limiting to all requests
app.use(express.json({ limit: '10mb' })); // Limit JSON payload size
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(sanitizeInput); // Sanitize all input

// Import routes
const authRoutes = require('./routes/authRoutes');
const kendaraanRoutes = require('./routes/kendaraanRoutes');
const akademikRoutes = require('./routes/akademikRoutes');
const biometrikRoutes = require('./routes/biometrikRoutes');
const parkirRoutes = require('./routes/parkirRoutes');
const postRoutes = require('./routes/postRoutes');
const anomaliRoutes = require('./routes/anomaliRoutes');

// Import Swagger
let swaggerSpec;
try {
    swaggerSpec = require('./utils/swagger');
} catch (e) {
    console.warn('[Warning] Swagger setup failed or swagger.js not found yet');
}

const port = process.env.PORT || 5050;
app.get('/', (req, res) => {
    res.send('Hello World!');
});

// Health Check Endpoint
app.get('/health', async (req, res) => {
    const health = {
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        services: {}
    };

    // Check Database
    const prismaHealth = require('./utils/prisma');
    try {
        await prismaHealth.$queryRaw`SELECT 1`;
        health.services.database = { status: 'ok' };
    } catch (e) {
        health.services.database = { status: 'error', message: e.message };
        health.status = 'degraded';
    }

    // Check Python Face Service (Port 5051)
    try {
        const resp = await fetch('http://localhost:5051/health', { signal: AbortSignal.timeout(3000) });
        health.services.face_recognition = { status: resp.ok ? 'ok' : 'error' };
    } catch {
        health.services.face_recognition = { status: 'unreachable' };
    }

    // Check Python Plate Service (Port 5001)
    try {
        const resp = await fetch('http://localhost:5001/health', { signal: AbortSignal.timeout(3000) });
        health.services.plate_recognition = { status: resp.ok ? 'ok' : 'error' };
    } catch {
        health.services.plate_recognition = { status: 'unreachable' };
    }

    const statusCode = health.status === 'ok' ? 200 : 503;
    res.status(statusCode).json(health);
});

if (swaggerSpec) {
    app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
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

registerRoutes('/api');
registerRoutes('/api/v1');

// Import and initialize scheduler for background tasks
const { initScheduler } = require('./utils/scheduler');

const server = http.createServer(app);
const io = new Server(server, { cors: corsOptions });

// Make io accessible in controllers
app.set('io', io);

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
    const pythonUrl = process.env.FACE_API_URL || 'http://localhost:5051';
    setInterval(async () => {
        try {
            await axios.get(`${pythonUrl}/health`, { timeout: 3000 });
        } catch (error) {
            console.error('[HealthCheck] Python service is down or unresponsive:', error.message);
        }
    }, 5 * 60 * 1000); // Check every 5 minutes
}

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
// Graceful shutdown
async function gracefulShutdown(signal) {
    console.log(`\n[${signal}] Shutting down gracefully...`);
    
    server.close(async () => {
        console.log('[Shutdown] HTTP server closed');
        
        try {
            const prisma = require('./utils/prisma');
            await prisma.$disconnect();
            console.log('[Shutdown] Database disconnected');
        } catch (e) {
            console.error('[Shutdown] Error disconnecting database:', e);
        }
        
        process.exit(0);
    });

    // Force shutdown after 10s if graceful fails
    setTimeout(() => {
        console.error('[Shutdown] Forced exit after 10s timeout');
        process.exit(1);
    }, 10000).unref();
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// 404 Handler
app.use((req, res) => {
    res.status(404).json({
        status: "error",
        message: `Route ${req.method} ${req.originalUrl} not found`
    });
});

// Global Error Handler
app.use((err, req, res, next) => {
    console.error(`[ERROR] ${err.message}`, err.stack);

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
            message: "CORS not allowed"
        });
    }

    // Hide internal details in production
    const message = process.env.NODE_ENV === 'production'
        ? 'Internal server error'
        : err.message;

    res.status(err.statusCode || 500).json({
        status: "error",
        message
    });
});

module.exports = app;