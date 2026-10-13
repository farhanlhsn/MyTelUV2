import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/date_helper.dart';

void main() {
  test('toWib shifts a UTC instant by +7 hours', () {
    final wib = toWib(DateTime.utc(2026, 10, 13, 18, 30));
    expect(wib.year, 2026);
    expect(wib.month, 10);
    expect(wib.day, 14);
    expect(wib.hour, 1);
    expect(wib.minute, 30);
  });

  test('formatWibDateTime zero-pads and labels the zone', () {
    expect(
      formatWibDateTime(DateTime.utc(2026, 10, 13, 18, 30)),
      '14/10/2026 01:30 WIB',
    );
    expect(
      formatWibDateTime(DateTime.utc(2026, 1, 2, 0, 5)),
      '02/01/2026 07:05 WIB',
    );
  });

  test('formatWibTime pads the hour', () {
    expect(formatWibTime(DateTime.utc(2026, 1, 1, 0, 5)), '07:05');
    expect(formatWibTime(DateTime.utc(2026, 1, 1, 2, 9)), '09:09');
  });

  test('a local DateTime is converted through UTC, not read as-is', () {
    final instant = DateTime.utc(2026, 3, 1, 10, 0);
    expect(formatWibTime(instant.toLocal()), formatWibTime(instant));
  });
}
