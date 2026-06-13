const validator = require('validator');

const { ZodError } = require('zod');

// Sanitize and validate input data
exports.sanitizeInput = (req, res, next) => {
    for (let key in req.body) {
        if (typeof req.body[key] === 'string') {
            req.body[key] = req.body[key].trim();
            // Skip sanitization for password and content fields
            const skipEscape = ['password', 'oldPassword', 'newPassword', 'new_password', 'content'];
            if (!skipEscape.includes(key)) {
                req.body[key] = validator.escape(req.body[key]);
            }
        }
    }
    next();
};

// Generic Zod Validator Middleware
exports.validateZod = (schema) => {
    return async (req, res, next) => {
        try {
            req.body = await schema.parseAsync(req.body);
            next();
        } catch (error) {
            if (error instanceof ZodError) {
                const errorMessages = error.errors.map(err => `${err.path.join('.')}: ${err.message}`);
                return res.status(400).json({
                    status: "error",
                    message: "Validation failed",
                    details: errorMessages
                });
            }
            next(error);
        }
    };
};

// Validate required fields
exports.validateRequired = (fields) => {
    return (req, res, next) => {
        const missingFields = [];

        fields.forEach(field => {
            if (!req.body[field] || (typeof req.body[field] === 'string' && req.body[field].trim() === '')) {
                missingFields.push(field);
            }
        });

        if (missingFields.length > 0) {
            return res.status(400).json({
                status: "error",
                message: `Missing required fields: ${missingFields.join(', ')}`
            });
        }

        next();
    };
};

// Validate email format
exports.validateEmail = (req, res, next) => {
    const { email } = req.body;

    if (email && !validator.isEmail(email)) {
        return res.status(400).json({
            status: "error",
            message: 'Please provide a valid email address'
        });
    }
    next();
};

// Validate password strength
exports.validatePassword = (req, res, next) => {
    const { password } = req.body;

    if (password) {
        if (!validator.isLength(password, { min: 6 })) {
            return res.status(400).json({
                status: "error",
                message: 'Password must be at least 6 characters long'
            });
        }

        // Check for at least one number and one letter
        if (!validator.matches(password, /^(?=.*[A-Za-z])(?=.*\d)/)) {
            return res.status(400).json({
                status: "error",
                message: 'Password must contain at least one letter and one number'
            });
        }
    }
    next();
};

// Validate username format
exports.validateUsername = (req, res, next) => {
    const { username } = req.body;

    if (username) {
        // Check length (3-30 characters)
        if (!validator.isLength(username, { min: 3, max: 30 })) {
            return res.status(400).json({
                status: "error",
                message: 'Username must be between 3 and 30 characters'
            });
        }

        // Check format: alphanumeric and underscore only, must start with letter
        if (!validator.matches(username, /^[a-zA-Z][a-zA-Z0-9_]*$/)) {
            return res.status(400).json({
                status: "error",
                message: 'Username must start with a letter and contain only letters, numbers, and underscores'
            });
        }
    }
    next();
};

// Validate schema using Zod
exports.validateZod = (schema) => (req, res, next) => {
    try {
        schema.parse(req.body);
        next();
    } catch (error) {
        return res.status(400).json({
            status: "error",
            message: error.errors ? error.errors.map(e => e.message).join(', ') : error.message
        });
    }
};