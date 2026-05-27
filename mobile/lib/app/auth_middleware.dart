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

  static Future<void> loadCredentials() async {
    const storage = FlutterSecureStorage();
    cachedToken = await storage.read(key: 'token');
    cachedRole = await storage.read(key: 'role');
    hasLoaded = true;
  }

  static void clearCredentials() {
    cachedToken = null;
    cachedRole = null;
    hasLoaded = false;
  }

  @override
  RouteSettings? redirect(String? route) {
    if (cachedToken == null || cachedToken!.isEmpty) {
      return const RouteSettings(name: AppRoutes.login);
    }
    return null;
  }
}
