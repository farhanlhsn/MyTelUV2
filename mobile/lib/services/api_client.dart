import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart' hide Response;
import 'package:mobile/utils/logger.dart';



import 'package:mobile/utils/logger.dart';

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
  static const String _apiUrlProd = String.fromEnvironment('API_URL_PROD');

  static const String _androidDevFallback = 'http://10.0.2.2:5050';
  static const String _defaultDevFallback = 'http://localhost:5050';

  static bool get isProduction => _env == 'prod';
  static bool get isDevelopment => _env == 'dev';

  static String get baseUrl {
    if (isProduction) {
      if (_apiUrlProd.trim().isEmpty) {
        throw StateError('API_URL_PROD must be set when ENV=prod');
      }
      return _apiUrlProd.trim();
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
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  static Dio? _dioInstance;
  static Completer<bool>? _refreshCompleter;
  static bool _isRedirecting = false;

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

            if (error.response?.statusCode == 401) {
              final bool refreshed = await _attemptTokenRefresh(
                error.requestOptions,
              );
              if (refreshed) {
                try {
                  final String? newToken = await _secureStorage.read(
                    key: 'token',
                  );
                  error.requestOptions.headers['Authorization'] =
                      'Bearer $newToken';
                  final retryResponse = await _dioInstance!.fetch(error.requestOptions);
                  return handler.resolve(retryResponse);
                } catch (e) {
                  debugLog('Retry failed after refresh: $e');
                }
              }

              debugLog(
                'Token refresh failed, clearing storage and redirecting to login',
              );
              await _secureStorage.deleteAll();
              _dioInstance = null;
              _redirectToLogin();
              return;
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

      final response = await refreshDio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data != null && data['token'] != null) {
          await _secureStorage.write(key: 'token', value: data['token']);
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
