import 'package:mobile/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../app/auth_middleware.dart';
import '../services/auth_service.dart';
import 'auth_result.dart';
import '../utils/error_helper.dart';
import '../utils/validators.dart';



class AccountController extends GetxController {
  final AuthService _authService;
  final FlutterSecureStorage _secureStorage;
  final Future<void> Function() _reloadCredentials;

  AccountController({
    AuthService? authService,
    FlutterSecureStorage? secureStorage,
    Future<void> Function()? reloadCredentials,
  }) : _authService = authService ?? AuthService(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _reloadCredentials = reloadCredentials ?? AuthMiddleware.loadCredentials;
  
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
      debugLog('Error loading user data: $e');
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
      ErrorHelper.showToast(
        "Gagal",
        "Nama tidak boleh kosong",
        backgroundColor: Colors.red.shade100,
        textColor: Colors.red,
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
        
        ErrorHelper.showToast(
          "Berhasil",
          "Profil berhasil diperbarui",
          backgroundColor: Colors.green.shade100,
          textColor: Colors.green.shade900,
        );
      } else {
        throw Exception(result['message'] ?? 'Gagal update profil');
      }
    } catch (e) {
      ErrorHelper.showToast(
        "Gagal",
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red.shade100,
        textColor: Colors.red,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Fungsi Ganti Password - Now using real API
  Future<void> changePassword() async {
    final AuthResult result = await submitPasswordChange();

    if (result.success) {
      ErrorHelper.showToast(
        "Berhasil",
        result.message,
        backgroundColor: Colors.green.shade100,
        textColor: Colors.green.shade900,
      );
    } else {
      ErrorHelper.showToast(
        "Gagal",
        result.message,
        backgroundColor: Colors.red.shade100,
        textColor: Colors.red,
      );
    }
  }

  /// Validates the form, changes the password and keeps this device logged in. Returns the
  /// outcome instead of showing it, so [changePassword] owns the feedback.
  ///
  /// The server revokes every refresh token of the user and answers with a fresh token pair; it
  /// is saved here (same storage keys as login) or the next token refresh would log this device out.
  Future<AuthResult> submitPasswordChange() async {
    if (oldPasswordController.text.isEmpty || newPasswordController.text.isEmpty) {
      return const AuthResult.failure('Password lama dan baru harus diisi');
    }

    if (newPasswordController.text != confirmPasswordController.text) {
      return const AuthResult.failure('Konfirmasi password tidak cocok');
    }

    final String? passwordError = Validators.password(newPasswordController.text);
    if (passwordError != null) {
      return AuthResult.failure(passwordError);
    }

    isLoading.value = true;

    try {
      final result = await _authService.changePassword(
        oldPassword: oldPasswordController.text,
        newPassword: newPasswordController.text,
      );

      if (result['status'] != 'success') {
        return AuthResult.failure(
          result['message']?.toString() ?? 'Gagal ubah password',
        );
      }

      await _storeRefreshedSession(result['data']);

      // Reset field password setelah berhasil
      oldPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();

      return const AuthResult.success('Password berhasil diubah');
    } catch (e) {
      return AuthResult.failure(ErrorHelper.parseError(e));
    } finally {
      isLoading.value = false;
    }
  }

  /// Saves the token pair the server returns after a password change (same keys as login).
  Future<void> _storeRefreshedSession(dynamic data) async {
    if (data is! Map) return;
    final String token = data['token'] as String? ?? '';
    final String refreshToken = data['refresh_token'] as String? ?? '';
    if (token.isEmpty) return;

    await _secureStorage.write(key: 'token', value: token);
    if (refreshToken.isNotEmpty) {
      await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    }
    // Route guard reads the token expiry from a cache that still holds the old token.
    await _reloadCredentials();
  }
}
