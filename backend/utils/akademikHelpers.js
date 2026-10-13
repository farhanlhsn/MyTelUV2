/**
 * Pagination helper - sanitize and cap pagination values
 * @param {Object} query - Request query object
 * @param {number} [maxLimit=100] - Maximum allowed limit per page
 * @returns {Object} - { page, limit, skip }
 */
const parsePagination = (query, maxLimit = 100) => {
    const page = Math.max(1, parseInt(query.page) || 1);
    const limit = Math.min(maxLimit, Math.max(1, parseInt(query.limit) || 10));
    const skip = (page - 1) * limit;

    return { page, limit, skip };
};

/**
 * Build pagination response object
 * @param {number} total - Total count of items
 * @param {number} page - Current page number
 * @param {number} limit - Items per page
 * @returns {Object} - Pagination metadata for response
 */
const buildPaginationResponse = (total, page, limit) => ({
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
    hasNextPage: page < Math.ceil(total / limit),
    hasPrevPage: page > 1
});

/**
 * Check if a DOSEN is authorized for a specific kelas
 * @param {Object} user - Authenticated user from req.user
 * @param {Object} kelas - Kelas object with id_dosen
 * @returns {boolean} - True if authorized
 */
const isDosenAuthorizedForKelas = (user, kelas) => {
    // ADMIN always authorized
    if (user.role === 'ADMIN') return true;
    // DOSEN only authorized for their own classes
    if (user.role === 'DOSEN') return user.id_user === kelas.id_dosen;
    // Other roles not authorized
    return false;
};

/**
 * Express middleware for DOSEN/ADMIN kelas authorization
 * Requires kelas object to be set in req.kelas by previous middleware
 */
const requireKelasOwnership = (req, res, next) => {
    const kelas = req.kelas;

    if (!kelas) {
        return res.status(500).json({
            status: "error",
            message: "Kelas not loaded for authorization check"
        });
    }

    if (!isDosenAuthorizedForKelas(req.user, kelas)) {
        return res.status(403).json({
            status: "error",
            message: "You can only access your own classes"
        });
    }

    next();
};

/**
 * Calculate distance between two coordinates using Haversine formula
 * @param {number} lat1 - Latitude of first point
 * @param {number} lon1 - Longitude of first point
 * @param {number} lat2 - Latitude of second point
 * @param {number} lon2 - Longitude of second point
 * @returns {number} - Distance in meters
 */
const haversineDistance = (lat1, lon1, lat2, lon2) => {
    const R = 6371000; // Earth's radius in meters
    const toRad = deg => (deg * Math.PI) / 180;

    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);

    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
};

/**
 * Whether a session counts towards a student's attendance statistics.
 *
 * A session counts when it is closed — closed by hand (`status === false`) or past its end time — and it
 * started on/after the student's enrollment. Running sessions and sessions from before the student joined
 * the class are left out of both "hadir" and "tidak hadir".
 *
 * @param {{mulai: Date|string, selesai: Date|string, status: boolean}} sesi - SesiAbsensi row:
 *        `mulai`/`selesai` are the session start/end instants, `status` is true while the session is open.
 *        Callers filter out soft-deleted sessions (`deletedAt`) themselves.
 * @param {Date|string|null|undefined} enrolledAt - PesertaKelas.createdAt of the student; null/undefined
 *        means "unknown" and only the closed check applies.
 * @param {Date} [now=new Date()]
 * @returns {boolean}
 */
const isCountableSession = (sesi, enrolledAt, now = new Date()) => {
    if (!sesi) return false;

    const ended = new Date(sesi.selesai).getTime() < new Date(now).getTime();
    const closed = sesi.status === false || ended;
    if (!closed) return false;

    if (enrolledAt === null || enrolledAt === undefined) return true;
    return new Date(sesi.mulai).getTime() >= new Date(enrolledAt).getTime();
};

/**
 * True when a Prisma error is a unique-constraint violation: P2002 from model queries, or
 * P2010 carrying Postgres code 23505 from raw queries ($executeRaw / $queryRaw).
 */
const isUniqueViolation = (error) => {
    if (!error) return false;
    if (error.code === 'P2002') return true;
    return error.code === 'P2010' && error.meta?.code === '23505';
};

module.exports = {
    parsePagination,
    buildPaginationResponse,
    isDosenAuthorizedForKelas,
    requireKelasOwnership,
    haversineDistance,
    isCountableSession,
    isUniqueViolation
};
