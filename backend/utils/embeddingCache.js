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
 * Get all active face embeddings with user data (Admin only).
 * Returns cached data if available, otherwise fetches from database.
 * 
 * @returns {Promise<Array>} Array of biometric data with user info
 */
async function getAllEmbeddings() {
    // Check cache first
    const cached = cache.get(CACHE_KEY);
    if (cached) {
        console.log('[EmbeddingCache] Cache hit - returning all cached embeddings');
        return cached;
    }

    console.log('[EmbeddingCache] Cache miss - fetching all from database');

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
 * Get single active user face embedding template.
 * Returns cached data if available, otherwise fetches from database.
 * 
 * @param {number} id_user 
 * @returns {Promise<Object|null>} Biometric data with user info
 */
async function getUserEmbedding(id_user) {
    const key = `user_embedding:${id_user}`;
    
    // Check cache first
    const cached = cache.get(key);
    if (cached) {
        console.log(`[EmbeddingCache] Cache hit - returning cached embedding for user ${id_user}`);
        return cached;
    }

    console.log(`[EmbeddingCache] Cache miss - fetching embedding for user ${id_user} from database`);

    // Fetch from database
    const userBiometric = await prisma.dataBiometrik.findUnique({
        where: {
            id_user: parseInt(id_user),
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

    // Store in cache if found
    if (userBiometric) {
        cache.set(key, userBiometric);
        console.log(`[EmbeddingCache] Cached embedding for user ${id_user} (TTL: ${CACHE_TTL}s)`);
    }

    return userBiometric;
}

/**
 * Invalidate the embeddings cache.
 * Should be called when biometric data is added, edited, or deleted.
 * 
 * @param {number} [id_user] Optional user ID to invalidate user-specific cache
 */
function invalidateCache(id_user) {
    if (id_user) {
        // Invalidate specific user cache
        const userKey = `user_embedding:${id_user}`;
        cache.del(userKey);
        // Also invalidate global cache just in case
        cache.del(CACHE_KEY);
        console.log(`[EmbeddingCache] Invalidated cache for user ${id_user} and global`);
    } else {
        // Flush all keys
        cache.flushAll();
        console.log('[EmbeddingCache] Entire cache flushed');
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
    getUserEmbedding,
    invalidateCache,
    getStats
};
