import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/controllers/auth_controller.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mockito/mockito.dart';

import 'auth_controller_test.mocks.dart';
import 'support/stub_http_adapter.dart';

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
  group('AuthService.register', () {
    test('posts to the public endpoint without any role', () async {
      final adapter = StubHttpAdapter(201, <String, dynamic>{
        'status': 'success',
        'message': 'Akun berhasil dibuat',
      });
      final service = AuthService(dio: adapter.dio());

      await service.register(
        username: 'budi',
        password: 'abcd1234',
        nama: 'Budi',
        nimNip: '12345678901',
        email: 'budi@example.com',
      );

      final request = adapter.lastRequest!;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/auth/register');
      final body = request.data as Map<String, dynamic>;
      expect(body.containsKey('role'), isFalse);
      expect(body['username'], 'budi');
      expect(body['password'], 'abcd1234');
      expect(body['nama'], 'Budi');
      expect(body['nim_nip'], '12345678901');
      expect(body['email'], 'budi@example.com');
    });

    test('leaves out nim_nip and email when they are empty', () async {
      final adapter = StubHttpAdapter(201, <String, dynamic>{'status': 'success'});
      final service = AuthService(dio: adapter.dio());

      await service.register(
        username: 'budi',
        password: 'abcd1234',
        nama: 'Budi',
        nimNip: '',
        email: '',
      );

      final body = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(body.containsKey('nim_nip'), isFalse);
      expect(body.containsKey('email'), isFalse);
    });
  });

  group('AuthController results (the page shows the feedback, not the controller)', () {
    late AuthController controller;
    late MockAuthService authService;

    setUp(() {
      authService = MockAuthService();
      controller = AuthController(
        authService: authService,
        secureStorage: MockFlutterSecureStorage(),
        registerNotificationToken: () async {},
        unregisterNotificationToken: () async {},
      );
    });

    test('register succeeds with the server message', () async {
      when(
        authService.register(
          username: 'budi',
          password: 'abcd1234',
          nama: 'Budi',
          nimNip: '12345678901',
          email: 'budi@example.com',
        ),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'status': 'success',
          'message': 'Akun berhasil dibuat',
        },
      );

      final result = await controller.register(
        'budi',
        'abcd1234',
        'Budi',
        nimNip: '12345678901',
        email: 'budi@example.com',
      );

      expect(result.success, isTrue);
      expect(result.message, 'Akun berhasil dibuat');
      expect(controller.isLoading.value, isFalse);
    });

    test('register returns the 409 message from the server', () async {
      when(
        authService.register(
          username: anyNamed('username'),
          password: anyNamed('password'),
          nama: anyNamed('nama'),
          nimNip: anyNamed('nimNip'),
          email: anyNamed('email'),
        ),
      ).thenAnswer(
        (_) async => throw _badResponse(409, 'Username sudah digunakan'),
      );

      final result = await controller.register('budi', 'abcd1234', 'Budi');

      expect(result.success, isFalse);
      expect(result.message, 'Username sudah digunakan');
      expect(result.isConnectionError, isFalse);
      expect(controller.isLoading.value, isFalse);
    });

    test('register refuses blank required fields without calling the server', () async {
      final result = await controller.register('', 'abcd1234', 'Budi');

      expect(result.success, isFalse);
      expect(result.message, isNotEmpty);
      verifyZeroInteractions(authService);
    });

    test('forgotPassword succeeds', () async {
      when(authService.forgotPassword('budi')).thenAnswer(
        (_) async => <String, dynamic>{
          'status': 'success',
          'message': 'Jika username atau email terdaftar, tautan reset password telah dikirim.',
        },
      );

      final result = await controller.forgotPassword('budi');

      expect(result.success, isTrue);
    });

    test('forgotPassword reports a connection problem as such', () async {
      when(
        authService.forgotPassword('budi'),
      ).thenAnswer((_) async => throw _connectionError());

      final result = await controller.forgotPassword('budi');

      expect(result.success, isFalse);
      expect(result.isConnectionError, isTrue);
      expect(result.message, contains('Tidak dapat terhubung ke server'));
    });

    test('resetPassword with a bad token returns the server message, not a network one', () async {
      when(
        authService.resetPassword(token: 'salah', newPassword: 'abcd1234'),
      ).thenAnswer(
        (_) async =>
            throw _badResponse(400, 'Token reset tidak valid atau sudah kedaluwarsa'),
      );

      final result = await controller.resetPassword('salah', 'abcd1234');

      expect(result.success, isFalse);
      expect(result.isConnectionError, isFalse);
      expect(result.message, 'Token reset tidak valid atau sudah kedaluwarsa');
    });

    test('resetPassword over a dead connection is a connection error, not "token invalid"', () async {
      when(
        authService.resetPassword(token: 'abc', newPassword: 'abcd1234'),
      ).thenAnswer((_) async => throw _connectionError());

      final result = await controller.resetPassword('abc', 'abcd1234');

      expect(result.success, isFalse);
      expect(result.isConnectionError, isTrue);
      expect(result.message, isNot(contains('Token')));
    });

    test('resetPassword succeeds', () async {
      when(
        authService.resetPassword(token: 'abc', newPassword: 'abcd1234'),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'status': 'success',
          'message': 'Password berhasil direset',
        },
      );

      final result = await controller.resetPassword('abc', 'abcd1234');

      expect(result.success, isTrue);
      expect(controller.isLoading.value, isFalse);
    });
  });
}
