import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/account_controller.dart';
import '../../utils/app_theme.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Injeksi controller
    final controller = Get.put(AccountController());
    final primaryColor = AppColors.primary; // Merah sesuai tema settings Anda

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Akun Saya"),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(appBackIcon, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SECTION FOTO PROFIL ---
              Center(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: primaryColor.withOpacity(0.2), width: 3),
                        shape: BoxShape.circle,
                      ),
                      // No profile photo exists: a neutral avatar, not a stock picture fetched from a third party
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade300,
                        child: const Icon(Icons.person, size: 56, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- SECTION EDIT PROFIL ---
              const Text("Informasi Pribadi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              
              _buildTextField(
                label: "Nama Lengkap",
                controller: controller.nameController,
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                label: "Email",
                controller: controller.emailController,
                icon: Icons.email_outlined,
                inputType: TextInputType.emailAddress,
                readOnly: true,
                helperText: 'Perubahan email belum tersedia.',
              ),
              const SizedBox(height: 15),
              _buildTextField(
                label: "Nomor Telepon",
                controller: controller.phoneController,
                icon: Icons.phone_android_outlined,
                inputType: TextInputType.phone,
                readOnly: true,
                helperText: 'Perubahan nomor telepon belum tersedia.',
              ),
              
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value ? null : () => controller.saveProfile(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: controller.isLoading.value
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2))
                      : const Text("Simpan Profil", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Divider(thickness: 1),
              ),

              // --- SECTION GANTI PASSWORD ---
              const Text("Keamanan (Ganti Password)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              _buildPasswordField(
                label: "Password Lama",
                controller: controller.oldPasswordController,
                isHidden: controller.isOldPasswordHidden,
              ),
              const SizedBox(height: 15),
              _buildPasswordField(
                label: "Password Baru",
                controller: controller.newPasswordController,
                isHidden: controller.isNewPasswordHidden,
              ),
              const SizedBox(height: 15),
              _buildPasswordField(
                label: "Konfirmasi Password Baru",
                controller: controller.confirmPasswordController,
                isHidden: controller.isConfirmPasswordHidden,
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: controller.isLoading.value ? null : () => controller.changePassword(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text("Ubah Password", style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      }),
    );
  }

  // Widget Helper untuk TextField Biasa
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    bool readOnly = false,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      readOnly: readOnly,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      autofillHints: readOnly ? null : const [AutofillHints.name],
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 3,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  // Widget Helper untuk Password Field
  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required RxBool isHidden,
  }) {
    return Obx(() => TextField(
      controller: controller,
      obscureText: isHidden.value,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
        suffixIcon: IconButton(
          tooltip: isHidden.value ? 'Tampilkan password' : 'Sembunyikan password',
          icon: Icon(
            isHidden.value ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () => isHidden.value = !isHidden.value,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    ));
  }
}
