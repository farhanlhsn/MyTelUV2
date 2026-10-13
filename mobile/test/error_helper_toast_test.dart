import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile/utils/error_helper.dart';

/// The toast helpers of [ErrorHelper] inside a GetMaterialApp.
///
/// `Get.snackbar` cannot be used here: GetX 4.7.2 looks its overlay up from the first child of the
/// navigator's overlay, which current Flutter no longer accepts ("No Overlay widget found" under a
/// plain GetMaterialApp). The failed snackbar also stays "open" in GetX's static queue, and from then
/// on every `Get.back()` only tries to close it and never pops the page. The toasts therefore go
/// through the app's ScaffoldMessenger ([ErrorHelper.scaffoldMessengerKey], wired into the
/// GetMaterialApp of app.dart).
void main() {
  tearDown(() => Get.reset());

  Future<void> pumpApp(WidgetTester tester, {Widget? home}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        scaffoldMessengerKey: ErrorHelper.scaffoldMessengerKey,
        home: home ?? const Scaffold(body: Text('beranda')),
      ),
    );
  }

  // Lets the toast stay and leave, so no timer outlives the test
  Future<void> letToastGo(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  testWidgets('showSuccess shows the title and message, then goes away', (tester) async {
    await pumpApp(tester);

    ErrorHelper.showSuccess('Data tersimpan', title: 'Berhasil');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Berhasil'), findsOneWidget);
    expect(find.text('Data tersimpan'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await letToastGo(tester);
    expect(find.text('Data tersimpan'), findsNothing);
  });

  testWidgets('showInfo shows the title and message', (tester) async {
    await pumpApp(tester);

    ErrorHelper.showInfo('Tidak ada perubahan', title: 'Info');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Info'), findsOneWidget);
    expect(find.text('Tidak ada perubahan'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    await letToastGo(tester);
  });

  testWidgets('a new toast replaces the one on screen instead of queueing behind it', (tester) async {
    await pumpApp(tester);

    ErrorHelper.showSuccess('Pertama');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    ErrorHelper.showInfo('Kedua');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text('Kedua'), findsOneWidget);
    expect(find.text('Pertama'), findsNothing);
    await letToastGo(tester);
  });

  testWidgets('showToast: a tap runs onTap and closes the toast (the push banner)', (tester) async {
    await pumpApp(tester);
    var taps = 0;

    ErrorHelper.showToast(
      'Absensi dibuka',
      'Kelas IF-44-01 sudah bisa diabsen',
      onTap: () => taps++,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Kelas IF-44-01 sudah bisa diabsen'));
    await tester.pump();

    expect(taps, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Kelas IF-44-01 sudah bisa diabsen'), findsNothing);
    await letToastGo(tester);
  });

  testWidgets('showError shows its dialog with the parsed message and OK closes it', (tester) async {
    await pumpApp(tester);

    ErrorHelper.showError('Exception: Gagal menyimpan', title: 'Gagal');
    await tester.pumpAndSettle();

    expect(find.text('Gagal'), findsOneWidget);
    expect(find.text('Gagal menyimpan'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Gagal menyimpan'), findsNothing);
  });

  testWidgets('a toast right after Get.back() (as the forms do after saving) shows on the page behind',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        scaffoldMessengerKey: ErrorHelper.scaffoldMessengerKey,
        initialRoute: '/',
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(name: '/', page: () => const Scaffold(body: Text('daftar'))),
          GetPage<dynamic>(name: '/form', page: () => const Scaffold(body: Text('form'))),
        ],
      ),
    );
    Get.toNamed<dynamic>('/form');
    await tester.pumpAndSettle();

    Get.back<dynamic>(result: true);
    ErrorHelper.showSuccess('Jadwal pengganti berhasil dibuat');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('daftar'), findsOneWidget);
    expect(find.text('Jadwal pengganti berhasil dibuat'), findsOneWidget);
    await letToastGo(tester);
  });

  testWidgets('a toast on screen does not stop Get.back() from closing the page', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        scaffoldMessengerKey: ErrorHelper.scaffoldMessengerKey,
        initialRoute: '/',
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(name: '/', page: () => const Scaffold(body: Text('daftar'))),
          GetPage<dynamic>(name: '/detail', page: () => const Scaffold(body: Text('detail'))),
        ],
      ),
    );
    Get.toNamed<dynamic>('/detail');
    await tester.pumpAndSettle();

    ErrorHelper.showInfo('Catatan');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    Get.back<dynamic>();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('daftar'), findsOneWidget);
    expect(find.text('detail'), findsNothing);
    await letToastGo(tester);
  });

  testWidgets('without an app shell (nothing to show it in) a toast is skipped, not thrown', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());

    expect(() => ErrorHelper.showSuccess('Tidak ada tempat'), returnsNormally);
    expect(() => ErrorHelper.showInfo('Tidak ada tempat'), returnsNormally);
    expect(
      () => ErrorHelper.showToast('Judul', 'Pesan', onTap: () {}),
      returnsNormally,
    );
  });

  group('the app no longer relies on Get.snackbar', () {
    // Run from mobile/ (flutter test)
    final Iterable<File> sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'));

    test('no Get.snackbar call is left in lib/', () {
      final List<String> offenders = <String>[
        for (final File file in sources)
          if (file.readAsStringSync().contains('Get.snackbar(')) file.path,
      ];

      expect(offenders, isEmpty);
    });

    test('app.dart gives the GetMaterialApp the key the toasts use', () {
      final String app = File('lib/app/app.dart').readAsStringSync();

      expect(app, contains('scaffoldMessengerKey: ErrorHelper.scaffoldMessengerKey'));
    });
  });
}
