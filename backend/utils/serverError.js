// The only text a client ever sees for a server-side failure. The real error is logged, never returned:
// raw messages can carry database hosts, credentials, storage endpoints and stack details.
const GENERIC_SERVER_ERROR = 'Terjadi kesalahan pada server';

module.exports = { GENERIC_SERVER_ERROR };
