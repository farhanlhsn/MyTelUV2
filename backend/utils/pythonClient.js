// Dedicated axios instance for calls from the backend to the Python AI services (face, plate, anomaly).
//
// Retries live on THIS instance only; the global axios is left alone, so other callers (for example
// the content moderator) never inherit them. Only idempotent reads (GET/HEAD) are retried: a POST
// carries a multipart/form-data stream that is already consumed after the first attempt, and the
// service may have processed it before the connection broke, so replaying it is never safe.
//
// Headers are not set here: every call builds them with `pythonServiceHeaders(service, ...)`.
const axios = require('axios');
const axiosRetry = require('axios-retry').default;

const RETRYABLE_METHODS = new Set(['get', 'head']);
const MAX_RETRIES = 3;

/**
 * Retry condition of the Python client.
 * - GET/HEAD only; any other (or unknown) method is never retried.
 * - Retries network errors, timeouts (ECONNABORTED), 429 and 5xx; client errors (4xx) and
 *   cancelled requests are final.
 * @param {import('axios').AxiosError} error
 * @returns {boolean}
 */
const shouldRetryPythonRequest = (error) => {
    const method = String(error?.config?.method || '').toLowerCase();
    if (!RETRYABLE_METHODS.has(method)) return false;
    if (error.code === 'ERR_CANCELED') return false;
    return error.code === 'ECONNABORTED' || axiosRetry.isRetryableError(error);
};

const pythonClient = axios.create();

axiosRetry(pythonClient, {
    retries: MAX_RETRIES,
    retryDelay: axiosRetry.exponentialDelay,
    retryCondition: shouldRetryPythonRequest,
    onRetry: (retryCount, error, requestConfig) => {
        console.log(
            `[PythonService] Retry attempt ${retryCount} for ${requestConfig.url}: ${error.message}`,
        );
    },
});

module.exports = { pythonClient, shouldRetryPythonRequest };
