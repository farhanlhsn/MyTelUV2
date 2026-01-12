/**
 * Embedding Cache Utility
 * 
 * In-memory cache for face embeddings to reduce database load.
 * TTL: 5 minutes (configurable via EMBEDDING_CACHE_TTL env var)
 */

const NodeCache = require('node-cache');
const prisma = require('./prisma');

// Cache configuration
const CACHE_TTL = parseInt(process.env.EMBEDDING_CACHE_TTL || '300'); // 5 minutes
const CHECK_PERIOD = parseInt(process.env.EMBEDDING_CACHE_CHECK_PERIOD || '60'); // 1 minute

const cache = new NodeCache({
    stdTTL: CACHE_TTL,
    checkperiod: CHECK_PERIOD,
    useClones: false // For performance - embeddings are read-only
});

const CACHE_KEY = 'all_embeddings';

/**
 * Get all active face embeddings with user data.
 * Returns cached data if available, otherwise fetches from database.
 * 
 * @returns {Promise<Array>} Array of biometric data with user info
 */
async function getAllEmbeddings() {
    // Check cache first
    const cached = cache.get(CACHE_KEY);
    if (cached) {
        console.log('[EmbeddingCache] Cache hit - returning cached embeddings');
        return cached;
    }

    console.log('[EmbeddingCache] Cache miss - fetching from database');

    // Fetch from database
    const allBiometrics = await prisma.dataBiometrik.findMany({
        where: {
            deletedAt: null
        },
        include: {
            user: {
                select: {
                    id_user: true,
                    nama: true,
                    username: true,
                    role: true
                }
            }
        }
    });

    // Store in cache
    cache.set(CACHE_KEY, allBiometrics);
    console.log(`[EmbeddingCache] Cached ${allBiometrics.length} embeddings (TTL: ${CACHE_TTL}s)`);

    return allBiometrics;
}

/**
 * Invalidate the embeddings cache.
 * Should be called when biometric data is added, edited, or deleted.
 */
function invalidateCache() {
    const deleted = cache.del(CACHE_KEY);
    if (deleted) {
        console.log('[EmbeddingCache] Cache invalidated');
    }
}

/**
 * Get cache statistics for monitoring.
 * 
 * @returns {Object} Cache statistics
 */
function getStats() {
    return {
        keys: cache.keys(),
        stats: cache.getStats(),
        ttl: CACHE_TTL,
        checkPeriod: CHECK_PERIOD
    };
}

module.exports = {
    getAllEmbeddings,
    invalidateCache,
    getStats
};
