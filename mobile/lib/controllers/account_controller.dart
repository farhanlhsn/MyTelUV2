import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AccountController extends GetxController {
  // State untuk loading
  var isLoading = false.obs;

  // State untuk visibility password
  var isOldPasswordHidden = true.obs;
  var isNewPasswordHidden = true.obs;
  var isConfirmPasswordHidden = true.obs;

  // Text Controllers untuk Profil
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  // Text Controllers untuk Password
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    // Simulasi mengisi data awal (Nanti bisa ambil dari AuthController/API)
    nameController.text = "";
    emailController.text = "";
    phoneController.text = "";
  }

  @override
  void onClose() {
    // Dispose controller agar hemat memori
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  // Fungsi Simpan Profil
  Future<void> saveProfile() async {
    isLoading.value = true;
    await Future.delayed(const Duration(seconds: 2)); // Simulasi API call
    isLoading.value = false;

    Get.snackbar(
      "Berhasil",
      "Profil berhasil diperbarui",
      backgroundColor: Colors.green.shade100,
      colorText: Colors.green.shade900,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // Fungsi Ganti Password
  Future<void> changePassword() async {
    if (newPasswordController.text != confirmPasswordController.text) {
      Get.snackbar("Error", "Konfirmasi password tidak cocok",
          backgroundColor: Colors.red.shade100, colorText: Colors.red);
      return;
    }

    isLoading.value = true;
    await Future.delayed(const Duration(seconds: 2)); // Simulasi API call
    isLoading.value = false;

    // Reset field password setelah berhasil
    oldPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();

    Get.snackbar(
      "Berhasil",
      "Password berhasil diubah",
      backgroundColor: Colors.green.shade100,
      colorText: Colors.green.shade900,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}