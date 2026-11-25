import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Business dates and times are Asia/Jakarta (WIB, UTC+7, no DST). These helpers show an instant in
/// WIB, in Indonesian, whatever the device time zone or locale is.
const Duration _wibOffset = Duration(hours: 7);
const String _locale = 'id_ID';

bool _localeReady = false;

/// A formatter for [pattern] in Indonesian. `main()` initialises the locale data, but the helpers
/// must not depend on it (tests, a background isolate): `initializeDateFormatting` of the local
/// data does its work synchronously, so doing it once here is enough.
DateFormat _format(String pattern) {
  if (!_localeReady) {
    initializeDateFormatting(_locale);
    _localeReady = true;
  }
  return DateFormat(pattern, _locale);
}

/// The same instant as WIB wall-clock fields (the returned value is flagged UTC, only its fields
/// are meant to be read).
DateTime toWib(DateTime instant) => instant.toUtc().add(_wibOffset);

/// `Rabu, 14 Oktober 2026` (the date of an instant, in WIB)
String formatTanggal(DateTime instant) {
  return _format('EEEE, d MMMM yyyy').format(toWib(instant));
}

/// `14 Okt 2026`
String formatTanggalSingkat(DateTime instant) {
  return _format('d MMM yyyy').format(toWib(instant));
}

/// `01:30` (WIB)
String formatJam(DateTime instant) {
  return _format('HH:mm').format(toWib(instant));
}

/// `14 Oktober 2026, 01:30 WIB`
String formatTanggalJam(DateTime instant) {
  return '${_format('d MMMM yyyy, HH:mm').format(toWib(instant))} WIB';
}

/// A calendar date (a date-picker value, a class date) has no instant: unlike [formatTanggal] it is
/// shown exactly as it is, never shifted by a time zone. `Rabu, 14 Oktober 2026`
String formatTanggalKalender(DateTime date) {
  return _format('EEEE, d MMMM yyyy').format(date);
}

/// `14/10/2026`, for a calendar date as in [formatTanggalKalender].
String formatTanggalAngka(DateTime date) {
  return _format('dd/MM/yyyy').format(date);
}

/// `14/10/2026 01:30 WIB`
String formatWibDateTime(DateTime instant) {
  return '${_format('dd/MM/yyyy HH:mm').format(toWib(instant))} WIB';
}

/// `01:30`
String formatWibTime(DateTime instant) => formatJam(instant);

/// How long ago [instant] was, the way the notification list shows it: `Baru saja`, `5 menit lalu`,
/// the time of day today, `Kemarin, 21:10`, the weekday within a week, then the short date. Days are
/// WIB days. [now] is for tests.
String formatWaktuRelatif(DateTime instant, {DateTime? now}) {
  final DateTime current = now ?? DateTime.now();
  final Duration diff = current.difference(instant);

  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';

  final DateTime wibNow = toWib(current);
  final DateTime wibThen = toWib(instant);
  final int daysAgo = DateTime.utc(wibNow.year, wibNow.month, wibNow.day)
      .difference(DateTime.utc(wibThen.year, wibThen.month, wibThen.day))
      .inDays;

  if (daysAgo < 1) return formatJam(instant);
  if (daysAgo == 1) return 'Kemarin, ${formatJam(instant)}';
  if (daysAgo < 7) {
    return '${_format('EEEE').format(wibThen)}, ${formatJam(instant)}';
  }
  return formatTanggalSingkat(instant);
}
