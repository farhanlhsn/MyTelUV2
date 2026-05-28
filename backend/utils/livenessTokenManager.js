const NodeCache = require('node-cache');
const crypto = require('crypto');

// Cache for liveness tokens, TTL: 5 minutes
const tokenCache = new NodeCache({
    stdTTL: 300,
    checkperiod: 60,
    useClones: false
});

/**
 * Generate a one-time use liveness token for a user
 * @param {number} userId 
 * @returns {Object} { token, expiresAt }
 */
function generateToken(userId) {
    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes from now
    
    // Store in cache with userId as value
    tokenCache.set(token, userId);
    
    return { token, expiresAt };
}

/**
 * Verify and consume a liveness token
 * @param {number} userId 
 * @param {string} token 
 * @returns {boolean} true if valid, false otherwise
 */
function verifyAndConsume(userId, token) {
    if (!token) return false;
    
    const storedUserId = tokenCache.get(token);
    
    if (storedUserId === userId) {
        // Consume token to prevent reuse
        tokenCache.del(token);
        return true;
    }
    
    return false;
}

module.exports = {
    generateToken,
    verifyAndConsume
};
