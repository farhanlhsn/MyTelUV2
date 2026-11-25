/**
 * Unit Testing - akademikHelpers: which sessions count, unique-violation detection, attendance status
 */

const {
    isCountableSession,
    isUniqueViolation,
    startedAfterEnrollment,
    sessionParticipants,
    STATUS_KEHADIRAN,
    isPresentStatus,
    isExcusedStatus,
    absensiStatus,
    summarizeKehadiran,
    lateThresholdMinutes,
    checkInStatus
} = require('../utils/akademikHelpers');

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

describe('startedAfterEnrollment / sessionParticipants', () => {
    const s = sesi({ mulai: new Date('2026-10-07T01:00:00Z') });

    test('a session counts for a student who enrolled before or exactly at its start', () => {
        expect(startedAfterEnrollment(s, new Date('2026-10-07T00:59:59Z'))).toBe(true);
        expect(startedAfterEnrollment(s, new Date('2026-10-07T01:00:00Z'))).toBe(true);
        expect(startedAfterEnrollment(s, new Date('2026-10-07T01:00:01Z'))).toBe(false);
        expect(startedAfterEnrollment(s, null)).toBe(true);
    });

    test('lists students enrolled by the session start, plus late enrollees who have a record for it', () => {
        const peserta = [
            { id_mahasiswa: 1, createdAt: new Date('2026-10-01T00:00:00Z') },
            { id_mahasiswa: 2, createdAt: new Date('2026-10-08T00:00:00Z') },
            { id_mahasiswa: 3, createdAt: new Date('2026-10-08T00:00:00Z') },
            { id_mahasiswa: 4 }
        ];
        const absensiByUser = new Map([[3, { status: 'IZIN' }]]);

        expect(sessionParticipants(s, peserta, absensiByUser).map((p) => p.id_mahasiswa)).toEqual([1, 3, 4]);
    });
});

describe('attendance status', () => {
    test('the five statuses', () => {
        expect(STATUS_KEHADIRAN).toEqual(['HADIR', 'TELAT', 'IZIN', 'SAKIT', 'ALPHA']);
    });

    test('HADIR and TELAT are present, IZIN and SAKIT are excused, ALPHA and no record are neither', () => {
        expect(['HADIR', 'TELAT', 'IZIN', 'SAKIT', 'ALPHA', null].map(isPresentStatus))
            .toEqual([true, true, false, false, false, false]);
        expect(['HADIR', 'TELAT', 'IZIN', 'SAKIT', 'ALPHA', null].map(isExcusedStatus))
            .toEqual([false, false, true, true, false, false]);
    });

    test('absensiStatus: no row is null, a row without a status is a check-in (HADIR)', () => {
        expect(absensiStatus(undefined)).toBeNull();
        expect(absensiStatus({ id_user: 1 })).toBe('HADIR');
        expect(absensiStatus({ status: 'SAKIT' })).toBe('SAKIT');
    });

    test('summarizeKehadiran: excused sessions leave the percentage denominator, no record is absent', () => {
        expect(summarizeKehadiran(['HADIR', 'TELAT', 'IZIN', 'SAKIT', 'ALPHA', null])).toEqual({
            total: 6, hadir: 2, telat: 1, izin: 1, sakit: 1, tidak_hadir: 2, dihitung: 4, persentase: 50
        });
    });

    test('summarizeKehadiran: 0% when there is nothing to count (no sessions, or every session excused)', () => {
        expect(summarizeKehadiran([]).persentase).toBe(0);
        expect(summarizeKehadiran([]).dihitung).toBe(0);
        expect(summarizeKehadiran(['IZIN', 'SAKIT'])).toMatchObject({ total: 2, hadir: 0, tidak_hadir: 0, dihitung: 0, persentase: 0 });
    });

    test('LATE_THRESHOLD_MINUTES defaults to 15 and ignores invalid values', () => {
        expect(lateThresholdMinutes({})).toBe(15);
        expect(lateThresholdMinutes({ LATE_THRESHOLD_MINUTES: '' })).toBe(15);
        expect(lateThresholdMinutes({ LATE_THRESHOLD_MINUTES: 'abc' })).toBe(15);
        expect(lateThresholdMinutes({ LATE_THRESHOLD_MINUTES: '-5' })).toBe(15);
        expect(lateThresholdMinutes({ LATE_THRESHOLD_MINUTES: '30' })).toBe(30);
        expect(lateThresholdMinutes({ LATE_THRESHOLD_MINUTES: '0' })).toBe(0);
    });

    test('checkInStatus: TELAT only when more than the threshold after the session start', () => {
        const mulai = new Date('2026-10-14T01:00:00Z');
        const at = (minutes) => new Date(mulai.getTime() + minutes * 60 * 1000);

        expect(checkInStatus(mulai, at(0), 15)).toBe('HADIR');
        expect(checkInStatus(mulai, at(15), 15)).toBe('HADIR');
        expect(checkInStatus(mulai, at(15.01), 15)).toBe('TELAT');
        expect(checkInStatus(mulai, at(20), 15)).toBe('TELAT');
        expect(checkInStatus(mulai, at(20), 30)).toBe('HADIR');
    });

    test('checkInStatus reads LATE_THRESHOLD_MINUTES when no threshold is passed', () => {
        const previous = process.env.LATE_THRESHOLD_MINUTES;
        const mulai = new Date('2026-10-14T01:00:00Z');
        const twentyMinutesLater = new Date('2026-10-14T01:20:00Z');
        try {
            delete process.env.LATE_THRESHOLD_MINUTES;
            expect(checkInStatus(mulai, twentyMinutesLater)).toBe('TELAT');
            process.env.LATE_THRESHOLD_MINUTES = '25';
            expect(checkInStatus(mulai, twentyMinutesLater)).toBe('HADIR');
        } finally {
            if (previous === undefined) delete process.env.LATE_THRESHOLD_MINUTES;
            else process.env.LATE_THRESHOLD_MINUTES = previous;
        }
    });
});
