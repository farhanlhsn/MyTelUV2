const express = require("express");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });
const helmet = require('helmet');
const cors = require('cors');

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

        if (allowedOrigins.indexOf(origin) !== -1 || process.env.NODE_ENV === 'development') {
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

const port = process.env.PORT || 5050;
app.get('/', (req, res) => {
    res.send('Hello World!');
});

app.use('/api/auth', authRoutes); // authLimiter now applied individually in authRoutes.js
app.use('/api/kendaraan', kendaraanRoutes);
app.use('/api/akademik', akademikRoutes);
app.use('/api/biometrik', biometrikRoutes);
app.use('/api/parkir', parkirRoutes);
app.use('/api/posts', postRoutes);

// Import and initialize scheduler for background tasks
const { initScheduler } = require('./utils/scheduler');

app.listen(port, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${port}`);
    console.log(`Local: http://localhost:${port}`);
    console.log(`Network: http://10.0.2.2:${port} (Android Emulator)`);

    // Initialize scheduled tasks (auto-close sessions, etc.)
    initScheduler();
});

module.exports = app;