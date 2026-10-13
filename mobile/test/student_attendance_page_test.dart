import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile/pages/absensi/absensi_page.dart';
import 'package:mobile/utils/attendance_status.dart';

Map<String, dynamic> _session(
  int id, {
  String? status,
  bool hadir = false,
  bool statusSesi = false,
  bool isActive = false,
  String? keterangan,
  String? waktuAbsen,
}) => <String, dynamic>{
  'id_sesi': id,
  'id_sesi_absensi': id,
  'tanggal': '2026-10-${10 + id}T01:00:00.000Z',
  'status': status,
  'status_sesi': statusSesi,
  'is_active': isActive,
  'hadir': hadir,
  'keterangan': keterangan,
  'waktu_absen': waktuAbsen,
};

void main() {
  tearDown(() => Get.reset());

  Future<void> pumpPage(
    WidgetTester tester,
    List<Map<String, dynamic>> sessions, {
    Map<String, dynamic>? stats,
  }) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        home: AbsensiDetailPage(
          kelasName: 'Pemrograman Mobile (IF-401)',
          idKelas: 3,
          sessions: sessions,
          stats: stats,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('each session shows its status as a label, not only present/absent', (tester) async {
    await pumpPage(tester, <Map<String, dynamic>>[
      _session(1, status: 'HADIR', hadir: true, waktuAbsen: '2026-10-11T01:02:00.000Z'),
      _session(2, status: 'TELAT', hadir: true, waktuAbsen: '2026-10-12T01:20:00.000Z'),
      _session(3, status: 'IZIN', keterangan: 'Surat izin orang tua'),
      _session(4, status: 'SAKIT'),
      _session(5, status: 'ALPHA'),
      _session(6), // closed, no record
    ]);

    for (final String label in <String>['Hadir', 'Telat', 'Izin', 'Sakit', 'Alpha', 'Tidak hadir']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Surat izin orang tua'), findsOneWidget);
  });

  testWidgets('each status badge has the colour of its status', (tester) async {
    await pumpPage(tester, <Map<String, dynamic>>[
      _session(1, status: 'TELAT', hadir: true, waktuAbsen: '2026-10-11T01:20:00.000Z'),
      _session(2, status: 'SAKIT'),
    ]);

    Color colorOf(String label) => tester.widget<Text>(find.text(label)).style!.color!;

    expect(colorOf('Telat'), attendanceStatusColor('TELAT'));
    expect(colorOf('Sakit'), attendanceStatusColor('SAKIT'));
  });

  testWidgets('a session still open with no record is "Belum absen" and offers the Absen button',
      (tester) async {
    await pumpPage(tester, <Map<String, dynamic>>[
      _session(1, statusSesi: true, isActive: true),
    ]);

    expect(find.text('Belum absen'), findsOneWidget);
    expect(find.text('Tidak hadir'), findsNothing);
    expect(find.text('Absen'), findsOneWidget);
  });

  testWidgets('a recorded status needs no check-in, even in an open session', (tester) async {
    await pumpPage(tester, <Map<String, dynamic>>[
      _session(1, status: 'IZIN', statusSesi: true, isActive: true),
    ]);

    expect(find.text('Izin'), findsOneWidget);
    expect(find.text('Absen'), findsNothing);
  });

  testWidgets('a closed session with no record is "Tidak hadir" and has no Absen button',
      (tester) async {
    await pumpPage(tester, <Map<String, dynamic>>[_session(1)]);

    expect(find.text('Tidak hadir'), findsOneWidget);
    expect(find.text('Absen'), findsNothing);
  });

  testWidgets('a session of an older answer (only hadir) still reads as Hadir', (tester) async {
    await pumpPage(tester, <Map<String, dynamic>>[
      <String, dynamic>{
        'id_sesi': 1,
        'tanggal': '2026-10-11T01:00:00.000Z',
        'hadir': true,
        'is_active': false,
        'waktu_absen': '2026-10-11T01:05:00.000Z',
      },
    ]);

    expect(find.text('Hadir'), findsOneWidget);
  });

  testWidgets('the summary names telat, izin and sakit when there are some', (tester) async {
    await pumpPage(
      tester,
      <Map<String, dynamic>>[_session(1, status: 'HADIR', hadir: true)],
      stats: <String, dynamic>{
        'total_sesi': 6,
        'total_hadir': 3,
        'total_telat': 1,
        'total_izin': 1,
        'total_sakit': 1,
        'total_tidak_hadir': 1,
        'persentase': '75.0',
      },
    );

    expect(find.text('Hadir: 3'), findsOneWidget);
    expect(find.text('Tidak Hadir: 1'), findsOneWidget);
    expect(find.text('Telat: 1'), findsOneWidget);
    expect(find.text('Izin: 1'), findsOneWidget);
    expect(find.text('Sakit: 1'), findsOneWidget);
  });

  testWidgets('no breakdown line when there is no telat, izin or sakit', (tester) async {
    await pumpPage(
      tester,
      <Map<String, dynamic>>[_session(1, status: 'HADIR', hadir: true)],
      stats: <String, dynamic>{
        'total_sesi': 2,
        'total_hadir': 2,
        'total_telat': 0,
        'total_izin': 0,
        'total_sakit': 0,
        'total_tidak_hadir': 0,
        'persentase': '100.0',
      },
    );

    expect(find.text('Telat: 0'), findsNothing);
    expect(find.text('Izin: 0'), findsNothing);
  });
}
