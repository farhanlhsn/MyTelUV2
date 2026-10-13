import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import 'error_helper.dart';

/// Pure helpers for the attendance flow (home card, absen page). No widgets, no platform calls,
/// so they can be unit tested.

/// Text of the green badge on the "kelas hari ini" card.
String attendanceBadgeLabel(bool requireFace) =>
    requireFace ? 'Absen Wajah' : 'Absen GPS';

// ---------------------------------------------------------------------------
// Geofence
// ---------------------------------------------------------------------------

const double _earthRadiusMeters =
    6371000; // same radius as the backend haversineDistance

/// Great-circle distance in metres between two coordinates.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return _earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// "84 m" below a kilometre, "1,2 km" from a kilometre on (decimal comma).
String formatDistance(double meters) {
  if (meters.isNaN || meters.isInfinite || meters < 0) return '-';
  final rounded = meters.round();
  if (rounded < 1000) return '$rounded m';
  return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// The backend rejects a check-in when distance > radius, so the boundary is still inside.
bool isWithinGeofence(double distanceMeters, int radiusMeter) =>
    distanceMeters <= radiusMeter;

class GeofenceStatus {
  final double distanceMeters;
  final int radiusMeter;

  const GeofenceStatus({
    required this.distanceMeters,
    required this.radiusMeter,
  });

  bool get inRange => isWithinGeofence(distanceMeters, radiusMeter);

  String get summary =>
      'Jarak ke lokasi absensi: ${formatDistance(distanceMeters)} '
      '(radius ${formatDistance(radiusMeter.toDouble())})';
}

/// Distance of the user to the centre of the session geofence, or null when the session has no
/// geofence or the user position is not known yet.
GeofenceStatus? geofenceStatusFor({
  required double? userLat,
  required double? userLng,
  required double? sesiLat,
  required double? sesiLng,
  required int? radiusMeter,
}) {
  if (userLat == null ||
      userLng == null ||
      sesiLat == null ||
      sesiLng == null ||
      radiusMeter == null) {
    return null;
  }
  return GeofenceStatus(
    distanceMeters: haversineMeters(userLat, userLng, sesiLat, sesiLng),
    radiusMeter: radiusMeter,
  );
}

// ---------------------------------------------------------------------------
// Start button
// ---------------------------------------------------------------------------

/// Label of the start button: it waits for the location before it offers [readyLabel].
String attendanceStartLabel({
  required bool hasLocation,
  required bool isGettingLocation,
  required String readyLabel,
}) {
  if (isGettingLocation) return 'Mendapatkan lokasi…';
  if (!hasLocation) return 'Lokasi belum tersedia';
  return readyLabel;
}

/// The button stays disabled until a position is known and no location request is running
/// (a last-known position is shown while the fresh fix is still being acquired).
bool canStartAttendance({
  required bool hasLocation,
  required bool isGettingLocation,
  required bool isBusy,
}) => hasLocation && !isGettingLocation && !isBusy;

// ---------------------------------------------------------------------------
// Location permission / service
// ---------------------------------------------------------------------------

enum LocationIssue { serviceDisabled, denied, deniedForever }

/// The reason a position cannot be read, or null when location is usable.
LocationIssue? locationIssueFor({
  required bool serviceEnabled,
  required LocationPermission permission,
}) {
  if (!serviceEnabled) return LocationIssue.serviceDisabled;
  switch (permission) {
    case LocationPermission.deniedForever:
      return LocationIssue.deniedForever;
    case LocationPermission.denied:
    case LocationPermission.unableToDetermine:
      return LocationIssue.denied;
    case LocationPermission.whileInUse:
    case LocationPermission.always:
      return null;
  }
}

String locationIssueMessage(LocationIssue issue) {
  switch (issue) {
    case LocationIssue.serviceDisabled:
      return 'Lokasi tidak aktif. Silakan aktifkan GPS.';
    case LocationIssue.denied:
      return 'Izin lokasi ditolak. Izinkan akses lokasi untuk melakukan absensi.';
    case LocationIssue.deniedForever:
      return 'Izin lokasi diblokir. Aktifkan izin lokasi di pengaturan aplikasi.';
  }
}

class LocationIssueException implements Exception {
  final LocationIssue issue;

  LocationIssueException(this.issue);

  @override
  String toString() => locationIssueMessage(issue);
}

const String _locationTimeoutMessage =
    'Lokasi belum didapat. Pastikan GPS aktif dan coba di area terbuka.';

/// The problem behind a failed position request when it is one the user can fix in the
/// settings or by granting the permission, else null.
LocationIssue? locationIssueOfError(Object error) {
  if (error is LocationIssueException) return error.issue;
  if (error is LocationServiceDisabledException) {
    return LocationIssue.serviceDisabled;
  }
  if (error is PermissionDeniedException) return LocationIssue.denied;
  return null;
}

/// Indonesian text for any error of a position request: a timeout (GPS has no fix yet), a
/// disabled service / denied permission, or something unexpected.
String locationErrorMessage(Object error) {
  final issue = locationIssueOfError(error);
  if (issue != null) return locationIssueMessage(issue);
  if (error is TimeoutException) return _locationTimeoutMessage;
  return 'Gagal mendapatkan lokasi: ${ErrorHelper.parseError(error)}';
}

// ---------------------------------------------------------------------------
// GPS-only attendance response
// ---------------------------------------------------------------------------

/// "Hadir" / "Terlambat" for the status the backend returns with a check-in.
String kehadiranStatusLabel(String? status) {
  switch (status?.toUpperCase()) {
    case 'HADIR':
      return 'Hadir';
    case 'TELAT':
      return 'Terlambat';
    default:
      return '-';
  }
}

/// The backend `message` of an error body. A geofence rejection also carries `distance` and
/// `required_radius`, which are appended so the student sees how far away they are.
String? attendanceServerMessage(dynamic body) {
  if (body is! Map) return null;
  final message = body['message'];
  if (message is! String || message.trim().isEmpty) return null;

  final distance = body['distance'];
  final radius = body['required_radius'];
  if (distance is num && radius is num) {
    return '${message.trim()}. Jarak: ${distance.round()} m, Radius: ${radius.round()} m';
  }
  return message.trim();
}

/// POST /akademik/absensi answers with the absensi record; reshape it like the face endpoint's
/// `data` ({kelas, ruangan, waktu, status}) so one success card renders both.
Map<String, dynamic> normalizeGpsAbsensiResult(Map<String, dynamic> body) {
  if (body['status'] != 'success') {
    return <String, dynamic>{
      'status': body['status'] ?? 'error',
      'message': body['message'],
    };
  }

  final data = body['data'];
  final record = data is Map ? data : const <dynamic, dynamic>{};
  final kelas = record['kelas'];
  final kelasMap = kelas is Map ? kelas : const <dynamic, dynamic>{};
  final matakuliah = kelasMap['matakuliah'];
  final namaMk = matakuliah is Map ? matakuliah['nama_matakuliah'] : null;

  return <String, dynamic>{
    'status': 'success',
    'message': body['message'],
    'data': <String, dynamic>{
      'kelas': namaMk ?? kelasMap['nama_kelas'],
      'ruangan': kelasMap['ruangan'],
      'waktu': record['createdAt'],
      'status': record['status'],
    },
  };
}
