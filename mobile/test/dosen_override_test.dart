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

  /// When on, `getSesiDetail` does not answer by itself: every call adds a completer to
  /// [gatedDetails] and waits for the test (a slow network, answers arriving in any order).
  bool gateDetails = false;
  final List<Completer<Map<String, dynamic>>> gatedDetails = <Completer<Map<String, dynamic>>>[];

  _FakeDosenService(this.detail);

  @override
  Future<Map<String, dynamic>> getSesiDetail(int idSesi) {
    detailCalls++;
    if (gateDetails) {
      final Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();
      gatedDetails.add(completer);
      return completer.future;
    }
    return Future<Map<String, dynamic>>.value(detail);
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

/// The session as the server would answer once Budi (10) and Sari (11) have these statuses.
/// [budiChangedBy] is the `diubah_oleh` the server keeps for Budi's row.
Map<String, dynamic> _detailWith({
  required String? budi,
  required String? sari,
  int? budiChangedBy,
}) {
  Map<String, dynamic> peserta(int idUser, String nama, String? status, int? changedBy) =>
      <String, dynamic>{
        'id_user': idUser,
        'nama': nama,
        'username': nama.toLowerCase(),
        'status': status,
        'hadir': status == 'HADIR' || status == 'TELAT',
        'keterangan': null,
        'diubah_oleh': changedBy,
        'waktu_absen': null,
      };

  return <String, dynamic>{
    ..._detail(),
    'peserta': <Map<String, dynamic>>[
      peserta(10, 'Budi', budi, budiChangedBy),
      peserta(11, 'Sari', sari, null),
    ],
  };
}

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

  group('quiet refresh after a save', () {
    // Opens the sheet of one student, picks a status and presses Simpan
    Future<void> startSave(WidgetTester tester, int idUser, String status) async {
      await tester.tap(find.byKey(Key('peserta-$idUser')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('override-status-$status')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('override-save')));
      await tester.pump();
    }

    // The server accepts the pending save
    Future<void> finishSave(WidgetTester tester, _FakeDosenService service, int idUser, String status) async {
      service.pending!.complete(<String, dynamic>{
        'id_user': idUser,
        'status': status,
        'diubah_oleh': 5,
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> letSnackbarsGo(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    testWidgets('a late refresh does not undo the row of a save made after it started', (tester) async {
      final service = _FakeDosenService(_detail());
      await pumpPage(tester, service);
      service.gateDetails = true;

      // Budi -> Hadir is saved; its quiet refresh (R1) is still on the way
      await startSave(tester, 10, 'HADIR');
      await finishSave(tester, service, 10, 'HADIR');
      expect(service.gatedDetails, hasLength(1));
      expect(statusOf(10, 'Hadir'), findsOneWidget);

      // Sari -> Izin is saved while R1 is out: the row shows Izin at once
      await startSave(tester, 11, 'IZIN');
      expect(statusOf(11, 'Izin'), findsOneWidget);

      // R1 answers now, with what the server knew before Sari's change
      service.gatedDetails[0].complete(_detailWith(budi: 'HADIR', sari: 'TELAT'));
      await tester.pump();

      expect(statusOf(11, 'Izin'), findsOneWidget, reason: 'the stale answer must be dropped');
      expect(statusOf(11, 'Telat'), findsNothing);

      // Sari's save is accepted; its own refresh (R2) brings the server's view of both
      await finishSave(tester, service, 11, 'IZIN');
      expect(service.gatedDetails, hasLength(2));
      service.gatedDetails[1].complete(_detailWith(budi: 'HADIR', sari: 'IZIN'));
      await tester.pump();

      expect(statusOf(10, 'Hadir'), findsOneWidget);
      expect(statusOf(11, 'Izin'), findsOneWidget);
      await letSnackbarsGo(tester);
    });

    testWidgets('answers that arrive out of order: the older one is dropped', (tester) async {
      final service = _FakeDosenService(_detail());
      await pumpPage(tester, service);
      service.gateDetails = true;

      await startSave(tester, 10, 'HADIR');
      await finishSave(tester, service, 10, 'HADIR'); // R1 starts
      await startSave(tester, 11, 'IZIN');
      await finishSave(tester, service, 11, 'IZIN'); // R2 starts
      expect(service.gatedDetails, hasLength(2));

      // R2 (the newer request) answers first, then the old R1 with what was true before Sari's change
      service.gatedDetails[1].complete(_detailWith(budi: 'HADIR', sari: 'IZIN'));
      await tester.pump();
      service.gatedDetails[0].complete(_detailWith(budi: 'HADIR', sari: 'TELAT'));
      await tester.pump();

      expect(statusOf(11, 'Izin'), findsOneWidget);
      expect(statusOf(11, 'Telat'), findsNothing);
      await letSnackbarsGo(tester);
    });

    testWidgets('a refresh with nothing newer in between is applied (what only the server knows)',
        (tester) async {
      final service = _FakeDosenService(_detail());
      await pumpPage(tester, service);
      service.gateDetails = true;

      await startSave(tester, 10, 'HADIR');
      await finishSave(tester, service, 10, 'HADIR');
      service.gatedDetails[0].complete(
        _detailWith(budi: 'HADIR', sari: 'TELAT', budiChangedBy: 5),
      );
      await tester.pump();

      expect(statusOf(10, 'Hadir'), findsOneWidget);
      expect(find.text('Diubah manual'), findsOneWidget);
      await letSnackbarsGo(tester);
    });
  });
}
