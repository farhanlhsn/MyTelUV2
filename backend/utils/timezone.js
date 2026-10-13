/**
 * Asia/Jakarta (WIB, UTC+7, no DST) date helpers.
 *
 * All business date logic ("today", day of week, week ranges, report timestamps) goes through
 * these helpers so it never depends on the server's process time zone. Every computation uses
 * Intl with an explicit timeZone, or the fixed +7h offset when building UTC instants.
 */

const TZ = 'Asia/Jakarta';

const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

// Same numbering as Kelas.hari: 1=Senin, 2=Selasa, ... 7=Minggu
const WEEKDAY_NUMBER = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };

const partsFormatter = new Intl.DateTimeFormat('en-US', {
    timeZone: TZ,
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
    weekday: 'short',
    hourCycle: 'h23'
});

const pad2 = (n) => String(n).padStart(2, '0');

const toValidDate = (date) => {
    const d = date instanceof Date ? date : new Date(date);
    if (Number.isNaN(d.getTime())) {
        throw new RangeError('Tanggal tidak valid');
    }
    return d;
};

/**
 * Calendar and clock fields of an instant as seen in Jakarta.
 * @param {Date|string|number} [date=new Date()]
 * @returns {{year: number, month: number, day: number, hour: number, minute: number, second: number, weekday: number}}
 *          month is 1-12; weekday is 1=Senin ... 7=Minggu (the Kelas.hari convention)
 */
const jakartaParts = (date = new Date()) => {
    const raw = {};
    for (const { type, value } of partsFormatter.formatToParts(toValidDate(date))) {
        raw[type] = value;
    }
    return {
        year: Number(raw.year),
        month: Number(raw.month),
        day: Number(raw.day),
        hour: Number(raw.hour) % 24, // some ICU builds print midnight as 24
        minute: Number(raw.minute),
        second: Number(raw.second),
        weekday: WEEKDAY_NUMBER[raw.weekday]
    };
};

/** Day of week in Jakarta, 1=Senin ... 7=Minggu (Kelas.hari convention). */
const jakartaWeekday = (date = new Date()) => jakartaParts(date).weekday;

// UTC instant of 00:00:00.000 WIB on the given Jakarta calendar day (day may overflow, Date.UTC normalises it)
const jakartaMidnight = (year, month, day) => new Date(Date.UTC(year, month - 1, day) - WIB_OFFSET_MS);

/**
 * The Jakarta calendar day containing `date`, as UTC instants.
 * @returns {{start: Date, end: Date}} 00:00:00.000 and 23:59:59.999 WIB
 */
const jakartaDayRange = (date = new Date()) => {
    const { year, month, day } = jakartaParts(date);
    const start = jakartaMidnight(year, month, day);
    return { start, end: new Date(start.getTime() + DAY_MS - 1) };
};

/**
 * The Monday-to-Sunday Jakarta week containing `date`, as UTC instants.
 * @returns {{start: Date, end: Date}} Senin 00:00:00.000 and Minggu 23:59:59.999 WIB
 */
const jakartaWeekRange = (date = new Date()) => {
    const { year, month, day, weekday } = jakartaParts(date);
    const start = jakartaMidnight(year, month, day - (weekday - 1));
    return { start, end: new Date(start.getTime() + 7 * DAY_MS - 1) };
};

/** Jakarta calendar date as "YYYY-MM-DD" (also handy for same-day comparisons). */
const jakartaDateString = (date = new Date()) => {
    const { year, month, day } = jakartaParts(date);
    return `${year}-${pad2(month)}-${pad2(day)}`;
};

/** Jakarta wall-clock time as "HH:MM:SS". */
const jakartaTimeString = (date = new Date()) => {
    const { hour, minute, second } = jakartaParts(date);
    return `${pad2(hour)}:${pad2(minute)}:${pad2(second)}`;
};

/**
 * Report style date: "14/10/2026", or "14/10/2026 01:30" with { withTime: true }.
 */
const formatJakarta = (date = new Date(), { withTime = false } = {}) => {
    const { year, month, day, hour, minute } = jakartaParts(date);
    const datePart = `${pad2(day)}/${pad2(month)}/${year}`;
    return withTime ? `${datePart} ${pad2(hour)}:${pad2(minute)}` : datePart;
};

module.exports = {
    TZ,
    jakartaParts,
    jakartaWeekday,
    jakartaDayRange,
    jakartaWeekRange,
    jakartaDateString,
    jakartaTimeString,
    formatJakarta
};
