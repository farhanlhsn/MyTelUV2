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

  /// Whether a refresh token is stored: an expired access token can then still be renewed.
  static bool cachedHasRefreshToken = false;

  /// Reads the session from the secure storage ([storage] is for tests).
  static Future<void> loadCredentials({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) async {
    cachedToken = await storage.read(key: 'token');
    cachedRole = await storage.read(key: 'role');
    final String? refreshToken = await storage.read(key: 'refresh_token');
    cachedHasRefreshToken = refreshToken != null && refreshToken.isNotEmpty;
    cachedTokenExpiry = _parseJwtExpiry(cachedToken);
    hasLoaded = true;
  }

  /// A new access token was stored (the session was refreshed): the cache must follow, otherwise
  /// the middleware keeps judging the old, expired one and sends a valid session to the login page.
  static void updateToken(String? token) {
    cachedToken = token;
    cachedTokenExpiry = _parseJwtExpiry(token);
  }

  static void clearCredentials() {
    cachedToken = null;
    cachedRole = null;
    cachedTokenExpiry = null;
    cachedHasRefreshToken = false;
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

  /// An access token that ran out is not the end of the session while a refresh token exists: the
  /// first request of the page renews it (ApiClient), and only a refresh that fails logs the user
  /// out. The route check cannot wait for that request, so it lets such a session through.
  static bool get canRefreshSession =>
      cachedToken != null && cachedToken!.isNotEmpty && cachedHasRefreshToken;

  @override
  RouteSettings? redirect(String? route) {
    if (!isTokenValid && !canRefreshSession) {
      return const RouteSettings(name: AppRoutes.login);
    }
    return null;
  }
}
