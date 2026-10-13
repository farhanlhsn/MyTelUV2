const { authenticateToken } = require('./authMiddleware');

// Socket.IO handshake authentication (`io.use(socketAuth)`).
// The client passes its JWT as `auth: { token }` (never in the URL, which ends up in proxy logs) and it is
// verified exactly like an HTTP Bearer token. Every failure is the same opaque `Unauthorized`, so
// a client cannot tell a bad signature from a deactivated account or a database problem.
const socketAuth = async (socket, next) => {
    const token = socket.handshake?.auth?.token;

    if (typeof token !== 'string' || token === '') {
        return next(new Error('Unauthorized'));
    }

    try {
        const user = await authenticateToken(token);
        if (!user) {
            return next(new Error('Unauthorized'));
        }
        socket.user = user;
        return next();
    } catch (err) {
        return next(new Error('Unauthorized'));
    }
};

module.exports = { socketAuth };
