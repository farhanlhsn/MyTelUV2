const { normalizePlate } = require('../utils/plate');

describe('normalizePlate', () => {
    test.each([
        ['b 1234-xyz', 'B1234XYZ'],
        [' D 12 AB ', 'D12AB'],
        ['B 1234 XYZ', 'B1234XYZ'],
        ['b.1234_xyz', 'B1234XYZ'],
        ['B1234XYZ', 'B1234XYZ'],
        ['---', ''],
        ['', '']
    ])('normalises %j to %j', (raw, expected) => {
        expect(normalizePlate(raw)).toBe(expected);
    });

    test('returns an empty string for null and undefined', () => {
        expect(normalizePlate(null)).toBe('');
        expect(normalizePlate(undefined)).toBe('');
    });

    test('is idempotent', () => {
        const once = normalizePlate('d 5678-abc');
        expect(normalizePlate(once)).toBe(once);
    });
});
