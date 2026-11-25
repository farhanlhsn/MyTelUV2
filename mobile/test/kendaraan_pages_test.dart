import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/pengajuan_plat_model.dart';
import 'package:mobile/pages/kendaraan/historyPengajuan/detailuserhistoripengajuan.dart';
import 'package:mobile/pages/kendaraan/historyPengajuan/userhistoripengajuan.dart';
import 'package:mobile/pages/kendaraan/registerplat.dart';
import 'package:mobile/pages/kendaraan/resubmit_kendaraan_page.dart';
import 'package:mobile/pages/kendaraan/widgets/foto_upload_field.dart';
import 'package:mobile/services/kendaraan_service.dart';
import 'package:mobile/utils/app_theme.dart';
import 'package:mockito/mockito.dart';

import 'kendaraan_service_test.mocks.dart';

PengajuanPlatModel _pengajuan(
  String status, {
  String? feedback,
  int id = 1,
  String plat = 'D 1234 AB',
}) {
  return PengajuanPlatModel(
    idKendaraan: id,
    platNomor: plat,
    namaKendaraan: 'Honda Vario',
    statusPengajuan: status,
    feedback: feedback,
    fotoKendaraan: const <String>[],
    fotoSTNK: '',
    createdAt: DateTime.utc(2026, 10, 1, 3, 0),
    updatedAt: DateTime.utc(2026, 10, 2, 4, 30),
  );
}

Map<String, dynamic> _json(String status, int id, String plat, {String? feedback}) {
  return <String, dynamic>{
    'id_kendaraan': id,
    'plat_nomor': plat,
    'nama_kendaraan': 'Motor $id',
    'status_pengajuan': status,
    'feedback': feedback,
    'fotoKendaraan': <String>[],
    'fotoSTNK': '',
    'createdAt': '2026-10-01T03:00:00.000Z',
    'updatedAt': '2026-10-02T04:30:00.000Z',
  };
}

void main() {
  late MockDio dio;

  setUp(() {
    dio = MockDio();
    KendaraanService.dio = dio;
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();
  }

  group('RegisterPlatPage', () {
    Finder field(String label) => find.widgetWithText(TextFormField, label);

    Future<void> submit(WidgetTester tester) async {
      final button = find.widgetWithText(ElevatedButton, 'Daftarkan');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
    }

    testWidgets('has labelled fields, not hint-only ones', (tester) async {
      await pumpPage(tester, const RegisterPlatPage());

      expect(field('Nama Kendaraan'), findsOneWidget);
      expect(field('Nomor Plat'), findsOneWidget);
    });

    testWidgets('uppercases the plate as it is typed', (tester) async {
      await pumpPage(tester, const RegisterPlatPage());

      await tester.enterText(field('Nomor Plat'), 'd 1234 ab');
      await tester.pump();

      final text = tester
          .widget<TextFormField>(field('Nomor Plat'))
          .controller!
          .text;
      expect(text, 'D 1234 AB');
    });

    testWidgets('validates every field and marks the missing photos, without calling the server', (
      tester,
    ) async {
      await pumpPage(tester, const RegisterPlatPage());

      await submit(tester);

      expect(find.text('Nama kendaraan wajib diisi'), findsOneWidget);
      expect(find.text('Plat nomor wajib diisi'), findsOneWidget);
      expect(find.text('Foto wajib dipilih'), findsNWidgets(4));
      verifyZeroInteractions(dio);
    });

    testWidgets('accepts a plate typed with extra spaces', (tester) async {
      await pumpPage(tester, const RegisterPlatPage());

      await tester.enterText(field('Nama Kendaraan'), 'Honda Vario');
      await tester.enterText(field('Nomor Plat'), 'b  1234   ab');
      await submit(tester);

      expect(
        find.text('Format plat nomor tidak valid. Contoh: D 1234 ABC'),
        findsNothing,
      );
      expect(find.text('Plat nomor wajib diisi'), findsNothing);
    });

    testWidgets('rejects a malformed plate with an example', (tester) async {
      await pumpPage(tester, const RegisterPlatPage());

      await tester.enterText(field('Nama Kendaraan'), 'Honda Vario');
      await tester.enterText(field('Nomor Plat'), 'BBB 1');
      await submit(tester);

      expect(
        find.text('Format plat nomor tidak valid. Contoh: D 1234 ABC'),
        findsOneWidget,
      );
    });
  });

  group('ResubmitKendaraanPage', () {
    Future<void> pumpWithArguments(WidgetTester tester, Object? arguments) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/resubmit',
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: RouteSettings(name: '/resubmit', arguments: arguments),
            builder: (_) => const ResubmitKendaraanPage(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('asks for all four photos before submitting', (tester) async {
      await pumpWithArguments(tester, <String, dynamic>{'id_kendaraan': 5});

      final button = find.widgetWithText(ElevatedButton, 'Ajukan Ulang');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();

      expect(find.text('Foto wajib dipilih'), findsNWidgets(4));
      verifyZeroInteractions(dio);
    });
  });

  group('FotoUploadField', () {
    testWidgets('shows the inline error and the not-chosen state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FotoUploadField(
              label: 'Foto STNK',
              imagePath: null,
              errorText: 'Foto wajib dipilih',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Foto STNK'), findsOneWidget);
      expect(find.text('Ketuk untuk memilih foto'), findsOneWidget);
      expect(find.text('Foto wajib dipilih'), findsOneWidget);
    });
  });

  group('RegisterPlatBerhasilPage (the one shared success page)', () {
    testWidgets('has a tappable back button and the given copy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterPlatBerhasilPage(
            appBarTitle: 'Ajukan Ulang',
            title: 'Pengajuan Ulang Berhasil!',
            message: 'Pengajuan ulang Anda sedang diproses',
          ),
        ),
      );

      expect(find.text('Pengajuan Ulang Berhasil!'), findsOneWidget);
      expect(find.text('Ajukan Ulang'), findsOneWidget);
      expect(find.byTooltip('Kembali ke beranda'), findsOneWidget);
      expect(
        find.widgetWithIcon(IconButton, appBackIcon),
        findsOneWidget,
      );

      // Leave the page so its countdown timer is cancelled.
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('DetailPengajuanPlat', () {
    testWidgets('a rejected submission shows its timeline, feedback and the resubmit button', (
      tester,
    ) async {
      await pumpPage(
        tester,
        DetailPengajuanPlat(
          pengajuan: _pengajuan('DITOLAK', feedback: 'Foto STNK buram'),
        ),
      );

      expect(find.text('Diajukan'), findsOneWidget);
      expect(find.text('01/10/2026 10:00 WIB'), findsOneWidget);
      expect(find.text('Ditolak'), findsNWidgets(2)); // badge + timeline step
      expect(find.text('02/10/2026 11:30 WIB'), findsOneWidget);
      expect(find.text('Foto STNK buram'), findsOneWidget);
      expect(find.text('AJUKAN ULANG'), findsOneWidget);
      expect(find.textContaining('LOREM'), findsNothing);
    });

    testWidgets('a pending submission has a detail too, but no resubmit button', (
      tester,
    ) async {
      await pumpPage(tester, DetailPengajuanPlat(pengajuan: _pengajuan('MENUNGGU')));

      expect(find.text('Menunggu'), findsNWidgets(2));
      expect(find.text('AJUKAN ULANG'), findsNothing);
    });

    testWidgets('an approved submission is labelled Disetujui', (tester) async {
      await pumpPage(tester, DetailPengajuanPlat(pengajuan: _pengajuan('DISETUJUI')));

      expect(find.text('Disetujui'), findsNWidgets(2));
      expect(find.text('Selesai'), findsNothing);
      expect(find.text('AJUKAN ULANG'), findsNothing);
    });

    testWidgets('a delete request is explained, not shown as a raw DELETE_REQUEST string', (
      tester,
    ) async {
      await pumpPage(
        tester,
        DetailPengajuanPlat(
          pengajuan: _pengajuan('DISETUJUI', feedback: 'DELETE_REQUEST: Motor dijual'),
        ),
      );

      expect(find.text('Permintaan hapus diajukan'), findsOneWidget);
      expect(find.text('Alasan: Motor dijual'), findsOneWidget);
      expect(find.textContaining('DELETE_REQUEST'), findsNothing);
    });
  });

  group('UserHistoriPengajuan', () {
    testWidgets('every submission, whatever its status, opens a detail', (tester) async {
      when(dio.get(any)).thenAnswer(
        (_) async => Response<dynamic>(
          data: <String, dynamic>{
            'status': 'success',
            'data': <Map<String, dynamic>>[
              _json('MENUNGGU', 1, 'D 1111 AA'),
              _json('DISETUJUI', 2, 'D 2222 BB'),
              _json('DITOLAK', 3, 'D 3333 CC', feedback: 'Foto buram'),
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: '/api/v1/kendaraan/histori-pengajuan'),
        ),
      );
      await pumpPage(tester, const UserHistoriPengajuan());
      await tester.pumpAndSettle();

      // One DETAIL button per card, including the pending and approved ones.
      expect(find.text('DETAIL'), findsNWidgets(3));
      expect(find.text('CEK'), findsNothing);

      // An approved submission opens its detail by tapping the card.
      await tester.tap(find.text('D 2222 BB'));
      await tester.pumpAndSettle();

      expect(find.text('Riwayat Status'), findsOneWidget);
      expect(find.text('Disetujui'), findsNWidgets(2));
    });

    testWidgets('the status filter says Disetujui, not Selesai', (tester) async {
      when(dio.get(any)).thenAnswer(
        (_) async => Response<dynamic>(
          data: <String, dynamic>{
            'status': 'success',
            'data': <Map<String, dynamic>>[_json('MENUNGGU', 1, 'D 1111 AA')],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: '/api/v1/kendaraan/histori-pengajuan'),
        ),
      );
      await pumpPage(tester, const UserHistoriPengajuan());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Status'));
      await tester.pumpAndSettle();

      expect(find.text('Disetujui'), findsOneWidget);
      expect(find.text('Selesai'), findsNothing);
    });

    testWidgets('a failed load shows a readable message with a retry, not a raw exception', (
      tester,
    ) async {
      when(dio.get(any)).thenAnswer(
        (_) async => throw DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
          message: 'SocketException',
        ),
      );
      await pumpPage(tester, const UserHistoriPengajuan());
      await tester.pumpAndSettle();

      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('Error:'), findsNothing);
    });
  });
}
