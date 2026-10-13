import 'package:flutter/material.dart';

/// Attendance statuses of the server (`StatusKehadiran`), in the order the override sheet lists them.
/// HADIR/TELAT are present, IZIN/SAKIT are excused, ALPHA is absent.
const List<String> attendanceStatuses = <String>['HADIR', 'TELAT', 'IZIN', 'SAKIT', 'ALPHA'];

/// Colours: clearly distinct and never the only cue (every status also has a label and an icon).
const Color _hadir = Color(0xFF16A34A); // green
const Color _telat = Color(0xFFF59E0B); // amber
const Color _izin = Color(0xFF2563EB); // blue
const Color _sakit = Color(0xFF7C3AED); // purple
const Color _alpha = Color(0xFFDC2626); // red
const Color _noRecord = Color(0xFF6B7280); // grey

/// A known status in upper case, or null when [raw] is null, blank, unknown or not a string.
String? normalizeAttendanceStatus(Object? raw) {
  if (raw is! String) return null;
  final String value = raw.trim().toUpperCase();
  return attendanceStatuses.contains(value) ? value : null;
}

/// Label shown to the user. Without a record (null or unknown status) it is "Belum absen" while
/// the session is open (the student can still check in) and "Tidak hadir" once it is closed.
String attendanceStatusLabel(String? status, {bool sessionOpen = false}) {
  switch (normalizeAttendanceStatus(status)) {
    case 'HADIR':
      return 'Hadir';
    case 'TELAT':
      return 'Telat';
    case 'IZIN':
      return 'Izin';
    case 'SAKIT':
      return 'Sakit';
    case 'ALPHA':
      return 'Alpha';
    default:
      return sessionOpen ? 'Belum absen' : 'Tidak hadir';
  }
}

Color attendanceStatusColor(String? status) {
  switch (normalizeAttendanceStatus(status)) {
    case 'HADIR':
      return _hadir;
    case 'TELAT':
      return _telat;
    case 'IZIN':
      return _izin;
    case 'SAKIT':
      return _sakit;
    case 'ALPHA':
      return _alpha;
    default:
      return _noRecord;
  }
}

IconData attendanceStatusIcon(String? status) {
  switch (normalizeAttendanceStatus(status)) {
    case 'HADIR':
      return Icons.check_circle;
    case 'TELAT':
      return Icons.schedule;
    case 'IZIN':
      return Icons.assignment_turned_in;
    case 'SAKIT':
      return Icons.local_hospital;
    case 'ALPHA':
      return Icons.cancel;
    default:
      return Icons.help_outline;
  }
}

/// HADIR and TELAT count as present.
bool isPresentAttendance(String? status) {
  final String? value = normalizeAttendanceStatus(status);
  return value == 'HADIR' || value == 'TELAT';
}

/// The status of a session of the student history or of a peserta of a session detail: its
/// `status`, null without a record. A row from before statuses existed only has `hadir`.
String? attendanceStatusOf(Map<String, dynamic> row) {
  final String? status = normalizeAttendanceStatus(row['status']);
  if (status != null) return status;
  return row['hadir'] == true ? 'HADIR' : null;
}

/// Counts of a list of statuses with the server's rules: IZIN/SAKIT are excused and leave the
/// percentage's denominator, ALPHA and "no record" (null) are absent, `hadir` includes `telat`.
class AttendanceSummary {
  final int total;
  final int hadir;
  final int telat;
  final int izin;
  final int sakit;
  final int tidakHadir;

  const AttendanceSummary({
    required this.total,
    required this.hadir,
    required this.telat,
    required this.izin,
    required this.sakit,
    required this.tidakHadir,
  });

  /// What the percentage is taken over: everything but the excused.
  int get dihitung => total - izin - sakit;

  double get persentase => dihitung > 0 ? hadir / dihitung * 100 : 0;

  /// Same text as the server: one decimal, or `0` when nothing is countable.
  String get persentaseLabel => dihitung > 0 ? persentase.toStringAsFixed(1) : '0';
}

AttendanceSummary summarizeAttendance(Iterable<String?> statuses) {
  int total = 0;
  int hadir = 0;
  int telat = 0;
  int izin = 0;
  int sakit = 0;
  int tidakHadir = 0;

  for (final String? raw in statuses) {
    total++;
    switch (normalizeAttendanceStatus(raw)) {
      case 'HADIR':
        hadir++;
      case 'TELAT':
        hadir++;
        telat++;
      case 'IZIN':
        izin++;
      case 'SAKIT':
        sakit++;
      default:
        tidakHadir++;
    }
  }

  return AttendanceSummary(
    total: total,
    hadir: hadir,
    telat: telat,
    izin: izin,
    sakit: sakit,
    tidakHadir: tidakHadir,
  );
}

/// The attendance percentage of a student over all their classes together, from the student
/// history (`GET /akademik/absensi/ku/history`). Every class carries the server's own `stats`, which
/// count each closed session of the class since the enrollment (one without a record is absent, so
/// a missed session shows even though it left no row) and leave izin/sakit out of the denominator.
/// Present sessions over countable sessions; nothing countable is 0, not 100.
double overallAttendancePercentage(Iterable<Map<String, dynamic>> history) {
  int hadir = 0;
  int dihitung = 0;

  for (final Map<String, dynamic> kelas in history) {
    final Object? stats = kelas['stats'];
    if (stats is! Map) continue;
    int count(String key) => (stats[key] as num?)?.toInt() ?? 0;

    hadir += count('total_hadir');
    dihitung += count('total_sesi') - count('total_izin') - count('total_sakit');
  }

  return dihitung > 0 ? hadir / dihitung * 100 : 0;
}

/// The attendance line of the Home top bar: "Kehadiran: 83.3%", or "Kehadiran: -" while the
/// percentage is unknown (not loaded yet, or the first load failed), so no number is made up.
String kehadiranLabel(double? percentage) {
  if (percentage == null) return 'Kehadiran: -';
  return 'Kehadiran: ${percentage.toStringAsFixed(1)}%';
}

/// "3/4 sesi hadir" for the class card of the student history. Izin and sakit are not part of the
/// denominator (same as the percentage), they are named separately: "3/4 sesi hadir • 2 izin/sakit".
String sesiHadirText(Map<String, dynamic>? stats) {
  int count(String key) => (stats?[key] as num?)?.toInt() ?? 0;

  final int hadir = count('total_hadir');
  final int excused = count('total_izin') + count('total_sakit');
  final int dihitung = count('total_sesi') - excused;

  final String text = '$hadir/$dihitung sesi hadir';
  return excused > 0 ? '$text • $excused izin/sakit' : text;
}
