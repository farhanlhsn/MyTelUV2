function parsePagination(query) {
    const page = Math.max(1, parseInt(query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(query.limit) || 10));
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
