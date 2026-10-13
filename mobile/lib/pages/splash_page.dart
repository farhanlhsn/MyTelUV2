import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes.dart';
import '../app/auth_middleware.dart';
import '../utils/notification_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Small delay for splash screen effect
    await Future.delayed(const Duration(milliseconds: 1000));

    try {
      await AuthMiddleware.loadCredentials();

      if (AuthMiddleware.isTokenValid) {
        Get.offAllNamed(AppRoutes.home);
        // The app is ready and the user is on the home page: open the notification that launched
        // the app (cold start), on top of home so back returns to it
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationNavigator.openPending();
        });
      } else {
        NotificationNavigator.clearPending();
        AuthMiddleware.clearCredentials();
        Get.offAllNamed(AppRoutes.login);
      }
    } catch (e) {
      // Error reading token, go to login
      NotificationNavigator.clearPending();
      Get.offAllNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE63946), // Red color matching homepage
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TelU Logo
            Image.asset('assets/images/telyu.png', width: 150, height: 150),
            const SizedBox(height: 24),
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
