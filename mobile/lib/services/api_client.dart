import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

String _detectBaseUrl() {
  // Android emulator uses 10.0.2.2 to reach host machine
  const String androidHost = 'http://10.0.2.2:5050';
  const String defaultHost = 'http://localhost:5050';
  try {
    return Platform.isAndroid ? androidHost : defaultHost;
  } catch (_) {
    return defaultHost;
  }
}

class ApiClient {
  static final String baseUrl = _detectBaseUrl();
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  static Dio? _dioInstance;

  static Dio get dio {
    if (_dioInstance == null) {
      print('🔧 Initializing Dio with baseUrl: $baseUrl');

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
            print('📤 Headers: ${options.headers}');

            // Get token from secure storage
            try {
              final String? token = await _secureStorage.read(key: 'token');
              print(
                '🔑 Token: ${token != null ? "EXISTS (${token.substring(0, 20)}...)" : "NULL"}',
              );

              // Add token to header if exists
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (e) {
              print('❌ Error reading token: $e');
            }

            return handler.next(options);
          },
          onResponse: (response, handler) {
            print(
              '✅ Response: ${response.statusCode} ${response.statusMessage}',
            );
            print('📥 Data: ${response.data}');
            return handler.next(response);
          },
          onError: (DioException error, ErrorInterceptorHandler handler) async {
            print('❌ DioError Type: ${error.type}');
            print('❌ DioError Message: ${error.message}');
            print('❌ DioError Response: ${error.response?.data}');

            // Handle 401 Unauthorized
            if (error.response?.statusCode == 401) {
              print('🚪 Token expired, clearing storage');
              await _secureStorage.deleteAll();
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
}
