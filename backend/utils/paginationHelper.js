/**
 * page >= 1 and limit clamped to 1..maxLimit; a missing, 0 or non-numeric limit becomes defaultLimit.
 * @param {object} query - req.query
 * @param {{defaultLimit?: number, maxLimit?: number}} [options]
 */
function parsePagination(query, { defaultLimit = 10, maxLimit = 100 } = {}) {
    const page = Math.max(1, parseInt(query.page) || 1);
    const limit = Math.min(maxLimit, Math.max(1, parseInt(query.limit) || defaultLimit));
    const skip = (page - 1) * limit;
    return { page, limit, skip };
}

function buildPaginationMeta(totalCount, page, limit) {
    const totalPages = Math.ceil(totalCount / limit);
    return {
        currentPage: page,
        totalPages,
        totalItems: totalCount,
        limit,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1
    };
}

module.exports = { parsePagination, buildPaginationMeta };
