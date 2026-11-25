import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/auth_middleware.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/pages/splash/splash_destination.dart';
import 'package:mobile/utils/notification_router.dart';
import 'package:mockito/mockito.dart';

import 'auth_controller_test.mocks.dart';

String _jwtExpiringAt(DateTime expiry) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part(<String, dynamic>{'alg': 'HS256'})}.'
      '${part(<String, dynamic>{'exp': expiry.millisecondsSinceEpoch ~/ 1000})}.signature';
}

/// Where the splash sends the user: a valid session goes to the home page, everything else to the
/// login page with the stored session and any pending notification cleared.
void main() {
  late MockFlutterSecureStorage storage;

  void stored({String? token}) {
    when(storage.read(key: 'token')).thenAnswer((_) async => token);
    when(storage.read(key: 'role')).thenAnswer((_) async => 'MAHASISWA');
    when(storage.read(key: 'refresh_token')).thenAnswer((_) async => null);
  }

  setUp(() {
    AuthMiddleware.clearCredentials();
    NotificationNavigator.resetForTest();
    storage = MockFlutterSecureStorage();
  });

  tearDown(() {
    AuthMiddleware.clearCredentials();
    NotificationNavigator.resetForTest();
  });

  test('valid token goes to home', () async {
    stored(token: _jwtExpiringAt(DateTime.now().add(const Duration(hours: 1))));

    expect(await resolveSplashDestination(storage: storage), AppRoutes.home);
  });

  test('no token goes to login and clears the session', () async {
    stored();
    NotificationNavigator.setPending(<String, dynamic>{'type': 'parkir'});

    expect(await resolveSplashDestination(storage: storage), AppRoutes.login);
    expect(AuthMiddleware.cachedToken, isNull);
    expect(NotificationNavigator.hasPending, isFalse);
  });

  test('expired token goes to login', () async {
    stored(token: _jwtExpiringAt(DateTime.now().subtract(const Duration(hours: 1))));

    expect(await resolveSplashDestination(storage: storage), AppRoutes.login);
    expect(AuthMiddleware.cachedToken, isNull);
  });

  test('storage error goes to login', () async {
    when(storage.read(key: anyNamed('key'))).thenThrow(Exception('corrupt keystore'));
    NotificationNavigator.setPending(<String, dynamic>{'type': 'parkir'});

    expect(await resolveSplashDestination(storage: storage), AppRoutes.login);
    expect(NotificationNavigator.hasPending, isFalse);
  });
}
