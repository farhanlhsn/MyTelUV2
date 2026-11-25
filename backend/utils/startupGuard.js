// TEST_MODE replaces real face/plate verification with stubs, so a production process must never run with it.
// Pure on purpose: server.js applies it right after dotenv (before any route or listener is loaded)
// and the unit test exercises every combination without spawning a process.
const shouldRefuseStart = (env = process.env) =>
    env.NODE_ENV === 'production' && env.TEST_MODE === 'true';

module.exports = { shouldRefuseStart };
