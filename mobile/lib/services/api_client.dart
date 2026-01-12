import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
      // Production URL (dengan HTTPS)
      return 'http://213.210.37.132:5050';
    }
    
    // Development URL
    try {
      // Android emulator uses 10.0.2.2 to reach host machine
      return Platform.isAndroid ? 'http://10.0.2.2:5050' : 'http://localhost:5050';
    } catch (_) {
      return 'http://localhost:5050';
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
          validateStatus: (status) {
            // Accept all status codes to handle them manually
            return status != null && status < 500;
          },
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
                print(
                  '🔑 Token: ${token != null ? "EXISTS (${token.substring(0, 20)}...)" : "NULL"}',
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
            
            // Handle 401 Unauthorized in response (because validateStatus accepts < 500)
            if (response.statusCode == 401) {
              print('🚪 Token expired (in response), clearing storage and redirecting to login');
              await _secureStorage.deleteAll();
              _dioInstance = null; // Reset Dio instance
              _redirectToLogin();
            }
            
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
              print('🚪 Token expired, clearing storage and redirecting to login');
              await _secureStorage.deleteAll();
              _dioInstance = null; // Reset Dio instance
              
              // Redirect to login page using Get
              // Import is lazy to avoid circular dependencies
              _redirectToLogin();
            }

            return handler.next(error);
          },
        ),
      );
    }

    return _dioInstance!;
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
