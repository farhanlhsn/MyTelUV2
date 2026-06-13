const crypto = require('crypto');

const secretsMatch = (providedSecret, configuredSecret) => {
    if (!providedSecret || !configuredSecret) {
        return false;
    }

    const providedBuffer = Buffer.from(providedSecret);
    const configuredBuffer = Buffer.from(configuredSecret);

    return providedBuffer.length === configuredBuffer.length
        && crypto.timingSafeEqual(providedBuffer, configuredBuffer);
};

exports.protectEdgeDevice = (req, res, next) => {
    const configuredSecret = process.env.EDGE_DEVICE_SECRET;

    if (!configuredSecret) {
        console.error('EDGE_DEVICE_SECRET is not configured');
        return res.status(503).json({
            status: 'error',
            message: 'Edge device authentication is not configured',
            data: { gate_action: 'DENY' }
        });
    }

    const providedSecret = req.get('X-Edge-Secret');
    if (!secretsMatch(providedSecret, configuredSecret)) {
        return res.status(401).json({
            status: 'error',
            message: 'Unauthorized edge device',
            data: { gate_action: 'DENY' }
        });
    }

    next();
};
