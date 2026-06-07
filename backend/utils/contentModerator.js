const axios = require('axios');

/**
 * Moderate content using OpenAI Moderation API.
 * Uses a fail-open approach so if the API is down or times out, the content is allowed.
 * @param {string} text - Content to moderate.
 * @returns {Promise<{ flagged: boolean, categories?: object }>}
 */
const moderateContent = async (text) => {
    if (!text || typeof text !== 'string' || text.trim() === '') {
        return { flagged: false };
    }

    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
        console.warn('[ContentModerator] OPENAI_API_KEY not configured. Content allowed without moderation.');
        return { flagged: false };
    }

    try {
        const response = await axios.post(
            'https://api.openai.com/v1/moderations',
            { input: text },
            {
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${apiKey}`
                },
                timeout: 5000 // 5 seconds timeout
            }
        );

        const result = response.data?.results?.[0];
        if (result) {
            return {
                flagged: result.flagged,
                categories: result.categories
            };
        }

        return { flagged: false };
    } catch (error) {
        console.error('[ContentModerator] OpenAI Moderation API call failed:', error.message);
        // Fail-open: allow content if API is down
        return { flagged: false };
    }
};

module.exports = { moderateContent };
