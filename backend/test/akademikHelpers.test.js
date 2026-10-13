/**
 * Unit Testing - akademikHelpers: which sessions count, unique-violation detection
 */

const { isCountableSession, isUniqueViolation } = require('../utils/akademikHelpers');

const NOW = new Date('2026-10-14T10:00:00Z');
const ENROLLED_AT = new Date('2026-10-01T00:00:00Z');

const sesi = (overrides = {}) => ({
    mulai: new Date('2026-10-07T01:00:00Z'),
    selesai: new Date('2026-10-07T03:00:00Z'),
    status: false,
    ...overrides
});

describe('isCountableSession', () => {
    test('a closed session after enrollment counts', () => {
        expect(isCountableSession(sesi(), ENROLLED_AT, NOW)).toBe(true);
    });

    test('a session still marked open but past its end time counts', () => {
        expect(isCountableSession(sesi({ status: true }), ENROLLED_AT, NOW)).toBe(true);
    });

    test('an open session that has not ended yet does not count', () => {
        const running = sesi({
            status: true,
            mulai: new Date('2026-10-14T09:00:00Z'),
            selesai: new Date('2026-10-14T11:00:00Z')
        });
        expect(isCountableSession(running, ENROLLED_AT, NOW)).toBe(false);
    });

    test('a session closed early by the dosen counts even before its planned end', () => {
        const closedEarly = sesi({
            status: false,
            mulai: new Date('2026-10-14T09:00:00Z'),
            selesai: new Date('2026-10-14T11:00:00Z')
        });
        expect(isCountableSession(closedEarly, ENROLLED_AT, NOW)).toBe(true);
    });

    test('a session that started before the student enrolled does not count', () => {
        const before = sesi({ mulai: new Date('2026-09-30T01:00:00Z'), selesai: new Date('2026-09-30T03:00:00Z') });
        expect(isCountableSession(before, ENROLLED_AT, NOW)).toBe(false);
    });

    test('a session starting exactly at enrollment counts', () => {
        expect(isCountableSession(sesi({ mulai: ENROLLED_AT }), ENROLLED_AT, NOW)).toBe(true);
    });

    test('without an enrollment date only the closed check applies', () => {
        expect(isCountableSession(sesi(), null, NOW)).toBe(true);
        expect(isCountableSession(sesi(), undefined, NOW)).toBe(true);
        expect(isCountableSession(sesi({ status: true, selesai: new Date('2026-10-15T00:00:00Z') }), null, NOW)).toBe(false);
    });

    test('accepts ISO strings for every date', () => {
        const s = { mulai: '2026-10-07T01:00:00Z', selesai: '2026-10-07T03:00:00Z', status: true };
        expect(isCountableSession(s, '2026-10-01T00:00:00Z', NOW)).toBe(true);
        expect(isCountableSession(s, '2026-10-08T00:00:00Z', NOW)).toBe(false);
    });

    test('now defaults to the current time', () => {
        expect(isCountableSession(sesi({ status: true, selesai: new Date('2000-01-01T00:00:00Z') }), null)).toBe(true);
        expect(isCountableSession(sesi({ status: true, selesai: new Date('2999-01-01T00:00:00Z') }), null)).toBe(false);
    });

    test('a missing session never counts', () => {
        expect(isCountableSession(null, ENROLLED_AT, NOW)).toBe(false);
    });
});

describe('isUniqueViolation', () => {
    test('recognises a Prisma P2002 error', () => {
        expect(isUniqueViolation({ code: 'P2002' })).toBe(true);
    });

    test('recognises a raw query unique violation (P2010 with Postgres 23505)', () => {
        expect(isUniqueViolation({ code: 'P2010', meta: { code: '23505', message: 'duplicate key value' } })).toBe(true);
    });

    test('ignores other errors', () => {
        expect(isUniqueViolation({ code: 'P2010', meta: { code: '23503' } })).toBe(false);
        expect(isUniqueViolation(new Error('boom'))).toBe(false);
        expect(isUniqueViolation(undefined)).toBe(false);
    });
});
