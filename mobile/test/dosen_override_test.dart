import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:mobile/pages/dosen/dosen_sesi_detail_page.dart';
import 'package:mobile/pages/dosen/widgets/override_status_sheet.dart';
import 'package:mobile/services/dosen_service.dart';

/// A DosenService that answers from memory; `overrideAbsensi` waits for the test to complete it
/// and then, like the server, shows the new status in the next `getSesiDetail`.
class _FakeDosenService extends Fake implements DosenService {
  Map<String, dynamic> detail;
  final List<Map<String, dynamic>> overrides = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? pending;
  int detailCalls = 0;

  _FakeDosenService(this.detail);

  @override
  Future<Map<String, dynamic>> getSesiDetail(int idSesi) async {
    detailCalls++;
    return detail;
  }

  @override
  Future<Map<String, dynamic>> overrideAbsensi({
    required int idSesi,
    required int idUser,
    required String status,
    String? keterangan,
  }) {
    overrides.add(<String, dynamic>{
      'id_sesi': idSesi,
      'id_user': idUser,
      'status': status,
      'keterangan': keterangan,
    });
    final Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();
    pending = completer;
    return completer.future.then((Map<String, dynamic> row) {
      detail = <String, dynamic>{
        ...detail,
        'peserta': <Map<String, dynamic>>[
          for (final Map<String, dynamic> item in detail['peserta'] as List<dynamic>)
            item['id_user'] == idUser
                ? <String, dynamic>{
                    ...item,
                    'status': status,
                    'hadir': status == 'HADIR' || status == 'TELAT',
                    'keterangan': keterangan,
                    'diubah_oleh': 5,
                  }
                : item,
        ],
      };
      return row;
    });
  }
}

DioException _serverError(int code, String message) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: code,
    data: <String, dynamic>{'status': 'error', 'message': message},
  ),
);

Map<String, dynamic> _detail({bool open = false}) => <String, dynamic>{
  'sesi': <String, dynamic>{'id_sesi_absensi': 12, 'status': open},
  'peserta': <Map<String, dynamic>>[
    <String, dynamic>{
      'id_user': 10,
      'nama': 'Budi',
      'username': 'budi',
      'status': null,
      'hadir': false,
      'keterangan': null,
      'diubah_oleh': null,
      'waktu_absen': null,
    },
    <String, dynamic>{
      'id_user': 11,
      'nama': 'Sari',
      'username': 'sari',
      'status': 'TELAT',
      'hadir': true,
      'keterangan': null,
      'diubah_oleh': null,
      'waktu_absen': '2026-10-14T01:20:00.000Z',
    },
  ],
  'stats': <String, dynamic>{
    'total_peserta': 2,
    'total_hadir': 1,
    'total_telat': 1,
    'total_izin': 0,
    'total_sakit': 0,
    'total_tidak_hadir': 1,
    'persentase': '50.0',
  },
};

void main() {
  tearDown(() => Get.reset());

  // The test font is much wider than a real one: the open-session banner of the page (not part of
  // this change) needs a wider screen to lay out than a phone does.
  Future<void> pumpPage(
    WidgetTester tester,
    _FakeDosenService service, {
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        home: DosenSesiDetailPage(idSesi: 12, kelasName: 'IF-44-01', dosenService: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder statusOf(int idUser, String label) => find.descendant(
    of: find.byKey(Key('peserta-status-$idUser')),
    matching: find.text(label),
  );

  group('status of each student', () {
    testWidgets('closed session: late is "Telat", no record is "Tidak hadir"', (tester) async {
      await pumpPage(tester, _FakeDosenService(_detail()));

      expect(statusOf(11, 'Telat'), findsOneWidget);
      expect(statusOf(10, 'Tidak hadir'), findsOneWidget);
    });

    testWidgets('open session: no record is "Belum absen"', (tester) async {
      await pumpPage(tester, _FakeDosenService(_detail(open: true)), width: 800);

      expect(statusOf(10, 'Belum absen'), findsOneWidget);
      expect(statusOf(11, 'Telat'), findsOneWidget);
    });
  });

  group('override sheet', () {
    testWidgets('lists the five statuses and a note field', (tester) async {
      await pumpPage(tester, _FakeDosenService(_detail()));

      await tester.tap(find.byKey(const Key('peserta-10')));
      await tester.pumpAndSettle();

      for (final String label in <String>['Hadir', 'Telat', 'Izin', 'Sakit', 'Alpha']) {
        expect(
          find.descendant(of: find.byType(OverrideStatusSheet), matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.byKey(const Key('override-keterangan')), findsOneWidget);
      // nothing picked yet, so nothing to save
      expect(
        tester.widget<ElevatedButton>(find.byKey(const Key('override-save'))).onPressed,
        isNull,
      );
    });

    testWidgets('optimistic: the list changes at once, the sheet is locked until the server answers',
        (tester) async {
      final service = _FakeDosenService(_detail());
      await pumpPage(tester, service);

      await tester.tap(find.byKey(const Key('peserta-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('override-status-IZIN')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('override-keterangan')), '  Surat izin  ');
      await tester.pump();
      await tester.tap(find.byKey(const Key('override-save')));
      await tester.pump();

      // sent with the trimmed note
      expect(service.overrides, <Map<String, dynamic>>[
        <String, dynamic>{'id_sesi': 12, 'id_user': 10, 'status': 'IZIN', 'keterangan': 'Surat izin'},
      ]);
      // the row behind the sheet already says Izin, the header already counts it
      expect(statusOf(10, 'Izin'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('peserta-10')), matching: find.text('Surat izin')),
        findsOneWidget,
      );
      // while saving: Simpan and Batal are off, a status can not be changed, the field is off
      expect(
        tester.widget<ElevatedButton>(find.byKey(const Key('override-save'))).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('override-cancel'))).onPressed,
        isNull,
      );
      expect(
        tester.widget<ListTile>(find.byKey(const Key('override-status-ALPHA'))).enabled,
        isFalse,
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('override-keterangan'))).enabled,
        isFalse,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      service.pending!.complete(<String, dynamic>{
        'id_user': 10,
        'status': 'IZIN',
        'keterangan': 'Surat izin',
        'diubah_oleh': 5,
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(OverrideStatusSheet), findsNothing);
      expect(statusOf(10, 'Izin'), findsOneWidget);
      expect(find.text('Diubah manual'), findsOneWidget);

      expect(find.text('Kehadiran Budi diperbarui'), findsOneWidget);
      // let the snackbar go away
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('the header counts follow the optimistic change', (tester) async {
      final service = _FakeDosenService(_detail());
      await pumpPage(tester, service);
      // before: 2 students, 1 present (telat), 0 excused, 1 absent
      expect(find.text('50.0% Kehadiran'), findsOneWidget);

      await tester.tap(find.byKey(const Key('peserta-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('override-status-SAKIT')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('override-save')));
      await tester.pump();

      // Budi is excused: 1 present of 1 countable
      expect(find.text('100.0% Kehadiran'), findsOneWidget);

      service.pending!.complete(<String, dynamic>{'id_user': 10, 'status': 'SAKIT'});
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('rollback: a refusal puts the list back and keeps the sheet open with the message',
        (tester) async {
      final service = _FakeDosenService(_detail());
      await pumpPage(tester, service);

      await tester.tap(find.byKey(const Key('peserta-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('override-status-ALPHA')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('override-save')));
      await tester.pump();
      expect(statusOf(10, 'Alpha'), findsOneWidget);

      service.pending!.completeError(
        _serverError(403, 'Anda hanya dapat mengubah kehadiran pada kelas yang Anda ajar'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // the row is what it was, the header too
      expect(statusOf(10, 'Tidak hadir'), findsOneWidget);
      expect(statusOf(10, 'Alpha'), findsNothing);
      expect(find.text('50.0% Kehadiran'), findsOneWidget);
      // the sheet stays, says why, and can be used again
      expect(find.byType(OverrideStatusSheet), findsOneWidget);
      expect(
        find.text('Anda hanya dapat mengubah kehadiran pada kelas yang Anda ajar'),
        findsOneWidget,
      );
      expect(
        tester.widget<ElevatedButton>(find.byKey(const Key('override-save'))).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('override-cancel'))).onPressed,
        isNotNull,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failed save can be retried', (tester) async {
      final service = _FakeDosenService(_detail());
      await pumpPage(tester, service);

      await tester.tap(find.byKey(const Key('peserta-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('override-status-HADIR')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('override-save')));
      await tester.pump();
      service.pending!.completeError(_serverError(404, 'Mahasiswa tidak terdaftar di kelas ini'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Mahasiswa tidak terdaftar di kelas ini'), findsOneWidget);

      await tester.tap(find.byKey(const Key('override-save')));
      await tester.pump();

      expect(service.overrides.length, 2);
      // the old error is gone while the new try runs
      expect(find.text('Mahasiswa tidak terdaftar di kelas ini'), findsNothing);
      expect(statusOf(10, 'Hadir'), findsOneWidget);

      service.pending!.complete(<String, dynamic>{'id_user': 10, 'status': 'HADIR'});
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('Batal closes the sheet without a request', (tester) async {
      final service = _FakeDosenService(_detail());
      await pumpPage(tester, service);

      await tester.tap(find.byKey(const Key('peserta-11')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('override-cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(OverrideStatusSheet), findsNothing);
      expect(service.overrides, isEmpty);
    });
  });
}
