/**
 * Single plate normaliser: uppercase, keep only A-Z and 0-9.
 * "b 1234-xyz" -> "B1234XYZ". Anything nullish becomes an empty string.
 */
const normalizePlate = (raw) => String(raw ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '');

module.exports = { normalizePlate };
