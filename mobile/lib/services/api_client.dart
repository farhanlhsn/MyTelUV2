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
      _dioInstance = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: <String, dynamic>{'Content-Type': 'application/json'},
        ),
      );

      // Add interceptor for authentication
      _dioInstance!.interceptors.add(
        InterceptorsWrapper(
          onRequest:
              (
                RequestOptions options,
                RequestInterceptorHandler handler,
              ) async {
                // Get token from secure storage
                final String? token = await _secureStorage.read(key: 'token');

                // Add token to header if exists
                if (token != null && token.isNotEmpty) {
                  options.headers['Authorization'] = 'Bearer $token';
                }

                return handler.next(options);
              },
          onError: (DioException error, ErrorInterceptorHandler handler) async {
            // Handle 401 Unauthorized
            if (error.response?.statusCode == 401) {
              // Token expired or invalid, clear storage
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
