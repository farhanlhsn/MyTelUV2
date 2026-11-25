// Single place that builds the request headers for the Python AI services (face, plate, anomaly).
//
// Every call must carry `X-API-Key`: the services fail closed, answering 503 while their key is not
// configured and 401 when the header is missing or wrong. The key is read from the environment on
// every call. Test mode is deliberately NOT part of this: the services decide it from their own
// TEST_MODE env, so the backend never sends an `X-Test-Mode` header.
const API_KEY_ENV = {
    face: 'FACE_API_KEY',
    plate: 'PLATE_API_KEY',
    anomaly: 'ANOMALY_API_KEY',
};

/**
 * @param {'face'|'plate'|'anomaly'} service
 * @param {object} [extraHeaders] e.g. `form.getHeaders()` or `{ 'Content-Type': 'application/json' }`
 * @returns {object} extraHeaders plus X-API-Key (which extraHeaders cannot override)
 */
const pythonServiceHeaders = (service, extraHeaders = {}) => {
    const envName = API_KEY_ENV[service];
    if (!envName) {
        throw new Error(`Unknown Python service: ${service}`);
    }
    return { ...extraHeaders, 'X-API-Key': process.env[envName] || '' };
};

module.exports = { pythonServiceHeaders };
