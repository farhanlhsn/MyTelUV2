import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile/utils/attendance_helper.dart';
import 'package:mobile/utils/attendance_status.dart';

void main() {
  group('attendanceBadgeLabel', () {
    test('face sessions say "Absen Wajah"', () {
      expect(attendanceBadgeLabel(true), 'Absen Wajah');
    });

    test('GPS-only sessions say "Absen GPS"', () {
      expect(attendanceBadgeLabel(false), 'Absen GPS');
    });
  });

  group('formatDistance', () {
    test('shows metres below one kilometre', () {
      expect(formatDistance(0), '0 m');
      expect(formatDistance(84.4), '84 m');
      expect(formatDistance(999.4), '999 m');
    });

    test('rolls a value that rounds to 1000 m over to km', () {
      expect(formatDistance(999.6), '1,0 km');
    });

    test('shows kilometres with a decimal comma from one kilometre', () {
      expect(formatDistance(1000), '1,0 km');
      expect(formatDistance(1234), '1,2 km');
      expect(formatDistance(15800), '15,8 km');
    });

    test('shows a dash for values that are not a distance', () {
      expect(formatDistance(double.nan), '-');
      expect(formatDistance(-5), '-');
    });
  });

  group('haversineMeters', () {
    test('is zero for the same point', () {
      expect(haversineMeters(-6.9732, 107.6303, -6.9732, 107.6303), 0);
    });

    test('one thousandth of a degree of latitude is about 111 m', () {
      final d = haversineMeters(-6.9730, 107.6300, -6.9740, 107.6300);
      expect(d, closeTo(111.2, 1.0));
    });

    test('is symmetric', () {
      final a = haversineMeters(-6.97, 107.63, -6.90, 107.60);
      final b = haversineMeters(-6.90, 107.60, -6.97, 107.63);
      expect(a, closeTo(b, 0.001));
    });
  });

  group('geofenceStatusFor', () {
    test('is null when the session has no coordinates', () {
      expect(
        geofenceStatusFor(
          userLat: -6.97,
          userLng: 107.63,
          sesiLat: null,
          sesiLng: null,
          radiusMeter: null,
        ),
        isNull,
      );
    });

    test('is null while the user position is unknown', () {
      expect(
        geofenceStatusFor(
          userLat: null,
          userLng: null,
          sesiLat: -6.97,
          sesiLng: 107.63,
          radiusMeter: 100,
        ),
        isNull,
      );
    });

    test('is in range inside the radius and on the boundary', () {
      final inside = geofenceStatusFor(
        userLat: -6.9731,
        userLng: 107.6300,
        sesiLat: -6.9730,
        sesiLng: 107.6300,
        radiusMeter: 100,
      )!;
      expect(inside.inRange, isTrue);
      expect(inside.distanceMeters, closeTo(11.1, 1.0));
      expect(inside.radiusMeter, 100);

      expect(isWithinGeofence(100, 100), isTrue);
      expect(isWithinGeofence(100.1, 100), isFalse);
    });

    test('is out of range beyond the radius', () {
      final outside = geofenceStatusFor(
        userLat: -6.9830,
        userLng: 107.6300,
        sesiLat: -6.9730,
        sesiLng: 107.6300,
        radiusMeter: 100,
      )!;
      expect(outside.inRange, isFalse);
      expect(outside.distanceMeters, closeTo(1112, 5));
    });

    test('summary text names the distance and the radius', () {
      final status = geofenceStatusFor(
        userLat: -6.9731,
        userLng: 107.6300,
        sesiLat: -6.9730,
        sesiLng: 107.6300,
        radiusMeter: 100,
      )!;
      expect(status.summary, 'Jarak ke lokasi absensi: 11 m (radius 100 m)');
    });
  });

  group('attendanceStartLabel', () {
    test('says "Mendapatkan lokasi…" while the location is being acquired', () {
      expect(
        attendanceStartLabel(
          hasLocation: false,
          isGettingLocation: true,
          readyLabel: 'Mulai Absen',
        ),
        'Mendapatkan lokasi…',
      );
    });

    test('says the location is unavailable once acquisition failed', () {
      expect(
        attendanceStartLabel(
          hasLocation: false,
          isGettingLocation: false,
          readyLabel: 'Mulai Absen',
        ),
        'Lokasi belum tersedia',
      );
    });

    test('uses the ready label when a position is known', () {
      expect(
        attendanceStartLabel(
          hasLocation: true,
          isGettingLocation: false,
          readyLabel: 'Mulai Absen',
        ),
        'Mulai Absen',
      );
    });

    test('keeps waiting while a fresh fix is still being acquired', () {
      // last-known position already present, fresh fix not yet
      expect(
        attendanceStartLabel(
          hasLocation: true,
          isGettingLocation: true,
          readyLabel: 'Mulai Absen',
        ),
        'Mendapatkan lokasi…',
      );
    });
  });

  group('canStartAttendance', () {
    test('needs a settled position and no request in flight', () {
      expect(
        canStartAttendance(
          hasLocation: true,
          isGettingLocation: false,
          isBusy: false,
        ),
        isTrue,
      );
      expect(
        canStartAttendance(
          hasLocation: false,
          isGettingLocation: false,
          isBusy: false,
        ),
        isFalse,
      );
      expect(
        canStartAttendance(
          hasLocation: true,
          isGettingLocation: true,
          isBusy: false,
        ),
        isFalse,
      );
      expect(
        canStartAttendance(
          hasLocation: true,
          isGettingLocation: false,
          isBusy: true,
        ),
        isFalse,
      );
    });
  });

  group('locationIssueFor', () {
    test('service off wins over any permission state', () {
      expect(
        locationIssueFor(
          serviceEnabled: false,
          permission: LocationPermission.always,
        ),
        LocationIssue.serviceDisabled,
      );
    });

    test('maps permission states', () {
      expect(
        locationIssueFor(
          serviceEnabled: true,
          permission: LocationPermission.deniedForever,
        ),
        LocationIssue.deniedForever,
      );
      expect(
        locationIssueFor(
          serviceEnabled: true,
          permission: LocationPermission.denied,
        ),
        LocationIssue.denied,
      );
      expect(
        locationIssueFor(
          serviceEnabled: true,
          permission: LocationPermission.whileInUse,
        ),
        isNull,
      );
      expect(
        locationIssueFor(
          serviceEnabled: true,
          permission: LocationPermission.always,
        ),
        isNull,
      );
    });

    test('every issue has an Indonesian message', () {
      expect(
        locationIssueMessage(LocationIssue.serviceDisabled),
        'Lokasi tidak aktif. Silakan aktifkan GPS.',
      );
      expect(
        locationIssueMessage(LocationIssue.denied),
        'Izin lokasi ditolak. Izinkan akses lokasi untuk melakukan absensi.',
      );
      expect(
        locationIssueMessage(LocationIssue.deniedForever),
        'Izin lokasi diblokir. Aktifkan izin lokasi di pengaturan aplikasi.',
      );
    });

    test('the exception carries the issue and its message', () {
      final e = LocationIssueException(LocationIssue.deniedForever);
      expect(e.issue, LocationIssue.deniedForever);
      expect(e.toString(), locationIssueMessage(LocationIssue.deniedForever));
    });
  });

  group('locationErrorMessage / locationIssueOfError', () {
    test('a location timeout says the location was not obtained', () {
      final timeout = TimeoutException(
        'Future not completed',
        const Duration(seconds: 20),
      );
      expect(
        locationErrorMessage(timeout),
        'Lokasi belum didapat. Pastikan GPS aktif dan coba di area terbuka.',
      );
      expect(locationIssueOfError(timeout), isNull);
    });

    test('a LocationIssueException keeps its own message and issue', () {
      final e = LocationIssueException(LocationIssue.deniedForever);
      expect(
        locationErrorMessage(e),
        locationIssueMessage(LocationIssue.deniedForever),
      );
      expect(locationIssueOfError(e), LocationIssue.deniedForever);
    });

    test('geolocator exceptions are mapped to the matching issue', () {
      const off = LocationServiceDisabledException();
      expect(
        locationErrorMessage(off),
        locationIssueMessage(LocationIssue.serviceDisabled),
      );
      expect(locationIssueOfError(off), LocationIssue.serviceDisabled);

      const denied = PermissionDeniedException('ditolak');
      expect(
        locationErrorMessage(denied),
        locationIssueMessage(LocationIssue.denied),
      );
      expect(locationIssueOfError(denied), LocationIssue.denied);
    });

    test('anything else is wrapped without an Exception: prefix', () {
      expect(
        locationErrorMessage(Exception('Sensor rusak')),
        'Gagal mendapatkan lokasi: Sensor rusak',
      );
      expect(locationIssueOfError(Exception('Sensor rusak')), isNull);
    });
  });

  group('kehadiranStatusLabel', () {
    test('translates the backend status', () {
      expect(kehadiranStatusLabel('HADIR'), 'Hadir');
      expect(kehadiranStatusLabel('TELAT'), 'Telat');
      expect(kehadiranStatusLabel('telat'), 'Telat');
    });

    test('says the same as the status label of the history and the dosen list', () {
      for (final String status in attendanceStatuses) {
        expect(kehadiranStatusLabel(status), attendanceStatusLabel(status), reason: status);
      }
      expect(kehadiranStatusLabel('TELAT'), isNot('Terlambat'));
    });

    test('returns a dash for a missing or unknown status', () {
      expect(kehadiranStatusLabel(null), '-');
      expect(kehadiranStatusLabel(''), '-');
      expect(kehadiranStatusLabel('LAIN'), '-');
    });
  });

  group('attendanceServerMessage', () {
    test('returns the plain message', () {
      expect(
        attendanceServerMessage(<String, dynamic>{
          'status': 'error',
          'message': 'Anda sudah melakukan absensi untuk sesi ini',
        }),
        'Anda sudah melakukan absensi untuk sesi ini',
      );
    });

    test('appends distance and radius of a geofence rejection', () {
      expect(
        attendanceServerMessage(<String, dynamic>{
          'status': 'error',
          'message': 'Lokasi di luar area absensi',
          'distance': 245,
          'required_radius': 100,
        }),
        'Lokasi di luar area absensi. Jarak: 245 m, Radius: 100 m',
      );
    });

    test('is null when the body has no message', () {
      expect(attendanceServerMessage(null), isNull);
      expect(attendanceServerMessage('boom'), isNull);
      expect(attendanceServerMessage(<String, dynamic>{}), isNull);
      expect(attendanceServerMessage(<String, dynamic>{'message': ''}), isNull);
    });
  });

  group('normalizeGpsAbsensiResult', () {
    test('maps the absensi record to the shape the success card reads', () {
      final result = normalizeGpsAbsensiResult(<String, dynamic>{
        'status': 'success',
        'message': 'Absensi recorded successfully',
        'data': <String, dynamic>{
          'id_absensi': 5,
          'status': 'TELAT',
          'createdAt': '2026-10-13T01:20:00.000Z',
          'kelas': <String, dynamic>{
            'nama_kelas': 'IF-44-01',
            'ruangan': 'A101',
            'matakuliah': <String, dynamic>{
              'nama_matakuliah': 'Pemrograman Web',
            },
          },
        },
      });

      expect(result['status'], 'success');
      final data = result['data'] as Map<String, dynamic>;
      expect(data['kelas'], 'Pemrograman Web');
      expect(data['ruangan'], 'A101');
      expect(data['waktu'], '2026-10-13T01:20:00.000Z');
      expect(data['status'], 'TELAT');
    });

    test('falls back to the class name and tolerates missing fields', () {
      final result = normalizeGpsAbsensiResult(<String, dynamic>{
        'status': 'success',
        'data': <String, dynamic>{
          'kelas': <String, dynamic>{'nama_kelas': 'IF-44-01'},
        },
      });
      final data = result['data'] as Map<String, dynamic>;
      expect(data['kelas'], 'IF-44-01');
      expect(data['ruangan'], isNull);
      expect(data['waktu'], isNull);
      expect(data['status'], isNull);
    });

    test('an empty body is not a success', () {
      expect(
        normalizeGpsAbsensiResult(<String, dynamic>{})['status'],
        isNot('success'),
      );
    });
  });
}
