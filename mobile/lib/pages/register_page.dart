import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes.dart';
import '../controllers/auth_controller.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController controller = Get.find<AuthController>();

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController usernameC = TextEditingController();
    final TextEditingController passwordC = TextEditingController();
    final TextEditingController namaC = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextFormField(
                controller: usernameC,
                decoration: const InputDecoration(labelText: 'Username'),
                keyboardType: TextInputType.text,
                validator: (String? v) {
                  if (v == null || v.isEmpty) return 'Username wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordC,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (String? v) {
                  if (v == null || v.isEmpty) return 'Password wajib diisi';
                  if (v.length < 6) return 'Minimal 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: namaC,
                decoration: const InputDecoration(labelText: 'Nama'),
                keyboardType: TextInputType.text,
                validator: (String? v) {
                  if (v == null || v.isEmpty) return 'Nama wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Obx(() {
                final bool loading = controller.isLoading.value;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            final bool ok = await controller.register(
                              usernameC.text.trim(),
                              passwordC.text,
                              namaC.text,
                              'MAHASISWA',
                            );

                            if (!ok) {
                              Get.snackbar(
                                'Gagal',
                                'Register gagal, username mungkin sudah digunakan',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                              return;
                            }

                            // Berhasil register, kembali ke login
                            Get.snackbar(
                              'Berhasil',
                              'Registrasi berhasil! Silakan login',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                            );
                            Get.offAllNamed(AppRoutes.login);
                          },
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Register'),
                  ),
                );
              }),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Sudah punya akun? Login di sini'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
