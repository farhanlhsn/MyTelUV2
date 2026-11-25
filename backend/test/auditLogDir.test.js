/**
 * Unit Testing - audit log directory (utils/auditLogger.js)
 *
 * AUDIT_LOG_DIR points the audit log at a mounted volume; without it the log stays in backend/logs
 * (/app/logs inside the Docker image).
 */

const path = require('path');
const { resolveAuditLogDir } = require('../utils/auditLogger');

describe('resolveAuditLogDir', () => {
    const defaultDir = path.join(__dirname, '..', 'logs');

    test('uses AUDIT_LOG_DIR when it is set', () => {
        expect(resolveAuditLogDir({ AUDIT_LOG_DIR: '/var/log/myteluv2' })).toBe('/var/log/myteluv2');
    });

    test('defaults to backend/logs when AUDIT_LOG_DIR is unset or blank', () => {
        expect(resolveAuditLogDir({})).toBe(defaultDir);
        expect(resolveAuditLogDir({ AUDIT_LOG_DIR: '' })).toBe(defaultDir);
        expect(resolveAuditLogDir({ AUDIT_LOG_DIR: '   ' })).toBe(defaultDir);
    });
});
