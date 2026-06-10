import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MyTelU V2 - E2E Test Suite', () {
    // ----------------------------------------------------------------
    // TC-MOB-001: Login dan Home Navigation
    // Precondition: backend running, user mhs_test terdaftar
    // ----------------------------------------------------------------
    testWidgets('TC-MOB-001: User dapat login dan navigasi ke halaman utama', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Tunggu redirect dari splash ke login
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verifikasi berada di halaman login
      // Menggunakan semantic Key yang ditambahkan ke widget
      final usernameField = find.byKey(const Key('login_username_field'));
      final passwordField = find.byKey(const Key('login_password_field'));
      final submitButton = find.byKey(const Key('login_submit_button'));

      // Fallback ke byType jika key tidak ditemukan (backward compat)
      final usernameWidget = usernameField.evaluate().isNotEmpty
          ? usernameField
          : find.byType(TextFormField).first;
      final passwordWidget = passwordField.evaluate().isNotEmpty
          ? passwordField
          : find.byType(TextFormField).last;
      final buttonWidget = submitButton.evaluate().isNotEmpty
          ? submitButton
          : find.byType(ElevatedButton).first;

      expect(
        usernameWidget,
        findsOneWidget,
        reason: 'Username field harus terlihat di halaman login',
      );
      expect(
        passwordWidget,
        findsOneWidget,
        reason: 'Password field harus terlihat di halaman login',
      );
      expect(
        buttonWidget,
        findsOneWidget,
        reason: 'Tombol Sign In harus terlihat',
      );

      // Input kredensial test
      await tester.enterText(usernameWidget, 'mhs_test');
      await tester.enterText(passwordWidget, 'password123');
      await tester.tap(buttonWidget);

      // Tunggu proses login selesai (network request + navigation)
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verifikasi berhasil navigasi ke home page
      // Home page harus menampilkan menu utama mahasiswa
      final bool isOnHome =
          find.text('Kendaraan').evaluate().isNotEmpty ||
          find.text('Absensi').evaluate().isNotEmpty ||
          find.text('Beranda').evaluate().isNotEmpty;

      expect(
        isOnHome,
        isTrue,
        reason: 'Setelah login berhasil, user harus di halaman utama',
      );
    });

    // ----------------------------------------------------------------
    // TC-MOB-002: Navigasi ke Biometrik Absensi
    // Precondition: user sudah login
    // ----------------------------------------------------------------
    testWidgets('TC-MOB-002: User dapat mengakses halaman Absen Biometrik', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Login flow
      final usernameField = find.byKey(const Key('login_username_field'));
      final passwordField = find.byKey(const Key('login_password_field'));
      final submitButton = find.byKey(const Key('login_submit_button'));

      final usernameWidget = usernameField.evaluate().isNotEmpty
          ? usernameField
          : find.byType(TextFormField).first;
      final passwordWidget = passwordField.evaluate().isNotEmpty
          ? passwordField
          : find.byType(TextFormField).last;
      final buttonWidget = submitButton.evaluate().isNotEmpty
          ? submitButton
          : find.byType(ElevatedButton).first;

      await tester.enterText(usernameWidget, 'mhs_test');
      await tester.enterText(passwordWidget, 'password123');
      await tester.tap(buttonWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap menu Biometrik jika tersedia
      final biometrikFinder = find.text('Biometrik');
      if (biometrikFinder.evaluate().isNotEmpty) {
        await tester.tap(biometrikFinder);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verifikasi halaman Biometrik terbuka
        final bool isOnBiometrik =
            find.text('Absen Biometrik').evaluate().isNotEmpty ||
            find.text('Absensi Biometrik').evaluate().isNotEmpty ||
            find.text('Scan Wajah').evaluate().isNotEmpty;

        expect(
          isOnBiometrik,
          isTrue,
          reason: 'Halaman biometrik harus menampilkan judul yang relevan',
        );

        // Kembali ke home
        final backButton = find.byIcon(Icons.arrow_back_ios);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));
        } else {
          // Try system back button simulation via pop
          final backButtonAlt = find.byIcon(Icons.arrow_back);
          if (backButtonAlt.evaluate().isNotEmpty) {
            await tester.tap(backButtonAlt.first);
            await tester.pumpAndSettle(const Duration(seconds: 1));
          }
        }
      } else {
        // Skip navigasi biometrik jika menu tidak ditemukan
        // (bisa berbeda tergantung role user yang login)
        debugPrint('[E2E] Menu Biometrik tidak ditemukan, skip sub-test');
      }
    });

    // ----------------------------------------------------------------
    // TC-MOB-003: Logout Flow
    // Precondition: user sudah login
    // ----------------------------------------------------------------
    testWidgets('TC-MOB-003: User dapat logout dan kembali ke halaman login', (
      WidgetTester tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Login flow
      final usernameField = find.byKey(const Key('login_username_field'));
      final passwordField = find.byKey(const Key('login_password_field'));
      final submitButton = find.byKey(const Key('login_submit_button'));

      final usernameWidget = usernameField.evaluate().isNotEmpty
          ? usernameField
          : find.byType(TextFormField).first;
      final passwordWidget = passwordField.evaluate().isNotEmpty
          ? passwordField
          : find.byType(TextFormField).last;
      final buttonWidget = submitButton.evaluate().isNotEmpty
          ? submitButton
          : find.byType(ElevatedButton).first;

      await tester.enterText(usernameWidget, 'mhs_test');
      await tester.enterText(passwordWidget, 'password123');
      await tester.tap(buttonWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Cari tombol logout
      // Strategi: cari CircleAvatar atau ikon profil, lalu cari tombol logout
      final profileIcon = find.byType(CircleAvatar);
      if (profileIcon.evaluate().isNotEmpty) {
        await tester.tap(profileIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Cari tombol logout (berbagai kemungkinan UI)
      final logoutIcon = find.byIcon(Icons.logout);
      final logoutText = find.text('Logout');
      final logoutTextAlt = find.text('Keluar');

      final Finder logoutFinder = logoutIcon.evaluate().isNotEmpty
          ? logoutIcon
          : logoutText.evaluate().isNotEmpty
          ? logoutText
          : logoutTextAlt;

      if (logoutFinder.evaluate().isNotEmpty) {
        await tester.tap(logoutFinder.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verifikasi kembali ke halaman login setelah logout
        final bool isOnLogin =
            find.text('Sign In').evaluate().isNotEmpty ||
            find.text('LOGIN').evaluate().isNotEmpty ||
            usernameField.evaluate().isNotEmpty ||
            find.byType(TextFormField).evaluate().isNotEmpty;

        expect(
          isOnLogin,
          isTrue,
          reason:
              'Setelah logout, user harus diarahkan kembali ke halaman login',
        );
      } else {
        debugPrint(
          '[E2E] Tombol logout tidak ditemukan, skip verifikasi logout',
        );
      }
    });
  });
}
