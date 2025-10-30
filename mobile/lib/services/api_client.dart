import 'dart:io';

import 'package:dio/dio.dart';

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
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: <String, dynamic>{'Content-Type': 'application/json'},
    ),
  );
}
