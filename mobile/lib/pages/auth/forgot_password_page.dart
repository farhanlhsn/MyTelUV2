import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/error_helper.dart';
import 'auth_feedback.dart';
import '../../utils/app_theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final AuthController _authController = Get.find<AuthController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (_authController.isLoading.value) return;
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    final AuthResult result = await _authController.forgotPassword(
      _usernameController.text.trim(),
    );
    if (!mounted) return;

    if (result.success) {
      // Navigate to reset password page where user can paste the token. Navigate first: the
      // toast is only a courtesy and must never keep the user on this page.
      Get.toNamed(AppRoutes.resetPassword);
      ErrorHelper.showSuccess(
        'Jika username atau email terdaftar, token reset telah dikirim ke email Anda.',
      );
      return;
    }

    showAuthFailure(
      result,
      title: 'Gagal Mengirim Token',
      onRetry: _handleForgotPassword,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lupa Password',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        // Scrollable so the keyboard never overflows the column on a small screen.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reset Password',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Masukkan username atau email Anda. Kami akan mengirimkan token reset ke email Anda.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _usernameController,
                  autofillHints: const [AutofillHints.username],
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleForgotPassword(),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    labelText: 'Username atau Email',
                    helperText:
                        'Belum mengisi email saat mendaftar? Hubungi admin untuk mereset password.',
                    helperMaxLines: 3,
                    errorMaxLines: 3,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username/Email wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                Obx(() {
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _authController.isLoading.value
                          ? null
                          : _handleForgotPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _authController.isLoading.value
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Kirim Token Reset',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () => Get.toNamed(AppRoutes.resetPassword),
                    child: const Text(
                      'Sudah punya token? Masukkan di sini',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
