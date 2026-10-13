import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart' hide Response;
import 'package:mobile/app/auth_middleware.dart';
import 'package:mobile/controllers/notification_controller.dart';
import 'package:mobile/utils/error_helper.dart';
import 'package:mobile/utils/jadwal_cache.dart';
import 'package:mobile/utils/logger.dart';
import 'package:mobile/utils/notification_inbox.dart';
import 'package:mobile/utils/app_theme.dart';
import 'package:mobile/utils/user_scoped_controllers.dart';

/// Environment configuration for API URLs.
///
/// Usage:
/// - Development:
///   `flutter run --dart-define=API_URL_DEV=http://10.0.2.2:5050`
/// - Production:
///   `flutter build apk --dart-define=ENV=prod --dart-define=API_URL_PROD=https://api.example.com`
class AppConfig {
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String _apiUrlDev = String.fromEnvironment('API_URL_DEV');
  static const String _apiUrlDevDefault = String.fromEnvironment(
    'API_URL_DEV_DEFAULT',
  );
  static const String _apiUrlProd = String.fromEnvironment(
    'API_URL_PROD', 
    defaultValue: 'https://mytelu.farhanlhsn.web.id',
  );

  static const String _androidDevFallback = 'http://10.0.2.2:5050';
  static const String _defaultDevFallback = 'http://localhost:5050';

  static bool get isProduction => _env == 'prod';
  static bool get isDevelopment => _env == 'dev';

  static String get baseUrl {
    if (isProduction) {
      return _apiUrlProd.trim().isNotEmpty 
          ? _apiUrlProd.trim() 
          : 'https://mytelu.farhanlhsn.web.id';
    }

    final String apiUrlDev = _apiUrlDev.trim();
    final String apiUrlDevDefault = _apiUrlDevDefault.trim();

    try {
      if (Platform.isAndroid) {
        if (apiUrlDev.isNotEmpty) return apiUrlDev;
        return _androidDevFallback;
      }
      if (apiUrlDevDefault.isNotEmpty) return apiUrlDevDefault;
      if (apiUrlDev.isNotEmpty) return apiUrlDev;
      return _defaultDevFallback;
    } catch (_) {
      if (apiUrlDevDefault.isNotEmpty) return apiUrlDevDefault;
      if (apiUrlDev.isNotEmpty) return apiUrlDev;
      return _defaultDevFallback;
    }
  }

  static String get envName => _env.toUpperCase();
}

/// How asking the server for a new access token ended.
enum _RefreshResult {
  /// New tokens are stored.
  refreshed,

  /// The server refused the refresh token (400/401), or there is none: the session is gone.
  rejected,

  /// No usable answer (timeout, no connection, 5xx, an odd body): nothing is known about the
  /// session, so it must not be ended.
  unavailable,
}

class ApiClient {
  static final String baseUrl = AppConfig.baseUrl;

  /// The same for the client and for the call that refreshes the token: a refresh that hangs
  /// would hold every request that waits on it.
  static const Duration _timeout = Duration(seconds: 30);
  static FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static Dio? _dioInstance;
  static Completer<_RefreshResult>? _refreshCompleter;
  static bool _isRedirecting = false;

  /// Set when the session is being ended, so requests that fail together end it once (one wipe, one
  /// login dialog). Cleared by [reset], which every login and logout calls.
  static bool _sessionEnding = false;

  /// `RequestOptions.extra` flag set on a request that was replayed after a token refresh.
  static const String _retriedKey = 'retried';

  /// Endpoints whose 401 means "these credentials / token are wrong" and not "your session
  /// expired": no refresh, no logout, the error goes to the caller. Matched on the path suffix, so
  /// `/auth/admin/reset-password` (a normal authenticated call) is not one of them. Nor is
  /// `/auth/password` (change password): a wrong current password is answered with a 400, so a 401
  /// there is an expired access token and refreshes like any other call.
  static const List<String> _authEndpoints = <String>[
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
    '/auth/forgot-password',
    '/auth/reset-password',
  ];

  static bool _isAuthEndpoint(String path) {
    final String clean = path.split('?').first;
    return _authEndpoints.any(clean.endsWith);
  }

  /// What happens when the session is really gone (refresh failed, or a retried request is still
  /// refused): the storage is already cleared, this sends the user to the login page.
  @visibleForTesting
  static void Function() onSessionExpired = _redirectToLogin;

  /// Test hook: every Dio created here (client and refresh call) uses this adapter.
  @visibleForTesting
  static HttpClientAdapter? httpAdapterOverride;

  @visibleForTesting
  static set secureStorage(FlutterSecureStorage storage) =>
      _secureStorage = storage;

  /// Test hook: back to the production wiring.
  @visibleForTesting
  static void resetForTest() {
    _secureStorage = const FlutterSecureStorage();
    onSessionExpired = _redirectToLogin;
    httpAdapterOverride = null;
    _dioInstance = null;
    _refreshCompleter = null;
    _isRedirecting = false;
    _sessionEnding = false;
  }

  static Dio get dio {
    if (_dioInstance == null) {
      debugLog(
        'Initializing Dio client (ENV: ${AppConfig.envName})',
      );

      _dioInstance = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: _timeout,
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          headers: <String, dynamic>{'Content-Type': 'application/json'},
        ),
      );
      if (httpAdapterOverride != null) {
        _dioInstance!.httpClientAdapter = httpAdapterOverride!;
      }

      _dioInstance!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            debugLog(
              'Request: ${options.method} ${options.path}',
            );

            try {
              final String? token = await _secureStorage.read(key: 'token');
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (e) {
              debugLog('Error reading token: $e');
            }

            return handler.next(options);
          },
          onResponse: (response, handler) async {
            debugLog(
              'Response: ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}',
            );

            return handler.next(response);
          },
          onError: (DioException error, ErrorInterceptorHandler handler) async {
            debugLog(
              'DioError: ${error.type} status=${error.response?.statusCode ?? '-'} path=${error.requestOptions.path}',
            );

            // A 401 from an auth endpoint is the answer to those credentials (wrong password, bad
            // token, ...), not an expired session: hand it to the caller, never refresh or log out.
            if (error.response?.statusCode == 401 &&
                !_isAuthEndpoint(error.requestOptions.path)) {
              final RequestOptions options = error.requestOptions;

              // One refresh + one retry per request. A request that already was retried and still
              // gets 401 goes straight to logout (no second refresh, no loop).
              _RefreshResult refresh = _RefreshResult.rejected;
              if (options.extra[_retriedKey] != true) {
                refresh = await _attemptTokenRefresh(options);
                if (refresh == _RefreshResult.refreshed) {
                  try {
                    final String? newToken = await _secureStorage.read(
                      key: 'token',
                    );
                    options.headers['Authorization'] = 'Bearer $newToken';
                    options.extra[_retriedKey] = true;
                    final retryResponse = await _dioInstance!.fetch(options);
                    return handler.resolve(retryResponse);
                  } catch (e) {
                    // A 401 of the retry already logged the user out in its own handler; any other
                    // failure (server error, timeout) is the retry's answer, not a dead session.
                    debugLog('Retry failed after refresh: $e');
                    return handler.next(e is DioException ? e : error);
                  }
                }
              }

              if (refresh == _RefreshResult.unavailable) {
                // The refresh could not be asked (timeout, no connection, server error): the session
                // may well be fine, so nothing is wiped and nobody is logged out. The caller's
                // request fails with a network-style error that says so: the 401 it got ("Token
                // tidak valid") would read like a session that ended.
                debugLog('Token refresh unavailable, keeping the session');
                return handler.next(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                    error: const SessionRefreshUnavailable(),
                    message: SessionRefreshUnavailable.message,
                  ),
                );
              }

              if (!_sessionEnding) {
                // Requests that fail together reach this point together: the first ends the session
                _sessionEnding = true;
                debugLog(
                  'Token refresh failed, clearing storage and redirecting to login',
                );
                await _endSession();
                _dioInstance = null;
                onSessionExpired();
              }
              // The caller's request must end too (a spinner waiting on it would never stop): it
              // fails with the 401 it got
              return handler.next(error);
            }

            return handler.next(error);
          },
        ),
      );
    }

    return _dioInstance!;
  }

  static Future<_RefreshResult> _attemptTokenRefresh(
    RequestOptions requestOptions,
  ) async {
    if (requestOptions.path.contains('/api/v1/auth/refresh')) {
      return _RefreshResult.rejected;
    }

    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      return _refreshCompleter!.future;
    }

    final Completer<_RefreshResult> completer = Completer<_RefreshResult>();
    _refreshCompleter = completer;

    _RefreshResult result = _RefreshResult.unavailable;
    try {
      final String? refreshToken = await _secureStorage.read(
        key: 'refresh_token',
      );
      if (refreshToken == null || refreshToken.isEmpty) {
        result = _RefreshResult.rejected;
        return result;
      }

      debugLog('Attempting to refresh token...');
      final Dio refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: _timeout,
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
        ),
      );
      if (httpAdapterOverride != null) {
        refreshDio.httpClientAdapter = httpAdapterOverride!;
      }

      final Response<dynamic> response;
      try {
        response = await refreshDio.post<dynamic>(
          '/api/v1/auth/refresh',
          data: {'refresh_token': refreshToken},
        );
      } on DioException catch (e) {
        // Only the server saying "this refresh token is no good" (400 missing, 401 invalid, expired
        // or account deactivated) ends the session; a timeout, no connection or a 5xx says nothing
        final int? status = e.response?.statusCode;
        debugLog('Refresh token API error: ${e.type} status=${status ?? '-'}');
        result = status == 400 || status == 401
            ? _RefreshResult.rejected
            : _RefreshResult.unavailable;
        return result;
      }

      final dynamic body = response.data;
      final dynamic data = body is Map ? body['data'] : null;
      if (response.statusCode == 200 && data is Map && data['token'] != null) {
        await _secureStorage.write(key: 'token', value: data['token']);
        // The route middleware judges the session from its own copy of the token
        AuthMiddleware.updateToken(data['token'] as String?);
        if (data['refresh_token'] != null) {
          await _secureStorage.write(
            key: 'refresh_token',
            value: data['refresh_token'],
          );
        }
        debugLog('Token refreshed successfully');
        result = _RefreshResult.refreshed;
      }
      return result;
    } catch (e) {
      debugLog('Refresh token error: $e');
      result = _RefreshResult.unavailable;
      return result;
    } finally {
      completer.complete(result);
      _refreshCompleter = null;
    }
  }

  /// A fresh client (login, logout). A new session can end again, so this also re-arms the guard
  /// that makes requests failing together end the session once.
  static void reset() {
    _dioInstance = null;
    _sessionEnding = false;
  }

  /// The session is gone: wipes what belongs to it on this phone, the route middleware's copy of it,
  /// the notification inbox of that user, the controllers that hold their data, the saved
  /// schedule and, last, the stored login. Every step has its own try, so
  /// one that fails does not skip the others, and the caller still gets to the login page.
  static Future<void> _endSession() async {
    // Whose inbox to clear: read while the storage still has it (never throws)
    final int? idUser = await NotificationInbox.currentUserId(
      storage: _secureStorage,
    );

    await _guardStep('middleware cache', () => AuthMiddleware.clearCredentials());
    await _guardStep('notification inbox', () => NotificationInbox.clear(idUser));
    await _guardStep('inbox on screen', () {
      if (Get.isRegistered<NotificationController>()) {
        Get.find<NotificationController>().reset();
      }
    });
    // Home, anomaly scan, profile...: the next login must not see this user's copy of them
    await _guardStep('user controllers', deleteUserScopedControllers);
    await _guardStep('saved schedule', JadwalCache.clear);
    await _guardStep('secure storage', () => _secureStorage.deleteAll());
  }

  static Future<void> _guardStep(String what, FutureOr<void> Function() step) async {
    try {
      await step();
    } catch (e) {
      debugLog('Failed to clear the ended session ($what): $e');
    }
  }

  static void _redirectToLogin() {
    if (_isRedirecting) return;
    _isRedirecting = true;

    Future.delayed(const Duration(seconds: 2), () {
      _isRedirecting = false;
    });

    if (Get.context != null) {
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.timer_off,
                  color: Colors.orange.shade400,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sesi Berakhir',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Sesi Anda telah berakhir. Silakan login kembali untuk melanjutkan.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.back();
                  Get.offAllNamed('/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Login Kembali',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } else {
      Get.offAllNamed('/login');
    }
  }
}
