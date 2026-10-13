import 'package:intl/intl.dart';

/// Business dates and times are Asia/Jakarta (WIB, UTC+7, no DST). These helpers show an instant in
/// WIB whatever the device time zone is.
const Duration _wibOffset = Duration(hours: 7);

/// The same instant as WIB wall-clock fields (the returned value is flagged UTC, only its fields
/// are meant to be read).
DateTime toWib(DateTime instant) => instant.toUtc().add(_wibOffset);

/// `14/10/2026 01:30 WIB`
String formatWibDateTime(DateTime instant) {
  return '${DateFormat('dd/MM/yyyy HH:mm').format(toWib(instant))} WIB';
}

/// `01:30`
String formatWibTime(DateTime instant) {
  return DateFormat('HH:mm').format(toWib(instant));
}
