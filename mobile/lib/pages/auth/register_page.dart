import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/validators.dart';
import 'auth_feedback.dart';
import '../../utils/app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const Color _primaryRed = AppColors.primary;

  final AuthController _authController = Get.find<AuthController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nimController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = _showTermsDialog;
  late final TapGestureRecognizer _loginTap = TapGestureRecognizer()
    ..onTap = () => Get.back();

  bool _isPasswordObscured = true;
  bool _isConfirmObscured = true;
  bool _isChecked = false;
  bool _showTermsError = false;

  @override
  void dispose() {
    _namaController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _nimController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _termsTap.dispose();
    _loginTap.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_authController.isLoading.value) return;
    FocusScope.of(context).unfocus();

    final bool formValid = _formKey.currentState?.validate() ?? false;
    if (!_isChecked) {
      setState(() => _showTermsError = true);
    }
    if (!formValid || !_isChecked) return;

    // Public registration always creates a MAHASISWA, the server decides the role.
    final AuthResult result = await _authController.register(
      _usernameController.text.trim(),
      _passwordController.text,
      _namaController.text.trim(),
      nimNip: _nimController.text.trim(),
      email: _emailController.text.trim(),
    );
    if (!mounted) return;

    if (result.success) {
      Get.offAllNamed(AppRoutes.registerSuccess);
      return;
    }
    showAuthFailure(
      result,
      title: 'Registrasi Gagal',
      onRetry: _handleRegister,
    );
  }

  void _showTermsDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Syarat dan Ketentuan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Text(
            '1. Akun ini hanya untuk Anda sendiri. Jaga kerahasiaan password '
            'dan jangan membagikannya kepada siapa pun.\n\n'
            '2. Data yang Anda isi (nama, username, NIM, dan email) harus benar '
            'dan dapat dipertanggungjawabkan.\n\n'
            '3. Data pribadi, lokasi, dan data biometrik wajah Anda hanya '
            'digunakan untuk layanan kampus di aplikasi ini, seperti presensi '
            'dan pengelolaan kendaraan.\n\n'
            '4. Penyalahgunaan aplikasi, misalnya presensi atas nama orang lain '
            'atau data palsu, dapat menyebabkan akun dinonaktifkan.\n\n'
            '5. Hubungi admin jika Anda perlu mengubah atau menghapus data akun.',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
    String? helper,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      label: Text(label, maxLines: 2),
      hintText: hint,
      helperText: helper,
      helperMaxLines: 4,
      errorMaxLines: 3,
      labelStyle: const TextStyle(
        color: Colors.grey,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryRed,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Kembali',
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () {
                      Get.back();
                    },
                  ),
                  const Text(
                    'Daftar',
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
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selamat bergabung,',
                            style: TextStyle(
                              color: _primaryRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                          const Text(
                            'Halo, buat akun mahasiswa Anda',
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
                            autofillHints: const [AutofillHints.name],
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: _decoration(
                              label: 'Nama Lengkap',
                              icon: Icons.person_outline,
                            ),
                            validator: Validators.nama,
                          ),
                          const SizedBox(height: 20),

                          // Username Field
                          TextFormField(
                            controller: _usernameController,
                            autofillHints: const [AutofillHints.newUsername],
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: _decoration(
                              label: 'Username',
                              icon: Icons.account_circle_outlined,
                              helper:
                                  'Diawali huruf; huruf, angka, dan underscore',
                            ),
                            validator: Validators.username,
                          ),
                          const SizedBox(height: 20),

                          // Email Field (opsional)
                          TextFormField(
                            controller: _emailController,
                            autofillHints: const [AutofillHints.email],
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: _decoration(
                              label: 'Email (opsional)',
                              icon: Icons.email_outlined,
                              helper:
                                  'Dipakai untuk reset password. Tanpa email, hubungi admin saat lupa password.',
                            ),
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 20),

                          // NIM Field (opsional)
                          TextFormField(
                            controller: _nimController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _decoration(
                              label: 'NIM (opsional)',
                              icon: Icons.numbers_outlined,
                              hint: 'Masukkan 11-12 digit angka',
                            ),
                            validator: (String? value) =>
                                Validators.nimNip(value),
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            autofillHints: const [AutofillHints.newPassword],
                            autocorrect: false,
                            enableSuggestions: false,
                            obscureText: _isPasswordObscured,
                            textInputAction: TextInputAction.next,
                            decoration: _decoration(
                              label: 'Password',
                              icon: Icons.lock_outline,
                              helper: 'Minimal 8 karakter, huruf dan angka',
                              suffixIcon: IconButton(
                                tooltip: _isPasswordObscured
                                    ? 'Tampilkan password'
                                    : 'Sembunyikan password',
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
                            validator: Validators.password,
                          ),
                          const SizedBox(height: 20),

                          // Konfirmasi Password Field
                          TextFormField(
                            controller: _confirmPasswordController,
                            autofillHints: const [AutofillHints.newPassword],
                            autocorrect: false,
                            enableSuggestions: false,
                            obscureText: _isConfirmObscured,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleRegister(),
                            decoration: _decoration(
                              label: 'Konfirmasi Password',
                              icon: Icons.lock_reset_outlined,
                              suffixIcon: IconButton(
                                tooltip: _isConfirmObscured
                                    ? 'Tampilkan password'
                                    : 'Sembunyikan password',
                                icon: Icon(
                                  _isConfirmObscured
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isConfirmObscured = !_isConfirmObscured;
                                  });
                                },
                              ),
                            ),
                            validator: (String? value) =>
                                Validators.confirmPassword(
                                  value,
                                  _passwordController.text,
                                ),
                          ),
                          const SizedBox(height: 20),

                          // Terms and Conditions Checkbox
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _isChecked,
                                activeColor: _primaryRed,
                                onChanged: (bool? newValue) {
                                  setState(() {
                                    _isChecked = newValue ?? false;
                                    if (_isChecked) _showTermsError = false;
                                  });
                                },
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text.rich(
                                    TextSpan(
                                      children: <InlineSpan>[
                                        const TextSpan(
                                          text:
                                              'Dengan membuat akun, Anda menyetujui ',
                                        ),
                                        TextSpan(
                                          text: 'Syarat dan Ketentuan',
                                          style: const TextStyle(
                                            color: _primaryRed,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          recognizer: _termsTap,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_showTermsError)
                            const Padding(
                              padding: EdgeInsets.only(left: 12, top: 4),
                              child: Text(
                                'Anda harus menyetujui Syarat dan Ketentuan',
                                style: TextStyle(
                                  color: Color(0xFFB3261E),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),

                          // Register Button
                          Obx(() {
                            final bool isLoading =
                                _authController.isLoading.value;
                            return SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryRed,
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
                                        'Daftar',
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

                          // Login Link
                          Center(
                            child: Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                children: <InlineSpan>[
                                  const TextSpan(text: 'Sudah punya akun? '),
                                  TextSpan(
                                    text: 'Masuk',
                                    style: const TextStyle(
                                      color: _primaryRed,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: _loginTap,
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
