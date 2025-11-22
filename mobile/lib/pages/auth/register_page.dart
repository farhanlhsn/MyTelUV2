import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../controllers/auth_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthController _authController = Get.find<AuthController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordObscured = true;
  String? _selectedRole;
  final List<String> _roles = ['MAHASISWA', 'DOSEN'];
  bool _isChecked = false;

  @override
  void dispose() {
    _namaController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _formKey.currentState?.validate() == true &&
        _selectedRole != null &&
        _isChecked;
  }

  Future<void> _handleRegister() async {
    if (!_isFormValid) {
      Get.snackbar(
        'Form Tidak Lengkap',
        'Mohon lengkapi semua field dan setujui syarat & ketentuan',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
        icon: const Icon(Icons.warning_amber, color: Colors.orange),
      );
      return;
    }

    final bool success = await _authController.register(
      _usernameController.text.trim(),
      _passwordController.text,
      _namaController.text.trim(),
      _selectedRole!,
    );

    if (!success) {
      Get.snackbar(
        'Registrasi Gagal',
        'Username mungkin sudah digunakan atau terjadi kesalahan',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        icon: const Icon(Icons.error_outline, color: Colors.red),
      );
      return;
    }

    // Berhasil register - navigate ke success page
    Get.offAllNamed(AppRoutes.registerSuccess);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE63946),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () {
                      Get.back();
                    },
                  ),
                  const Text(
                    'Register',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Content Container
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 20,
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome to us,',
                            style: TextStyle(
                              color: Color(0xFFE63946),
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                          const Text(
                            'Hello there, create new account',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 20),

                          // Illustration
                          Center(
                            child: Image.asset(
                              'assets/images/Illustration.png',
                              height: 150,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person_add_alt_1,
                                  size: 150,
                                  color: Colors.grey,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Nama Field
                          TextFormField(
                            controller: _namaController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              labelText: 'Nama Lengkap',
                              labelStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (String? value) {
                              if (value == null || value.isEmpty) {
                                return 'Nama wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Username Field
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              labelText: 'Username',
                              labelStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: const Icon(
                                Icons.account_circle_outlined,
                              ),
                            ),
                            validator: (String? value) {
                              if (value == null || value.isEmpty) {
                                return 'Username wajib diisi';
                              }
                              if (value.length < 3) {
                                return 'Username minimal 3 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _isPasswordObscured,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              labelText: 'Password',
                              labelStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordObscured
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordObscured = !_isPasswordObscured;
                                  });
                                },
                              ),
                            ),
                            validator: (String? value) {
                              if (value == null || value.isEmpty) {
                                return 'Password wajib diisi';
                              }
                              if (value.length < 6) {
                                return 'Password minimal 6 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Role Dropdown
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              labelText: 'Role/Peran',
                              labelStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: const Icon(Icons.badge_outlined),
                            ),
                            value: _selectedRole,
                            hint: const Text('Pilih role Anda...'),
                            isExpanded: true,
                            items: _roles.map((String role) {
                              return DropdownMenuItem<String>(
                                value: role,
                                child: Text(role),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedRole = newValue;
                              });
                            },
                            validator: (String? value) {
                              if (value == null) {
                                return 'Role wajib dipilih';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Terms and Conditions Checkbox
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _isChecked,
                                activeColor: const Color(0xFFE63946),
                                onChanged: (bool? newValue) {
                                  setState(() {
                                    _isChecked = newValue!;
                                  });
                                },
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: RichText(
                                    text: TextSpan(
                                      children: <TextSpan>[
                                        const TextSpan(
                                          text:
                                              'By creating an account you agree to our ',
                                          style: TextStyle(color: Colors.black),
                                        ),
                                        TextSpan(
                                          text: 'Terms and Conditions',
                                          style: const TextStyle(
                                            color: Color(0xFFE63946),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              // TODO: Navigate to terms page
                                              Get.snackbar(
                                                'Info',
                                                'Terms and Conditions page',
                                              );
                                            },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Sign Up Button
                          Obx(() {
                            final bool isLoading =
                                _authController.isLoading.value;
                            return SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE63946),
                                  disabledBackgroundColor: const Color(
                                    0xFFFAA0A0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            );
                          }),
                          const SizedBox(height: 30),

                          // Sign In Link
                          Center(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                                children: <TextSpan>[
                                  const TextSpan(text: 'Have an account? '),
                                  TextSpan(
                                    text: 'Sign In',
                                    style: const TextStyle(
                                      color: Color(0xFFE63946),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Get.back();
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
