import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';

class AccountController extends GetxController {
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
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
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final nama = await _secureStorage.read(key: 'nama');
      nameController.text = nama ?? '';
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  // Fungsi Simpan Profil - Now using real API
  Future<void> saveProfile() async {
    if (nameController.text.trim().isEmpty) {
      Get.snackbar(
        "Error",
        "Nama tidak boleh kosong",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isLoading.value = true;
    
    try {
      final result = await _authService.updateProfile(
        nama: nameController.text.trim(),
      );

      if (result['status'] == 'success') {
        // Update local storage
        await _secureStorage.write(key: 'nama', value: nameController.text.trim());
        
        Get.snackbar(
          "Berhasil",
          "Profil berhasil diperbarui",
          backgroundColor: Colors.green.shade100,
          colorText: Colors.green.shade900,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        throw Exception(result['message'] ?? 'Gagal update profil');
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Fungsi Ganti Password - Now using real API
  Future<void> changePassword() async {
    if (oldPasswordController.text.isEmpty || newPasswordController.text.isEmpty) {
      Get.snackbar(
        "Error",
        "Password lama dan baru harus diisi",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (newPasswordController.text != confirmPasswordController.text) {
      Get.snackbar(
        "Error",
        "Konfirmasi password tidak cocok",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (newPasswordController.text.length < 6) {
      Get.snackbar(
        "Error",
        "Password baru minimal 6 karakter",
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isLoading.value = true;

    try {
      final result = await _authService.changePassword(
        oldPassword: oldPasswordController.text,
        newPassword: newPasswordController.text,
      );

      if (result['status'] == 'success') {
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
      } else {
        throw Exception(result['message'] ?? 'Gagal ubah password');
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}