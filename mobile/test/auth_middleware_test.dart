import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/auth_middleware.dart';
import 'package:mobile/app/routes.dart';
import 'package:mockito/mockito.dart';

import 'auth_controller_test.mocks.dart';

String _jwtExpiringAt(DateTime expiry) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part(<String, dynamic>{'alg': 'HS256'})}.'
      '${part(<String, dynamic>{'exp': expiry.millisecondsSinceEpoch ~/ 1000})}.signature';
}

/// What the route middleware lets through: a session whose access token ran out is still a session
/// while a refresh token exists, because the first request of the page refreshes it. Only a session
/// that cannot be refreshed goes to the login page.
void main() {
  late MockFlutterSecureStorage storage;

  setUp(() {
    AuthMiddleware.clearCredentials();
    storage = MockFlutterSecureStorage();
  });

  tearDown(AuthMiddleware.clearCredentials);

  final DateTime past = DateTime.now().subtract(const Duration(hours: 2));
  final DateTime future = DateTime.now().add(const Duration(hours: 1));

  group('updateToken (after the token was refreshed)', () {
    test('replaces the cached token and takes its expiry from the JWT', () {
      AuthMiddleware.updateToken(_jwtExpiringAt(past));
      expect(AuthMiddleware.isTokenValid, isFalse);

      final String fresh = _jwtExpiringAt(future);
      AuthMiddleware.updateToken(fresh);

      expect(AuthMiddleware.cachedToken, fresh);
      expect(AuthMiddleware.isTokenValid, isTrue);
    });

    test('a token that is not a JWT has no expiry and is not valid', () {
      AuthMiddleware.updateToken('access-new');

      expect(AuthMiddleware.cachedToken, 'access-new');
      expect(AuthMiddleware.cachedTokenExpiry, isNull);
      expect(AuthMiddleware.isTokenValid, isFalse);
    });
  });

  group('loadCredentials', () {
    test('reads token, role and whether a refresh token exists', () async {
      final String token = _jwtExpiringAt(future);
      when(storage.read(key: 'token')).thenAnswer((_) async => token);
      when(storage.read(key: 'role')).thenAnswer((_) async => 'DOSEN');
      when(storage.read(key: 'refresh_token')).thenAnswer((_) async => 'refresh-1');

      await AuthMiddleware.loadCredentials(storage: storage);

      expect(AuthMiddleware.cachedToken, token);
      expect(AuthMiddleware.cachedRole, 'DOSEN');
      expect(AuthMiddleware.cachedHasRefreshToken, isTrue);
      expect(AuthMiddleware.isTokenValid, isTrue);
    });

    test('no refresh token in the storage', () async {
      when(storage.read(key: 'token')).thenAnswer((_) async => _jwtExpiringAt(past));
      when(storage.read(key: 'refresh_token')).thenAnswer((_) async => null);

      await AuthMiddleware.loadCredentials(storage: storage);

      expect(AuthMiddleware.cachedHasRefreshToken, isFalse);
    });

    test('clearCredentials forgets the refresh token too', () async {
      when(storage.read(key: 'token')).thenAnswer((_) async => _jwtExpiringAt(future));
      when(storage.read(key: 'refresh_token')).thenAnswer((_) async => 'refresh-1');
      await AuthMiddleware.loadCredentials(storage: storage);

      AuthMiddleware.clearCredentials();

      expect(AuthMiddleware.cachedHasRefreshToken, isFalse);
      expect(AuthMiddleware.cachedToken, isNull);
    });
  });

  group('redirect', () {
    final AuthMiddleware middleware = AuthMiddleware();

    test('a valid token passes', () {
      AuthMiddleware.updateToken(_jwtExpiringAt(future));
      expect(middleware.redirect(AppRoutes.me), isNull);
    });

    test('an expired access token with a refresh token passes: the first request refreshes it', () {
      AuthMiddleware.updateToken(_jwtExpiringAt(past));
      AuthMiddleware.cachedHasRefreshToken = true;

      expect(middleware.redirect(AppRoutes.me), isNull);
    });

    test('an expired access token without a refresh token goes to login', () {
      AuthMiddleware.updateToken(_jwtExpiringAt(past));
      AuthMiddleware.cachedHasRefreshToken = false;

      expect(middleware.redirect(AppRoutes.me)?.name, AppRoutes.login);
    });

    test('no session at all goes to login, whatever the refresh flag says', () {
      AuthMiddleware.cachedHasRefreshToken = true;

      expect(middleware.redirect(AppRoutes.me)?.name, AppRoutes.login);
    });
  });
}
