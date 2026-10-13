/**
 * Unit Testing - Asia/Jakarta time helpers (utils/timezone)
 *
 * Every assertion uses an explicit UTC instant and checks the Jakarta (WIB, UTC+7) result,
 * so the tests pass whatever time zone the machine running them is in.
 */

const {
    TZ,
    jakartaParts,
    jakartaWeekday,
    jakartaDayRange,
    jakartaWeekRange,
    jakartaDateString,
    jakartaTimeString,
    formatJakarta,
    parseJakartaDateTime
} = require('../utils/timezone');

// 01:30 WIB on Wednesday 14 October 2026, which is still Tuesday 13 October in UTC
const AFTER_MIDNIGHT_WIB = new Date('2026-10-13T18:30:00Z');

describe('utils/timezone', () => {
    test('the business time zone is Asia/Jakarta', () => {
        expect(TZ).toBe('Asia/Jakarta');
    });

    describe('jakartaParts', () => {
        test('18:30 UTC is already the next day in Jakarta', () => {
            expect(jakartaParts(AFTER_MIDNIGHT_WIB)).toMatchObject({
                year: 2026,
                month: 10,
                day: 14,
                hour: 1,
                minute: 30,
                weekday: 3 // Rabu, same numbering as Kelas.hari (1=Senin ... 7=Minggu)
            });
        });

        test('midnight WIB is hour 0, not 24', () => {
            expect(jakartaParts(new Date('2026-10-13T17:00:00Z'))).toMatchObject({ day: 14, hour: 0, minute: 0 });
        });

        test('accepts an ISO string', () => {
            expect(jakartaParts('2026-10-13T18:30:00Z')).toMatchObject({ day: 14, hour: 1 });
        });

        test('rejects an invalid date', () => {
            expect(() => jakartaParts(new Date('not-a-date'))).toThrow(RangeError);
        });
    });

    describe('jakartaWeekday (1=Senin ... 7=Minggu, like Kelas.hari)', () => {
        test('Wednesday in Jakarta while UTC is still Tuesday', () => {
            expect(jakartaWeekday(AFTER_MIDNIGHT_WIB)).toBe(3);
        });

        test('Sunday is 7 and the following Monday is 1', () => {
            expect(jakartaWeekday(new Date('2026-10-18T03:00:00Z'))).toBe(7); // Minggu 10:00 WIB
            expect(jakartaWeekday(new Date('2026-10-18T17:30:00Z'))).toBe(1); // Senin 00:30 WIB
        });
    });

    describe('jakartaDayRange', () => {
        test('spans 00:00:00.000 to 23:59:59.999 WIB of the Jakarta day', () => {
            const { start, end } = jakartaDayRange(AFTER_MIDNIGHT_WIB);
            expect(start.toISOString()).toBe('2026-10-13T17:00:00.000Z');
            expect(end.toISOString()).toBe('2026-10-14T16:59:59.999Z');
        });

        test('the last millisecond of a WIB day stays in that day', () => {
            const { start } = jakartaDayRange(new Date('2026-10-13T16:59:59.999Z'));
            expect(start.toISOString()).toBe('2026-10-12T17:00:00.000Z');
        });

        test('a date-only string means that calendar day in Jakarta', () => {
            const { start, end } = jakartaDayRange(new Date('2026-10-14'));
            expect(start.toISOString()).toBe('2026-10-13T17:00:00.000Z');
            expect(end.toISOString()).toBe('2026-10-14T16:59:59.999Z');
        });
    });

    describe('jakartaWeekRange', () => {
        test('runs from Monday 00:00 WIB to Sunday 23:59:59.999 WIB', () => {
            const { start, end } = jakartaWeekRange(AFTER_MIDNIGHT_WIB);
            expect(start.toISOString()).toBe('2026-10-11T17:00:00.000Z'); // Senin 12/10 00:00 WIB
            expect(end.toISOString()).toBe('2026-10-18T16:59:59.999Z'); // Minggu 18/10 23:59:59.999 WIB
        });

        test('Sunday evening belongs to the week that started on the previous Monday', () => {
            const { start } = jakartaWeekRange(new Date('2026-10-18T15:00:00Z')); // Minggu 22:00 WIB
            expect(start.toISOString()).toBe('2026-10-11T17:00:00.000Z');
        });
    });

    describe('string formatting', () => {
        test('jakartaDateString gives the Jakarta calendar date', () => {
            expect(jakartaDateString(AFTER_MIDNIGHT_WIB)).toBe('2026-10-14');
        });

        test('jakartaTimeString gives the Jakarta wall-clock time', () => {
            expect(jakartaTimeString(AFTER_MIDNIGHT_WIB)).toBe('01:30:00');
        });

        test('formatJakarta uses the report style', () => {
            expect(formatJakarta(AFTER_MIDNIGHT_WIB, { withTime: true })).toBe('14/10/2026 01:30');
            expect(formatJakarta(AFTER_MIDNIGHT_WIB)).toBe('14/10/2026');
        });
    });

    describe('parseJakartaDateTime (client dates; no offset = WIB wall-clock time)', () => {
        test('a date-only value is 00:00 WIB of that day', () => {
            expect(parseJakartaDateTime('2026-10-14')).toEqual(new Date('2026-10-13T17:00:00.000Z'));
        });

        test('a date-time without offset (what the mobile app sends) is read as WIB', () => {
            expect(parseJakartaDateTime('2026-10-14T00:00:00.000')).toEqual(new Date('2026-10-13T17:00:00.000Z'));
            expect(parseJakartaDateTime('2026-10-14T09:30')).toEqual(new Date('2026-10-14T02:30:00.000Z'));
        });

        test('a value with Z or an offset is that instant', () => {
            expect(parseJakartaDateTime('2026-10-13T17:30:00.000Z')).toEqual(new Date('2026-10-13T17:30:00.000Z'));
            expect(parseJakartaDateTime('2026-10-14T08:00:00+08:00')).toEqual(new Date('2026-10-14T00:00:00.000Z'));
        });

        test.each([['besok'], [''], ['14/10/2026'], ['2026-13-40'], ['2026-02-30'], ['2026-10-14T25:00'], [null], [undefined], [20261014]])('%p is not a date (null)', (value) => {
            expect(parseJakartaDateTime(value)).toBeNull();
        });
    });
});
