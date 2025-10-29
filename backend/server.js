const express = require("express");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });
const helmet = require('helmet');

//import security middleware
const { generalLimiter, authLimiter } = require('./middlewares/rateLimiterMiddleware');
const {sanitizeInput} = require('./middlewares/validationMiddleware');

const app = express();

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

const port = process.env.PORT || 5050;
app.get('/', (req, res) => {
    res.send('Hello World!');
});

app.use('/api/auth', authLimiter, authRoutes);

app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});

module.exports = app;