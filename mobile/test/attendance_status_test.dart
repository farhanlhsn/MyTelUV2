import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/attendance_status.dart';

void main() {
  group('attendanceStatuses', () {
    test('the five server statuses, in the order the override sheet lists them', () {
      expect(attendanceStatuses, <String>['HADIR', 'TELAT', 'IZIN', 'SAKIT', 'ALPHA']);
    });
  });

  group('normalizeAttendanceStatus', () {
    test('keeps a known status', () {
      for (final String status in attendanceStatuses) {
        expect(normalizeAttendanceStatus(status), status);
      }
    });

    test('is not picky about case or surrounding spaces', () {
      expect(normalizeAttendanceStatus('telat'), 'TELAT');
      expect(normalizeAttendanceStatus(' Sakit '), 'SAKIT');
    });

    test('null, blank, unknown and non-string values are no status', () {
      expect(normalizeAttendanceStatus(null), isNull);
      expect(normalizeAttendanceStatus(''), isNull);
      expect(normalizeAttendanceStatus('BOLOS'), isNull);
      expect(normalizeAttendanceStatus(true), isNull);
      expect(normalizeAttendanceStatus(3), isNull);
    });
  });

  group('attendanceStatusLabel', () {
    test('Indonesian label for each status', () {
      expect(attendanceStatusLabel('HADIR'), 'Hadir');
      expect(attendanceStatusLabel('TELAT'), 'Telat');
      expect(attendanceStatusLabel('IZIN'), 'Izin');
      expect(attendanceStatusLabel('SAKIT'), 'Sakit');
      expect(attendanceStatusLabel('ALPHA'), 'Alpha');
    });

    test('the session being open or closed does not change a recorded status', () {
      expect(attendanceStatusLabel('IZIN', sessionOpen: true), 'Izin');
      expect(attendanceStatusLabel('IZIN', sessionOpen: false), 'Izin');
    });

    test('no record: "Belum absen" while the session is open, "Tidak hadir" once closed', () {
      expect(attendanceStatusLabel(null, sessionOpen: true), 'Belum absen');
      expect(attendanceStatusLabel(null, sessionOpen: false), 'Tidak hadir');
    });

    test('a closed session is the default for a missing record', () {
      expect(attendanceStatusLabel(null), 'Tidak hadir');
    });

    test('an unknown status is treated like no record', () {
      expect(attendanceStatusLabel('BOLOS', sessionOpen: true), 'Belum absen');
      expect(attendanceStatusLabel('BOLOS'), 'Tidak hadir');
    });
  });

  group('attendanceStatusColor', () {
    test('green, amber, blue, purple, red; grey without a record', () {
      expect(attendanceStatusColor('HADIR'), const Color(0xFF16A34A));
      expect(attendanceStatusColor('TELAT'), const Color(0xFFF59E0B));
      expect(attendanceStatusColor('IZIN'), const Color(0xFF2563EB));
      expect(attendanceStatusColor('SAKIT'), const Color(0xFF7C3AED));
      expect(attendanceStatusColor('ALPHA'), const Color(0xFFDC2626));
      expect(attendanceStatusColor(null), const Color(0xFF6B7280));
    });

    test('every status has its own colour', () {
      final Set<Color> colors = <Color>{
        for (final String status in attendanceStatuses) attendanceStatusColor(status),
        attendanceStatusColor(null),
      };
      expect(colors.length, attendanceStatuses.length + 1);
    });

    test('an unknown status gets the grey of "no record"', () {
      expect(attendanceStatusColor('BOLOS'), attendanceStatusColor(null));
    });
  });

  group('attendanceStatusIcon', () {
    test('colour is never the only cue: every status has its own icon', () {
      final Set<IconData> icons = <IconData>{
        for (final String status in attendanceStatuses) attendanceStatusIcon(status),
        attendanceStatusIcon(null),
      };
      expect(icons.length, attendanceStatuses.length + 1);
    });
  });

  group('isPresentAttendance', () {
    test('HADIR and TELAT are present, everything else is not', () {
      expect(isPresentAttendance('HADIR'), isTrue);
      expect(isPresentAttendance('TELAT'), isTrue);
      expect(isPresentAttendance('IZIN'), isFalse);
      expect(isPresentAttendance('SAKIT'), isFalse);
      expect(isPresentAttendance('ALPHA'), isFalse);
      expect(isPresentAttendance(null), isFalse);
    });
  });

  group('attendanceStatusOf', () {
    test('reads the status of a history session or a peserta row', () {
      expect(attendanceStatusOf(<String, dynamic>{'status': 'SAKIT', 'hadir': false}), 'SAKIT');
      expect(attendanceStatusOf(<String, dynamic>{'status': 'TELAT', 'hadir': true}), 'TELAT');
    });

    test('status null means no record', () {
      expect(attendanceStatusOf(<String, dynamic>{'status': null, 'hadir': false}), isNull);
    });

    test('a row without a status falls back to the old hadir flag', () {
      expect(attendanceStatusOf(<String, dynamic>{'hadir': true}), 'HADIR');
      expect(attendanceStatusOf(<String, dynamic>{'hadir': false}), isNull);
      expect(attendanceStatusOf(<String, dynamic>{}), isNull);
    });
  });

  group('summarizeAttendance', () {
    test('HADIR/TELAT present, IZIN/SAKIT excused, ALPHA and no record absent', () {
      final AttendanceSummary summary = summarizeAttendance(<String?>[
        'HADIR',
        'TELAT',
        'IZIN',
        'SAKIT',
        'ALPHA',
        null,
      ]);

      expect(summary.total, 6);
      expect(summary.hadir, 2); // includes the late one
      expect(summary.telat, 1);
      expect(summary.izin, 1);
      expect(summary.sakit, 1);
      expect(summary.tidakHadir, 2);
    });

    test('IZIN and SAKIT leave the denominator', () {
      // 2 present of 4 countable (6 - 2 excused) = 50%
      final AttendanceSummary summary = summarizeAttendance(<String?>[
        'HADIR',
        'TELAT',
        'IZIN',
        'SAKIT',
        'ALPHA',
        null,
      ]);

      expect(summary.dihitung, 4);
      expect(summary.persentase, 50.0);
      expect(summary.persentaseLabel, '50.0');
    });

    test('rounds like the server: one decimal', () {
      final AttendanceSummary summary = summarizeAttendance(<String?>['HADIR', 'HADIR', null]);

      expect(summary.persentaseLabel, '66.7');
    });

    test('nothing countable is 0, not 100', () {
      expect(summarizeAttendance(<String?>[]).persentase, 0);
      expect(summarizeAttendance(<String?>[]).persentaseLabel, '0');
      final AttendanceSummary excused = summarizeAttendance(<String?>['IZIN', 'SAKIT']);
      expect(excused.dihitung, 0);
      expect(excused.persentase, 0);
      expect(excused.persentaseLabel, '0');
    });

    test('everyone present is 100.0', () {
      expect(summarizeAttendance(<String?>['HADIR', 'TELAT']).persentaseLabel, '100.0');
    });
  });

  group('overallAttendancePercentage', () {
    Map<String, dynamic> kelas({
      required int totalSesi,
      required int hadir,
      int izin = 0,
      int sakit = 0,
    }) => <String, dynamic>{
      'kelas': <String, dynamic>{'id_kelas': 1},
      'sessions': <dynamic>[],
      'stats': <String, dynamic>{
        'total_sesi': totalSesi,
        'total_hadir': hadir,
        'total_izin': izin,
        'total_sakit': sakit,
        'total_tidak_hadir': totalSesi - hadir - izin - sakit,
        'persentase': '0',
      },
    };

    test('is the present sessions over the countable sessions of all classes together', () {
      // class 1: 3 present of 3 countable (4 - 1 excused), class 2: 1 present of 2
      final double overall = overallAttendancePercentage(<Map<String, dynamic>>[
        kelas(totalSesi: 4, hadir: 3, izin: 1),
        kelas(totalSesi: 2, hadir: 1),
      ]);

      expect(overall, 4 / 5 * 100);
    });

    test('a session without any record counts as absent (the server lists it as tidak hadir)', () {
      // 5 closed sessions, the student checked in at 2: 40%, not the 100% of "no rows, no misses"
      expect(
        overallAttendancePercentage(<Map<String, dynamic>>[kelas(totalSesi: 5, hadir: 2)]),
        40.0,
      );
    });

    test('izin and sakit leave the denominator', () {
      expect(
        overallAttendancePercentage(<Map<String, dynamic>>[
          kelas(totalSesi: 4, hadir: 1, izin: 1, sakit: 1),
        ]),
        50.0,
      );
    });

    test('nothing countable is 0, not 100', () {
      expect(overallAttendancePercentage(<Map<String, dynamic>>[]), 0);
      expect(
        overallAttendancePercentage(<Map<String, dynamic>>[kelas(totalSesi: 0, hadir: 0)]),
        0,
      );
      // every session excused
      expect(
        overallAttendancePercentage(<Map<String, dynamic>>[
          kelas(totalSesi: 2, hadir: 0, izin: 1, sakit: 1),
        ]),
        0,
      );
    });

    test('a class without stats adds nothing', () {
      expect(
        overallAttendancePercentage(<Map<String, dynamic>>[
          <String, dynamic>{'kelas': <String, dynamic>{'id_kelas': 9}},
          kelas(totalSesi: 2, hadir: 1),
        ]),
        50.0,
      );
    });

    test('everyone present is 100', () {
      expect(
        overallAttendancePercentage(<Map<String, dynamic>>[kelas(totalSesi: 3, hadir: 3)]),
        100.0,
      );
    });

    test('is the same number the class cards of the history add up to', () {
      final List<Map<String, dynamic>> history = <Map<String, dynamic>>[
        kelas(totalSesi: 6, hadir: 3, izin: 1, sakit: 1),
        kelas(totalSesi: 3, hadir: 2),
      ];

      // sesiHadirText of the cards: "3/4 sesi hadir" and "2/3 sesi hadir" -> 5 of 7
      expect(sesiHadirText(history[0]['stats'] as Map<String, dynamic>), startsWith('3/4'));
      expect(sesiHadirText(history[1]['stats'] as Map<String, dynamic>), startsWith('2/3'));
      expect(overallAttendancePercentage(history), 5 / 7 * 100);
    });
  });

  group('sesiHadirText', () {
    test('present over the sessions that count', () {
      expect(
        sesiHadirText(<String, dynamic>{'total_sesi': 5, 'total_hadir': 3}),
        '3/5 sesi hadir',
      );
    });

    test('izin and sakit leave the denominator and are named', () {
      expect(
        sesiHadirText(<String, dynamic>{
          'total_sesi': 6,
          'total_hadir': 3,
          'total_izin': 1,
          'total_sakit': 1,
        }),
        '3/4 sesi hadir • 2 izin/sakit',
      );
    });

    test('missing stats read as nothing', () {
      expect(sesiHadirText(null), '0/0 sesi hadir');
      expect(sesiHadirText(<String, dynamic>{}), '0/0 sesi hadir');
    });
  });
}
