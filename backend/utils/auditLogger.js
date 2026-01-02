const winston = require('winston');
const path = require('path');

// Create logs directory if it doesn't exist
const logsDir = path.join(__dirname, '..', 'logs');

// Audit logger for sensitive actions
const auditLogger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp({
            format: 'YYYY-MM-DD HH:mm:ss'
        }),
        winston.format.json()
    ),
    defaultMeta: { service: 'myteluv-audit' },
    transports: [
        // Write audit logs to a dedicated file
        new winston.transports.File({
            filename: path.join(logsDir, 'audit.log'),
            maxsize: 5242880, // 5MB
            maxFiles: 5
        }),
        // Also log to console in development
        ...(process.env.NODE_ENV !== 'production'
            ? [new winston.transports.Console({
                format: winston.format.combine(
                    winston.format.colorize(),
                    winston.format.simple()
                )
            })]
            : []
        )
    ]
});

/**
 * Log an audit event for sensitive actions
 * @param {Object} params - Audit parameters
 * @param {string} params.action - Action performed (e.g., 'ADMIN_RESET_PASSWORD', 'USER_DELETE')
 * @param {number} params.performedBy - User ID who performed the action
 * @param {number} [params.targetUserId] - User ID affected by the action (if applicable)
 * @param {string} [params.details] - Additional details about the action
 * @param {string} [params.ip] - IP address of the requester
 */
const logAudit = ({ action, performedBy, targetUserId = null, details = null, ip = null }) => {
    auditLogger.info({
        action,
        performedBy,
        targetUserId,
        details,
        ip,
        timestamp: new Date().toISOString()
    });
};

module.exports = { logAudit };
