import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/date_helper.dart';

void main() {
  // First on purpose: nothing in this file calls initializeDateFormatting, so this is the helper's
  // own set-up of the id_ID data (main() does it in the app; tests and background isolates do not)
  test('formats in Indonesian even though no one initialised the locale data', () {
    expect(formatTanggal(DateTime.utc(2026, 10, 13, 18, 30)), 'Rabu, 14 Oktober 2026');
  });

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

  // Chosen pattern: "<hari>, <tanggal> <bulan> <tahun>" in Indonesian, in WIB.
  // 2026-10-13 18:30 UTC is already Wednesday the 14th in Jakarta.
  group('Indonesian (id_ID) formats, always in WIB', () {
    final midnightWib = DateTime.utc(2026, 10, 13, 18, 30);

    test('formatTanggal: weekday, day, full month name, year', () {
      expect(formatTanggal(midnightWib), 'Rabu, 14 Oktober 2026');
      expect(formatTanggal(DateTime.utc(2026, 1, 1, 3)), 'Kamis, 1 Januari 2026');
      expect(formatTanggal(DateTime.utc(2026, 8, 17, 3)), 'Senin, 17 Agustus 2026');
    });

    test('formatTanggalSingkat: day, abbreviated month, year', () {
      expect(formatTanggalSingkat(midnightWib), '14 Okt 2026');
      expect(formatTanggalSingkat(DateTime.utc(2026, 5, 3, 3)), '3 Mei 2026');
    });

    test('formatJam: HH:mm', () {
      expect(formatJam(midnightWib), '01:30');
      expect(formatJam(DateTime.utc(2026, 10, 14, 4, 5)), '11:05');
    });

    test('formatTanggalJam: date, time and the zone', () {
      expect(formatTanggalJam(midnightWib), '14 Oktober 2026, 01:30 WIB');
    });

    test('the device time zone does not matter: a local DateTime gives the same text', () {
      expect(formatTanggal(midnightWib.toLocal()), formatTanggal(midnightWib));
      expect(formatTanggalJam(midnightWib.toLocal()), formatTanggalJam(midnightWib));
    });
  });

  // A calendar date (a date-picker value) has no instant: it must be shown as picked, never shifted
  // by the time zone.
  group('calendar dates (date picker values)', () {
    test('formatTanggalKalender keeps the picked day', () {
      expect(formatTanggalKalender(DateTime(2026, 10, 14)), 'Rabu, 14 Oktober 2026');
      expect(formatTanggalKalender(DateTime(2026, 10, 14, 23, 59)), 'Rabu, 14 Oktober 2026');
    });

    test('formatTanggalAngka: dd/MM/yyyy', () {
      expect(formatTanggalAngka(DateTime(2026, 1, 2)), '02/01/2026');
      expect(formatTanggalAngka(DateTime(2026, 12, 31)), '31/12/2026');
    });
  });

  group('formatWaktuRelatif (notifications, posts and comments)', () {
    // 2026-10-14 10:00 WIB
    final now = DateTime.utc(2026, 10, 14, 3, 0);

    test('under a minute is "Baru saja"', () {
      expect(
        formatWaktuRelatif(now.subtract(const Duration(seconds: 20)), now: now),
        'Baru saja',
      );
    });

    test('under an hour counts minutes', () {
      expect(
        formatWaktuRelatif(now.subtract(const Duration(minutes: 5)), now: now),
        '5 menit lalu',
      );
    });

    test('earlier today shows the WIB time', () {
      expect(
        formatWaktuRelatif(DateTime.utc(2026, 10, 14, 0, 30), now: now),
        '07:30',
      );
    });

    test('yesterday (a WIB day, not 24 hours) says so', () {
      // Tuesday 13 Oct 2026, 21:10 WIB: 13 hours earlier, but yesterday
      expect(
        formatWaktuRelatif(DateTime.utc(2026, 10, 13, 14, 10), now: now),
        'Kemarin, 21:10',
      );
    });

    test('within a week shows the weekday and time, in Indonesian', () {
      // Monday 12 Oct 2026, 09:15 WIB
      expect(
        formatWaktuRelatif(DateTime.utc(2026, 10, 12, 2, 15), now: now),
        'Senin, 09:15',
      );
    });

    test('older than a week shows the short date', () {
      expect(
        formatWaktuRelatif(DateTime.utc(2026, 9, 20, 2, 15), now: now),
        '20 Sep 2026',
      );
    });

    test('crossing midnight WIB changes the calendar day without waiting 24 hours', () {
      // A post at 23:00 WIB, read at 00:15 WIB the following day.
      expect(
        formatWaktuRelatif(
          DateTime.utc(2026, 10, 13, 16),
          now: DateTime.utc(2026, 10, 13, 17, 15),
        ),
        'Kemarin, 23:00',
      );
    });

    test('exactly one hour, one week and a future timestamp have readable labels', () {
      expect(formatWaktuRelatif(now.subtract(const Duration(hours: 1)), now: now), '09:00');
      expect(formatWaktuRelatif(now.subtract(const Duration(days: 7)), now: now), '7 Okt 2026');
      expect(formatWaktuRelatif(now.add(const Duration(minutes: 1)), now: now), 'Baru saja');
    });
  });
}
