import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:mobile/app/auth_middleware.dart';
import 'package:mobile/controllers/notification_controller.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/utils/notification_inbox.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_controller_test.mocks.dart';
import 'support/stub_http_adapter.dart';

/// A token shaped like the server's JWT: only the `exp` claim matters to the middleware cache.
String _jwtExpiringAt(DateTime expiry) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part(<String, dynamic>{'alg': 'HS256'})}.'
      '${part(<String, dynamic>{'exp': expiry.millisecondsSinceEpoch ~/ 1000})}.signature';
}

/// The 401 handling of [ApiClient]: only a real expired session may refresh the token and log the
/// user out. A 401 that is the answer of an auth endpoint (bad credentials, bad reset token) must
/// reach the caller untouched.
void main() {
  late MockFlutterSecureStorage storage;
  late int sessionExpiredCalls;
  late String storedToken;

  const unauthorized = <String, dynamic>{
    'status': 'error',
    'message': 'Token tidak valid',
  };
  const refreshOk = <String, dynamic>{
    'status': 'success',
    'data': <String, dynamic>{
      'token': 'access-new',
      'refresh_token': 'refresh-new',
    },
  };

  setUp(() {
    storage = MockFlutterSecureStorage();
    sessionExpiredCalls = 0;
    storedToken = 'access-old';
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AuthMiddleware.clearCredentials();
    when(storage.read(key: 'token')).thenAnswer((_) async => storedToken);
    when(
      storage.read(key: 'refresh_token'),
    ).thenAnswer((_) async => 'refresh-old');
    when(storage.write(key: 'token', value: anyNamed('value'))).thenAnswer((
      invocation,
    ) async {
      storedToken = invocation.namedArguments[#value] as String;
    });
    ApiClient.secureStorage = storage;
    ApiClient.onSessionExpired = () => sessionExpiredCalls++;
  });

  tearDown(() {
    ApiClient.resetForTest();
    AuthMiddleware.clearCredentials();
    Get.reset();
  });

  Dio clientWith(StubHttpAdapter adapter) {
    ApiClient.httpAdapterOverride = adapter;
    ApiClient.reset();
    return ApiClient.dio;
  }

  Future<void> waitUntil(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// A request that is never answered (a dead session) must not fail the test.
  void fireAndForget(Future<Object?> request) {
    unawaited(request.then((_) {}, onError: (Object _) {}));
  }

  group('401 from an auth endpoint', () {
    test('login, register, forgot and reset password are never refreshed or logged out', () async {
      for (final path in <String>[
        '/api/v1/auth/login',
        '/api/v1/auth/register',
        '/api/v1/auth/forgot-password',
        '/api/v1/auth/reset-password',
        '/api/v1/auth/refresh',
      ]) {
        final adapter = StubHttpAdapter(401, unauthorized);
        final dio = clientWith(adapter);

        await expectLater(
          dio.post<dynamic>(path, data: <String, dynamic>{}),
          throwsA(isA<DioException>()),
          reason: path,
        );

        expect(adapter.requests, hasLength(1), reason: path);
      }
      verifyNever(storage.deleteAll());
      verifyNever(storage.read(key: 'refresh_token'));
      expect(sessionExpiredCalls, 0);
    });

    test('a query string does not hide the endpoint', () async {
      final adapter = StubHttpAdapter(401, unauthorized);
      final dio = clientWith(adapter);

      await expectLater(
        dio.post<dynamic>('/api/v1/auth/login?x=1'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests, hasLength(1));
      expect(sessionExpiredCalls, 0);
    });
  });

  group('401 on a normal endpoint', () {
    test('when the refresh fails the user is logged out once', () async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (401, unauthorized), // GET /kelas
        (401, unauthorized), // POST /auth/refresh
      ]);
      final dio = clientWith(adapter);

      fireAndForget(dio.get<dynamic>('/api/v1/akademik/kelas'));
      await waitUntil(() => sessionExpiredCalls > 0);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(sessionExpiredCalls, 1);
      verify(storage.deleteAll()).called(1);
      expect(adapter.requests.map((r) => r.path), <String>[
        '/api/v1/akademik/kelas',
        '/api/v1/auth/refresh',
      ]);
    });

    test('after a successful refresh the request is retried once and succeeds', () async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (401, unauthorized), // GET /kelas
        (200, refreshOk), // POST /auth/refresh
        (200, <String, dynamic>{'status': 'success', 'data': <dynamic>[]}),
      ]);
      final dio = clientWith(adapter);

      final response = await dio.get<dynamic>('/api/v1/akademik/kelas');

      expect(response.statusCode, 200);
      expect(adapter.requests, hasLength(3));
      expect(adapter.lastRequest!.headers['Authorization'], 'Bearer access-new');
      verify(storage.write(key: 'refresh_token', value: 'refresh-new')).called(1);
      verifyNever(storage.deleteAll());
      expect(sessionExpiredCalls, 0);
    });

    test('a 401 after the one retry goes straight to logout, without looping', () async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (401, unauthorized), // GET /kelas
        (200, refreshOk), // POST /auth/refresh
        (401, unauthorized), // the retry
        (200, refreshOk), // would be a second refresh: must never be asked
      ]);
      final dio = clientWith(adapter);

      fireAndForget(dio.get<dynamic>('/api/v1/akademik/kelas'));
      await waitUntil(() => sessionExpiredCalls > 0);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(sessionExpiredCalls, 1);
      verify(storage.deleteAll()).called(1);
      expect(adapter.requests.map((r) => r.path), <String>[
        '/api/v1/akademik/kelas',
        '/api/v1/auth/refresh',
        '/api/v1/akademik/kelas',
      ]);
      expect(adapter.lastRequest!.extra['retried'], isTrue);
    });

    test('a server error on the retry is the retry\'s own answer, not a dead session', () async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (401, unauthorized),
        (200, refreshOk),
        (500, <String, dynamic>{'status': 'error', 'message': 'Terjadi kesalahan'}),
      ]);
      final dio = clientWith(adapter);

      await expectLater(
        dio.get<dynamic>('/api/v1/akademik/kelas'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            500,
          ),
        ),
      );

      verifyNever(storage.deleteAll());
      expect(sessionExpiredCalls, 0);
    });

    test('/auth/password (change password) with an expired token refreshes and retries like any call', () async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (401, unauthorized), // PUT /auth/password with an expired access token
        (200, refreshOk), // POST /auth/refresh
        (200, <String, dynamic>{'status': 'success', 'message': 'Password berhasil diubah'}),
      ]);
      final dio = clientWith(adapter);

      final response = await dio.put<dynamic>(
        '/api/v1/auth/password',
        data: <String, dynamic>{'oldPassword': 'lama1234', 'newPassword': 'baru5678'},
      );

      expect(response.statusCode, 200);
      expect(adapter.requests.map((r) => r.path), <String>[
        '/api/v1/auth/password',
        '/api/v1/auth/refresh',
        '/api/v1/auth/password',
      ]);
      expect(adapter.lastRequest!.headers['Authorization'], 'Bearer access-new');
      verifyNever(storage.deleteAll());
      expect(sessionExpiredCalls, 0);
    });

    test('/auth/password with a dead session logs the user out once', () async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (401, unauthorized),
        (401, unauthorized), // refresh fails
      ]);
      final dio = clientWith(adapter);

      fireAndForget(dio.put<dynamic>('/api/v1/auth/password'));
      await waitUntil(() => sessionExpiredCalls > 0);

      expect(sessionExpiredCalls, 1);
      expect(adapter.requests.last.path, '/api/v1/auth/refresh');
    });

    test('a wrong current password on /auth/password (the server now answers 400) is an error for the caller', () async {
      final adapter = StubHttpAdapter(400, <String, dynamic>{
        'status': 'error',
        'message': 'Password lama salah',
      });
      final dio = clientWith(adapter);

      await expectLater(
        dio.put<dynamic>(
          '/api/v1/auth/password',
          data: <String, dynamic>{'oldPassword': 'x', 'newPassword': 'abcd1234'},
        ),
        throwsA(
          isA<DioException>().having((e) => e.response?.statusCode, 'status', 400),
        ),
      );

      expect(adapter.requests, hasLength(1));
      verifyNever(storage.deleteAll());
      verifyNever(storage.read(key: 'refresh_token'));
      expect(sessionExpiredCalls, 0);
    });

    test('/auth/admin/reset-password is an ordinary authenticated call', () async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (401, unauthorized),
        (401, unauthorized), // refresh fails
      ]);
      final dio = clientWith(adapter);

      fireAndForget(dio.put<dynamic>('/api/v1/auth/admin/reset-password'));
      await waitUntil(() => sessionExpiredCalls > 0);

      expect(sessionExpiredCalls, 1);
      expect(adapter.requests.last.path, '/api/v1/auth/refresh');
    });
  });

  group('session cache of the route middleware', () {
    test('a refresh puts the new token and its expiry into the middleware cache', () async {
      final DateTime newExpiry = DateTime.now().add(const Duration(hours: 1));
      final String newToken = _jwtExpiringAt(newExpiry);
      AuthMiddleware.cachedToken = _jwtExpiringAt(
        DateTime.now().subtract(const Duration(minutes: 5)),
      );
      AuthMiddleware.cachedTokenExpiry = DateTime.now().subtract(const Duration(minutes: 5));
      expect(AuthMiddleware.isTokenValid, isFalse, reason: 'precondition: the cached token is stale');

      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (401, unauthorized),
        (
          200,
          <String, dynamic>{
            'status': 'success',
            'data': <String, dynamic>{'token': newToken, 'refresh_token': 'refresh-new'},
          },
        ),
        (200, <String, dynamic>{'status': 'success', 'data': <dynamic>[]}),
      ]);
      final dio = clientWith(adapter);

      await dio.get<dynamic>('/api/v1/akademik/kelas');

      expect(AuthMiddleware.cachedToken, newToken);
      // exp has a one-second resolution
      expect(
        AuthMiddleware.cachedTokenExpiry,
        DateTime.fromMillisecondsSinceEpoch(newExpiry.millisecondsSinceEpoch ~/ 1000 * 1000),
      );
      expect(AuthMiddleware.isTokenValid, isTrue);
    });

    test('a forced session expiry empties the middleware cache', () async {
      AuthMiddleware.cachedToken = 'access-old';
      AuthMiddleware.cachedRole = 'MAHASISWA';
      AuthMiddleware.cachedTokenExpiry = DateTime.now().add(const Duration(hours: 1));
      final adapter = StubHttpAdapter(401, unauthorized);
      final dio = clientWith(adapter);

      await expectLater(
        dio.get<dynamic>('/api/v1/akademik/kelas').timeout(const Duration(seconds: 2)),
        throwsA(isA<DioException>()),
      );

      expect(AuthMiddleware.cachedToken, isNull);
      expect(AuthMiddleware.cachedRole, isNull);
      expect(AuthMiddleware.isTokenValid, isFalse);
    });
  });

  group('real session expiry', () {
    test('the caller future completes with the original 401 and the logout ran once', () async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (401, unauthorized), // GET /kelas
        (401, unauthorized), // POST /auth/refresh
      ]);
      final dio = clientWith(adapter);

      await expectLater(
        dio.get<dynamic>('/api/v1/akademik/kelas').timeout(const Duration(seconds: 2)),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)),
      );

      expect(sessionExpiredCalls, 1);
      verify(storage.deleteAll()).called(1);
    });

    test('a 401 on the retry after a refresh completes the caller too', () async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (401, unauthorized), // GET /kelas
        (200, refreshOk), // POST /auth/refresh
        (401, unauthorized), // the retry: the session is dead after all
      ]);
      final dio = clientWith(adapter);

      await expectLater(
        dio.get<dynamic>('/api/v1/akademik/kelas').timeout(const Duration(seconds: 2)),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)),
      );

      expect(sessionExpiredCalls, 1);
      verify(storage.deleteAll()).called(1);
    });

    test('every request waiting on the failed refresh completes', () async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (401, unauthorized), // GET /kelas
        (401, unauthorized), // GET /jadwal
        (401, unauthorized), // POST /auth/refresh (and anything after it)
      ]);
      final dio = clientWith(adapter);

      final Future<Object?> first = dio
          .get<dynamic>('/api/v1/akademik/kelas')
          .then<Object?>((_) => null, onError: (Object e) => e);
      final Future<Object?> second = dio
          .get<dynamic>('/api/v1/akademik/jadwal')
          .then<Object?>((_) => null, onError: (Object e) => e);

      final List<Object?> results = await Future.wait(<Future<Object?>>[
        first,
        second,
      ]).timeout(const Duration(seconds: 2));

      expect(results, everyElement(isA<DioException>()));
    });
  });

  group('forced session expiry and the notification inbox', () {
    Map<String, Object> inboxes() => <String, Object>{
      NotificationInbox.notificationsKey(7): jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{'id': 'a', 'title': 'Absensi', 'timestamp': '2026-10-14T01:00:00.000'},
      ]),
      NotificationInbox.lastReadKey(7): '2026-10-14T01:30:00.000',
      NotificationInbox.notificationsKey(8): jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{'id': 'b', 'title': 'Parkir', 'timestamp': '2026-10-14T02:00:00.000'},
      ]),
      NotificationInbox.legacyNotificationsKey: '[]',
    };

    Future<void> expireSession() async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (401, unauthorized),
        (401, unauthorized), // refresh fails
      ]);
      final dio = clientWith(adapter);
      await expectLater(
        dio.get<dynamic>('/api/v1/akademik/kelas').timeout(const Duration(seconds: 2)),
        throwsA(isA<DioException>()),
      );
    }

    test('removes the inbox of the user whose session ended, and only theirs', () async {
      when(storage.read(key: 'id_user')).thenAnswer((_) async => '7');
      SharedPreferences.setMockInitialValues(inboxes());

      await expireSession();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(NotificationInbox.notificationsKey(7)), isFalse);
      expect(prefs.containsKey(NotificationInbox.lastReadKey(7)), isFalse);
      expect(prefs.containsKey(NotificationInbox.legacyNotificationsKey), isFalse);
      // another account on the same phone keeps theirs
      expect(prefs.containsKey(NotificationInbox.notificationsKey(8)), isTrue);
    });

    test('the user id is read before the storage is wiped', () async {
      when(storage.read(key: 'id_user')).thenAnswer((_) async => '7');
      SharedPreferences.setMockInitialValues(inboxes());

      await expireSession();

      verifyInOrder(<Object?>[storage.read(key: 'id_user'), storage.deleteAll()]);
    });

    test('the list on screen is emptied as well', () async {
      when(storage.read(key: 'id_user')).thenAnswer((_) async => '7');
      SharedPreferences.setMockInitialValues(inboxes());
      final NotificationController shown = Get.put(
        NotificationController(userIdProvider: () async => 7),
      );
      await shown.loadNotifications();
      expect(shown.notifications, hasLength(1), reason: 'precondition: the inbox is on screen');

      await expireSession();

      expect(shown.notifications, isEmpty);
      expect(shown.unreadCount.value, 0);
    });

    test('without a known user nothing else is touched (only the legacy inbox goes)', () async {
      when(storage.read(key: 'id_user')).thenAnswer((_) async => null);
      SharedPreferences.setMockInitialValues(inboxes());

      await expireSession();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(NotificationInbox.notificationsKey(7)), isTrue);
      expect(prefs.containsKey(NotificationInbox.notificationsKey(8)), isTrue);
      expect(prefs.containsKey(NotificationInbox.legacyNotificationsKey), isFalse);
    });
  });
}
