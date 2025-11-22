import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes.dart';

class RegisterSuccessPage extends StatefulWidget {
  const RegisterSuccessPage({super.key});

  @override
  State<RegisterSuccessPage> createState() => _RegisterSuccessPageState();
}

class _RegisterSuccessPageState extends State<RegisterSuccessPage> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  void _navigateToLogin() {
    // Auto redirect ke login setelah 3 detik
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Get.offAllNamed(AppRoutes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE63946),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon/Illustration
              Image.asset(
                'assets/images/Done-rafiki_1.png',
                height: 250,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    width: 250,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 150,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              // Success Title
              const Text(
                'Registrasi Berhasil!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Success Message
              const Text(
                'Akun Anda telah berhasil dibuat.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Redirect Info
              Text(
                'Anda akan diarahkan ke halaman login...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),

              // Loading Indicator
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              const SizedBox(height: 30),

              // Manual Navigation Button (optional)
              TextButton(
                onPressed: () {
                  Get.offAllNamed(AppRoutes.login);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                child: const Text(
                  'Lanjut ke Login',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
