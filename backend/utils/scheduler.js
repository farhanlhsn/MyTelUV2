/**
 * Scheduler Service
 * Handles periodic tasks like auto-closing expired attendance sessions
 */
const cron = require('node-cron');
const prisma = require('./prisma');

/**
 * Auto-close expired attendance sessions
 * This function finds all open sessions where the 'selesai' time has passed
 * and closes them automatically.
 */
const closeExpiredSessions = async () => {
    const now = new Date();

    try {
        // Find all open sessions that have expired
        const expiredSessions = await prisma.sesiAbsensi.findMany({
            where: {
                status: true,
                selesai: { lt: now },
                deletedAt: null
            },
            select: {
                id_sesi_absensi: true,
                id_kelas: true,
                selesai: true
            }
        });

        if (expiredSessions.length === 0) {
            return; // No expired sessions to close
        }

        // Close all expired sessions
        const result = await prisma.sesiAbsensi.updateMany({
            where: {
                id_sesi_absensi: {
                    in: expiredSessions.map(s => s.id_sesi_absensi)
                }
            },
            data: {
                status: false
            }
        });

        console.log(`[Scheduler] Auto-closed ${result.count} expired session(s):`,
            expiredSessions.map(s => s.id_sesi_absensi));

    } catch (error) {
        console.error('[Scheduler] Error closing expired sessions:', error.message);
    }
};

/**
 * Initialize all scheduled tasks
 */
const initScheduler = () => {
    console.log('[Scheduler] Initializing scheduled tasks...');

    // Run every minute to check for expired sessions
    // Cron format: second minute hour day month day-of-week
    cron.schedule('* * * * *', async () => {
        await closeExpiredSessions();
    });

    console.log('[Scheduler] Auto-close session task scheduled (runs every minute)');

    // Run once on startup to close any sessions that expired while server was down
    closeExpiredSessions();
};

module.exports = {
    initScheduler,
    closeExpiredSessions
};
