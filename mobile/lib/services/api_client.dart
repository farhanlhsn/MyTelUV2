import 'dart:io';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart' hide Response;

/// Environment configuration for API URLs
/// 
/// Usage:
/// - Development: `flutter run` (default, uses localhost)
/// - Production: `flutter run --dart-define=ENV=prod` or `flutter build apk --dart-define=ENV=prod`
class AppConfig {
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');
  
  static bool get isProduction => _env == 'prod';
  static bool get isDevelopment => _env == 'dev';
  
  static String get baseUrl {
    if (isProduction) {
      // Production URL
      return dotenv.env['API_URL_PROD'] ?? 'http://213.210.37.132:5050';
    }
    
    // Development URL
    try {
      if (Platform.isAndroid) {
        // Android emulator uses 10.0.2.2 to reach host machine
        return dotenv.env['API_URL_DEV'] ?? 'http://10.0.2.2:5050';
      }
      return dotenv.env['API_URL_DEV_DEFAULT'] ?? 'http://localhost:5050';
    } catch (_) {
      return dotenv.env['API_URL_DEV_DEFAULT'] ?? 'http://localhost:5050';
    }
  }
  
  static String get envName => _env.toUpperCase();
}

class ApiClient {
  static final String baseUrl = AppConfig.baseUrl;
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  static Dio? _dioInstance;

  static Dio get dio {
    if (_dioInstance == null) {
      print('🔧 Initializing Dio with baseUrl: $baseUrl (ENV: ${AppConfig.envName})');

      _dioInstance = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: <String, dynamic>{'Content-Type': 'application/json'},
        ),
      );

      // Add logging interceptor
      _dioInstance!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            print(
              '🌐 Request: ${options.method} ${options.baseUrl}${options.path}',
            );
            if (AppConfig.isDevelopment) {
              print('📤 Headers: ${options.headers}');
            }

            // Get token from secure storage
            try {
              final String? token = await _secureStorage.read(key: 'token');
              if (AppConfig.isDevelopment) {
<<<<<<< Updated upstream
                print(
                  '🔑 Token: ${token != null ? "EXISTS (${token.substring(0, 20)}...)" : "NULL"}',
=======
                debugLog(
                  '🔑 Token: ${token != null ? "EXISTS (Length: ${token.length})" : "NULL"}',
>>>>>>> Stashed changes
                );
              }

              // Add token to header if exists
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (e) {
              print('❌ Error reading token: $e');
            }

            return handler.next(options);
          },
          onResponse: (response, handler) async {
            print(
              '✅ Response: ${response.statusCode} ${response.statusMessage}',
            );
            if (AppConfig.isDevelopment) {
              print('📥 Data: ${response.data}');
            }
            
<<<<<<< Updated upstream
            // Handle 401 Unauthorized in response (because validateStatus accepts < 500)
            if (response.statusCode == 401) {
              print('🚪 Token expired (in response), clearing storage and redirecting to login');
              await _secureStorage.deleteAll();
              _dioInstance = null; // Reset Dio instance
              _redirectToLogin();
            }
            
=======
>>>>>>> Stashed changes
            return handler.next(response);
          },
          onError: (DioException error, ErrorInterceptorHandler handler) async {
            print('❌ DioError Type: ${error.type}');
            print('❌ DioError Message: ${error.message}');
            if (AppConfig.isDevelopment) {
              print('❌ DioError Response: ${error.response?.data}');
            }

            // Handle 401 Unauthorized - Token expired
            if (error.response?.statusCode == 401) {
<<<<<<< Updated upstream
              print('🚪 Token expired, clearing storage and redirecting to login');
=======
              final bool refreshed = await _attemptTokenRefresh(error.requestOptions);
              if (refreshed) {
                // Retry the request
                try {
                  final String? newToken = await _secureStorage.read(key: 'token');
                  error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                  final retryResponse = await Dio(BaseOptions(baseUrl: baseUrl)).fetch(error.requestOptions);
                  return handler.resolve(retryResponse);
                } catch (e) {
                  debugLog('❌ Retry failed after refresh: $e');
                }
              }
              
              debugLog('🚪 Token refresh failed, clearing storage and redirecting to login');
>>>>>>> Stashed changes
              await _secureStorage.deleteAll();
              _dioInstance = null; // Reset Dio instance
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

  static Completer<bool>? _refreshCompleter;

  static Future<bool> _attemptTokenRefresh(RequestOptions requestOptions) async {
    // Prevent refresh loop if the request that failed WAS the refresh request
    if (requestOptions.path.contains('/api/v1/auth/refresh')) {
      return false;
    }

    // If another refresh is in progress, wait for its result (not a blind timer)
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();
    
    try {
      final String? refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      debugLog('🔄 Attempting to refresh token...');
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
            await _secureStorage.write(key: 'refresh_token', value: data['refresh_token']);
          }
          debugLog('✅ Token refreshed successfully');
          _refreshCompleter!.complete(true);
          return true;
        }
      }
      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      debugLog('❌ Refresh token API error: $e');
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  // Method to reset dio instance (useful for logout)
  static void reset() {
    _dioInstance = null;
  }
  
  // Flag to prevent multiple redirects
  static bool _isRedirecting = false;
  
  // Helper method to redirect to login page
  static void _redirectToLogin() {
    // Prevent multiple redirects
    if (_isRedirecting) return;
    _isRedirecting = true;
    
    // Reset flag after short delay to allow future redirects
    Future.delayed(const Duration(seconds: 2), () {
      _isRedirecting = false;
    });
    
    // Show session expired dialog
    if (Get.context != null) {
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timer_off, color: Colors.orange.shade400, size: 24),
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
                  Get.back(); // Close dialog
                  Get.offAllNamed('/login'); // Navigate to login and clear stack
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Login Kembali', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } else {
      // Fallback: direct navigation if dialog can't be shown
      Get.offAllNamed('/login');
    }
  }
}
