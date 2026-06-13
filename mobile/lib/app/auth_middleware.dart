import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'routes.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  static String? cachedToken;
  static String? cachedRole;
  static bool hasLoaded = false;
  static DateTime? cachedTokenExpiry;

  static Future<void> loadCredentials() async {
    const storage = FlutterSecureStorage();
    cachedToken = await storage.read(key: 'token');
    cachedRole = await storage.read(key: 'role');
    cachedTokenExpiry = _parseJwtExpiry(cachedToken);
    hasLoaded = true;
  }

  static void clearCredentials() {
    cachedToken = null;
    cachedRole = null;
    cachedTokenExpiry = null;
    hasLoaded = false;
  }

  /// Parse JWT payload dan ekstrak expiry time
  static DateTime? _parseJwtExpiry(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // Base64 decode payload (bagian kedua)
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final data = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = data['exp'];
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
    } catch (_) {
      return null;
    }
  }

  /// Cek apakah token masih valid (tidak expired)
  static bool get isTokenValid {
    if (cachedToken == null || cachedToken!.isEmpty) return false;
    if (cachedTokenExpiry == null) return false;
    // Buffer 30 detik untuk menghindari race condition
    return cachedTokenExpiry!.isAfter(DateTime.now().add(const Duration(seconds: 30)));
  }

  @override
  RouteSettings? redirect(String? route) {
    if (!isTokenValid) {
      return const RouteSettings(name: AppRoutes.login);
    }
    return null;
  }
}
