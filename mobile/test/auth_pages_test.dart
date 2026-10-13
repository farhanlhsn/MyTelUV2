import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:mobile/controllers/auth_controller.dart';
import 'package:mobile/pages/auth/forgot_password_page.dart';
import 'package:mobile/pages/auth/register_page.dart';
import 'package:mobile/pages/auth/reset_password_page.dart';
import 'package:mockito/mockito.dart';

import 'auth_controller_test.mocks.dart';

DioException _badResponse(int status, String message) {
  final options = RequestOptions(path: '/api/v1/auth/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: <String, dynamic>{'status': 'error', 'message': message},
    ),
  );
}

DioException _connectionError() {
  return DioException(
    requestOptions: RequestOptions(path: '/api/v1/auth/x'),
    type: DioExceptionType.connectionError,
    message: 'SocketException: Connection refused',
  );
}

void main() {
  late MockAuthService authService;

  setUp(() {
    authService = MockAuthService();
    Get.put<AuthController>(
      AuthController(
        authService: authService,
        secureStorage: MockFlutterSecureStorage(),
        registerNotificationToken: () async {},
        unregisterNotificationToken: () async {},
      ),
    );
  });

  tearDown(() => Get.reset());

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(360, 800),
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        home: page,
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(
            name: '/login',
            page: () => const Scaffold(body: Text('halaman login')),
          ),
          GetPage<dynamic>(
            name: '/success',
            page: () => const Scaffold(body: Text('halaman sukses')),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final finder = find.widgetWithText(ElevatedButton, label);
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('ForgotPasswordPage', () {
    testWidgets('does not overflow on a small screen with the keyboard open', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const ForgotPasswordPage(),
        size: const Size(360, 520),
        keyboard: 280,
      );

      expect(tester.takeException(), isNull);
      // The link below the button is still reachable by scrolling.
      await tester.ensureVisible(
        find.text('Sudah punya token? Masukkan di sini'),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a server error is shown once, not twice', (tester) async {
      when(authService.forgotPassword('budi')).thenAnswer(
        (_) async => throw _badResponse(429, 'Terlalu banyak percobaan'),
      );
      await pumpPage(tester, const ForgotPasswordPage());

      await tester.enterText(find.byType(TextFormField), 'budi');
      await tapButton(tester, 'Kirim Token Reset');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Terlalu banyak percobaan'), findsOneWidget);
    });
  });

  group('ResetPasswordPage', () {
    Future<void> fillAndSubmit(
      WidgetTester tester, {
      String confirm = 'baru5678',
    }) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'token-123');
      await tester.enterText(fields.at(1), 'baru5678');
      await tester.enterText(fields.at(2), confirm);
      await tapButton(tester, 'Ganti Password');
    }

    testWidgets('has a confirm password field and refuses a mismatch', (
      tester,
    ) async {
      await pumpPage(tester, const ResetPasswordPage());

      expect(find.text('Konfirmasi Password Baru'), findsOneWidget);

      await fillAndSubmit(tester, confirm: 'beda1234');

      expect(find.text('Konfirmasi password tidak cocok'), findsOneWidget);
      verifyZeroInteractions(authService);
    });

    testWidgets('an invalid token shows exactly one dialog with the server message', (
      tester,
    ) async {
      when(
        authService.resetPassword(token: 'token-123', newPassword: 'baru5678'),
      ).thenAnswer(
        (_) async =>
            throw _badResponse(400, 'Token reset tidak valid atau sudah kedaluwarsa'),
      );
      await pumpPage(tester, const ResetPasswordPage());

      await fillAndSubmit(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('Token reset tidak valid atau sudah kedaluwarsa'),
        findsOneWidget,
      );
      expect(find.text('Reset Password Gagal'), findsOneWidget);
    });

    testWidgets('a dead connection is not reported as an invalid token', (
      tester,
    ) async {
      when(
        authService.resetPassword(token: 'token-123', newPassword: 'baru5678'),
      ).thenAnswer((_) async => throw _connectionError());
      await pumpPage(tester, const ResetPasswordPage());

      await fillAndSubmit(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Tidak dapat terhubung ke server'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Token'),
        ),
        findsNothing,
      );
      expect(find.text('Coba Lagi'), findsOneWidget);
    });
  });

  group('RegisterPage', () {
    testWidgets('no role selector, but email and confirm password fields', (
      tester,
    ) async {
      await pumpPage(tester, const RegisterPage());

      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Role/Peran'), findsNothing);
      expect(find.text('Email (opsional)'), findsOneWidget);
      expect(find.text('Konfirmasi Password'), findsOneWidget);
    });

    testWidgets('the terms link opens an in-app dialog', (tester) async {
      await pumpPage(tester, const RegisterPage());

      await tester.ensureVisible(
        find.textContaining('Syarat dan Ketentuan', findRichText: true),
      );
      await tester.pump();
      await tester.tapOnText(find.textRange.ofSubstring('Syarat dan Ketentuan'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Syarat dan Ketentuan'), findsOneWidget);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a short password and a missing terms checkbox are reported inline', (
      tester,
    ) async {
      await pumpPage(tester, const RegisterPage());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Budi Santoso');
      await tester.enterText(fields.at(1), 'budi_01');
      // fields: nama, username, email, nim, password, confirm
      await tester.enterText(fields.at(4), 'abc123');
      await tester.enterText(fields.at(5), 'abc123');
      await tapButton(tester, 'Daftar');

      expect(find.text('Password minimal 8 karakter'), findsOneWidget);
      expect(
        find.text('Anda harus menyetujui Syarat dan Ketentuan'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      verifyZeroInteractions(authService);
    });

    testWidgets('submits without any role and moves on to the success page', (
      tester,
    ) async {
      when(
        authService.register(
          username: 'budi_01',
          password: 'abcd1234',
          nama: 'Budi Santoso',
          nimNip: '12345678901',
          email: 'budi@example.com',
        ),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'status': 'success',
          'message': 'Akun berhasil dibuat',
        },
      );
      await pumpPage(tester, const RegisterPage());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Budi Santoso');
      await tester.enterText(fields.at(1), 'budi_01');
      await tester.enterText(fields.at(2), 'budi@example.com');
      await tester.enterText(fields.at(3), '12345678901');
      await tester.enterText(fields.at(4), 'abcd1234');
      await tester.enterText(fields.at(5), 'abcd1234');
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tapButton(tester, 'Daftar');
      await tester.pumpAndSettle();

      verify(
        authService.register(
          username: 'budi_01',
          password: 'abcd1234',
          nama: 'Budi Santoso',
          nimNip: '12345678901',
          email: 'budi@example.com',
        ),
      ).called(1);
      expect(find.text('halaman sukses'), findsOneWidget);
    });

    testWidgets('a duplicate username shows one dialog with the server message', (
      tester,
    ) async {
      when(
        authService.register(
          username: anyNamed('username'),
          password: anyNamed('password'),
          nama: anyNamed('nama'),
          nimNip: anyNamed('nimNip'),
          email: anyNamed('email'),
        ),
      ).thenAnswer(
        (_) async => throw _badResponse(409, 'Username, NIM/NIP, atau email sudah terdaftar'),
      );
      await pumpPage(tester, const RegisterPage());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Budi Santoso');
      await tester.enterText(fields.at(1), 'budi_01');
      await tester.enterText(fields.at(4), 'abcd1234');
      await tester.enterText(fields.at(5), 'abcd1234');
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tapButton(tester, 'Daftar');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('Username, NIM/NIP, atau email sudah terdaftar'),
        findsOneWidget,
      );
    });
  });
}
