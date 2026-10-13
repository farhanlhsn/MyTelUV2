import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart' hide Response;
import 'package:mobile/app/auth_middleware.dart';
import 'package:mobile/controllers/notification_controller.dart';
import 'package:mobile/utils/logger.dart';
import 'package:mobile/utils/notification_inbox.dart';

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

class ApiClient {
  static final String baseUrl = AppConfig.baseUrl;
  static FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static Dio? _dioInstance;
  static Completer<bool>? _refreshCompleter;
  static bool _isRedirecting = false;

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
  }

  static Dio get dio {
    if (_dioInstance == null) {
      debugLog(
        'Initializing Dio client (ENV: ${AppConfig.envName})',
      );

      _dioInstance = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
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
              if (options.extra[_retriedKey] != true) {
                final bool refreshed = await _attemptTokenRefresh(options);
                if (refreshed) {
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

              debugLog(
                'Token refresh failed, clearing storage and redirecting to login',
              );
              await _endSession();
              _dioInstance = null;
              onSessionExpired();
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

  static Future<bool> _attemptTokenRefresh(
    RequestOptions requestOptions,
  ) async {
    if (requestOptions.path.contains('/api/v1/auth/refresh')) {
      return false;
    }

    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final String? refreshToken = await _secureStorage.read(
        key: 'refresh_token',
      );
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      debugLog('Attempting to refresh token...');
      final Dio refreshDio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
      if (httpAdapterOverride != null) {
        refreshDio.httpClientAdapter = httpAdapterOverride!;
      }

      final response = await refreshDio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data != null && data['token'] != null) {
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
          _refreshCompleter!.complete(true);
          return true;
        }
      }
      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      debugLog('Refresh token API error: $e');
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  static void reset() {
    _dioInstance = null;
  }

  /// The session is gone: wipes what belongs to it on this phone, the stored login, the route
  /// middleware's copy of it and the notification inbox of that user. Never throws, so the caller
  /// still gets to the login page.
  static Future<void> _endSession() async {
    try {
      // Whose inbox to clear: read before the storage is wiped
      final int? idUser = await NotificationInbox.currentUserId(
        storage: _secureStorage,
      );
      await _secureStorage.deleteAll();
      AuthMiddleware.clearCredentials();
      await NotificationInbox.clear(idUser);
      if (Get.isRegistered<NotificationController>()) {
        Get.find<NotificationController>().reset();
      }
    } catch (e) {
      debugLog('Failed to clear the ended session: $e');
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
                  backgroundColor: const Color(0xFFE63946),
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
