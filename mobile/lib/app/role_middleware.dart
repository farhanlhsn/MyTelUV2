import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'auth_middleware.dart';
import 'routes.dart';

class RoleMiddleware extends GetMiddleware {
  final List<String> allowedRoles;
  RoleMiddleware(this.allowedRoles);

  @override
  int? get priority => 2;

  @override
  RouteSettings? redirect(String? route) {
    if (AuthMiddleware.cachedToken == null || AuthMiddleware.cachedToken!.isEmpty) {
      return const RouteSettings(name: AppRoutes.login);
    }

    final role = AuthMiddleware.cachedRole;
    if (role == null || !allowedRoles.contains(role.toUpperCase())) {
      Future.delayed(Duration.zero, () {
        Get.snackbar(
          'Akses Ditolak',
          'Anda tidak memiliki akses ke halaman ini.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFE63946),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          icon: const Icon(Icons.lock, color: Colors.white),
        );
      });
      return const RouteSettings(name: AppRoutes.home);
    }
    return null;
  }
}
