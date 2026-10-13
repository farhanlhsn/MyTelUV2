import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/biometrik/biometrik_status_page.dart';
import 'package:mobile/pages/biometrik/biometrik_status_widget.dart';
import 'package:mobile/services/biometrik_service.dart';

import 'support/stub_http_adapter.dart';

Map<String, dynamic> _statusBody({
  required bool terdaftar,
  String? diperbarui,
}) => <String, dynamic>{
  'status': 'success',
  'data': <String, dynamic>{'terdaftar': terdaftar, 'diperbarui': diperbarui},
};

Future<void> _pumpPage(WidgetTester tester, StubHttpAdapter adapter) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BiometrikStatusPage(service: BiometrikService(dio: adapter.dio())),
    ),
  );
}

void main() {
  testWidgets('shows a loading state before the status arrives', (
    tester,
  ) async {
    final adapter = StubHttpAdapter(
      200,
      _statusBody(terdaftar: true, diperbarui: '2026-10-01T03:04:05.000Z'),
    );
    await _pumpPage(tester, adapter);

    // first frame: the request is in flight
    expect(find.text('Memeriksa status…'), findsOneWidget);
    expect(find.text('Wajah sudah terdaftar'), findsNothing);
    expect(find.text('Wajah belum terdaftar'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Memeriksa status…'), findsNothing);
  });

  testWidgets('registered: says so and shows the update date (WIB)', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      StubHttpAdapter(
        200,
        // 2026-10-01 18:00 UTC is already 2 October in WIB
        _statusBody(terdaftar: true, diperbarui: '2026-10-01T18:00:00.000Z'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BiometrikStatusWidget), findsOneWidget);
    expect(find.text('Data Biometrik'), findsOneWidget);
    expect(find.text('Wajah sudah terdaftar'), findsOneWidget);
    expect(find.text('Terakhir diperbarui: 2 Okt 2026'), findsOneWidget);
    expect(find.text('Hubungi admin untuk pendaftaran wajah'), findsNothing);
    // no "Daftar"/"Verifikasi" button: verifying needs an attendance session
    expect(find.text('Daftar'), findsNothing);
    expect(find.text('Verifikasi'), findsNothing);
  });

  testWidgets(
    'not registered: says so and tells the student to ask the admin',
    (tester) async {
      await _pumpPage(
        tester,
        StubHttpAdapter(200, _statusBody(terdaftar: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wajah belum terdaftar'), findsOneWidget);
      expect(
        find.text('Hubungi admin untuk pendaftaran wajah'),
        findsOneWidget,
      );
      expect(find.text('Daftar'), findsNothing);
    },
  );

  testWidgets('error: shows the message with Coba Lagi, which loads again', (
    tester,
  ) async {
    final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
      (
        500,
        <String, dynamic>{
          'status': 'error',
          'message': 'Terjadi kesalahan pada server',
        },
      ),
      (200, _statusBody(terdaftar: true)),
    ]);
    await _pumpPage(tester, adapter);
    await tester.pumpAndSettle();

    expect(find.text('Terjadi kesalahan pada server'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(find.text('Wajah sudah terdaftar'), findsNothing);

    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(adapter.requests.length, 2);
    expect(find.text('Terjadi kesalahan pada server'), findsNothing);
    expect(find.text('Wajah sudah terdaftar'), findsOneWidget);
  });

  testWidgets('the widget alone does not claim a state while it is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BiometrikStatusWidget(showAction: false)),
      ),
    );

    expect(find.text('Wajah sudah terdaftar'), findsNothing);
    expect(find.text('Wajah belum terdaftar'), findsNothing);
    expect(find.text('Memeriksa status…'), findsOneWidget);
  });

  testWidgets('the widget shows the registration state when it is known', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BiometrikStatusWidget(isRegistered: true, showAction: false),
        ),
      ),
    );
    expect(find.text('Wajah sudah terdaftar'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BiometrikStatusWidget(isRegistered: false, showAction: false),
        ),
      ),
    );
    expect(find.text('Wajah belum terdaftar'), findsOneWidget);
  });
}
