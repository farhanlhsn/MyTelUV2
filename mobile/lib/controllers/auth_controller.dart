import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../models/user.dart';
import '../utils/error_helper.dart';
import 'package:mobile/utils/logger.dart';
import '../app/auth_middleware.dart';

class AuthController extends GetxController {
  final RxBool isLoading = false.obs;
  final AuthService _authService;
  final FlutterSecureStorage _secureStorage;
  final Future<void> Function() _registerNotificationToken;
  final Future<void> Function() _unregisterNotificationToken;

  AuthController({
    AuthService? authService, 
    FlutterSecureStorage? secureStorage,
    Future<void> Function()? registerNotificationToken,
    Future<void> Function()? unregisterNotificationToken,
  }) : _authService = authService ?? AuthService(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _registerNotificationToken = registerNotificationToken ?? NotificationService.registerToken,
       _unregisterNotificationToken = unregisterNotificationToken ?? NotificationService.unregisterToken;

  Future<bool> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      return false;
    }
    isLoading.value = true;
    try {
      // Hapus token lama terlebih dahulu untuk memastikan clean state
      await _secureStorage.deleteAll();
      print('🗑️ Cleared all old tokens and user data');

      final Map<String, dynamic> result = await _authService.login(
        username: username,
        password: password,
      );

      final Map<String, dynamic> data =
          result['data'] as Map<String, dynamic>? ?? <String, dynamic>{};

      final String token = data['token'] as String? ?? '';
      final String refreshToken = data['refresh_token'] as String? ?? '';

      if (token.isEmpty) {
        ErrorHelper.showError('Token tidak ditemukan dalam respon server', title: 'Login Gagal');
        return false;
      }

      final UserModel user = UserModel.fromMap(data);

      // Simpan token dan data user baru
      await _secureStorage.write(key: 'token', value: token);
      if (refreshToken.isNotEmpty) {
        await _secureStorage.write(key: 'refresh_token', value: refreshToken);
      }
      await _secureStorage.write(key: 'id_user', value: user.idUser.toString());
      await _secureStorage.write(key: 'username', value: user.username);
      await _secureStorage.write(key: 'nama', value: user.nama);
      await _secureStorage.write(key: 'role', value: user.role);

      AuthMiddleware.cachedToken = token;
      AuthMiddleware.cachedRole = user.role;
      AuthMiddleware.hasLoaded = true;

      debugLog(
        '✅ Saved new token for user: ${user.username} (ID: ${user.idUser})',
      );

      // Reset Dio instance to ensure new token is used
      ApiClient.reset();
      print('🔄 Reset Dio instance');

      // Register FCM token for push notifications
      await _registerNotificationToken();

      return true;
    } on DioException catch (e) {
      debugLog('❌ Login failed: ${e.message}');
      ErrorHelper.showError(e, title: 'Login Gagal');
      return false;
    } catch (e) {
      debugLog('❌ Login unexpected error: $e');
      ErrorHelper.showError(e, title: 'Login Gagal');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> register(
    String username,
    String password,
    String nama,
    String role,
    {String? nimNip}
  ) async {
    if (username.isEmpty || password.isEmpty || nama.isEmpty || role.isEmpty) {
      return false;
    }
    isLoading.value = true;
    try {
      final Map<String, dynamic> result = await _authService.register(
        username: username,
        password: password,
        nama: nama,
        role: role,
        nimNip: nimNip,
      );

      return true;
    } on DioException catch (e) {
      debugLog('❌ Register failed: ${e.message}');
      ErrorHelper.showError(e, title: 'Registrasi Gagal');
      return false;
    } catch (e) {
      debugLog('❌ Register unexpected error: $e');
      ErrorHelper.showError(e, title: 'Registrasi Gagal');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> logout() async {
    try {
      final String? refreshToken = await _secureStorage.read(key: 'refresh_token');

      // Call backend logout to clear FCM token server-side
      await _authService.logout(refreshToken: refreshToken);

      // Clear local storage
      await _secureStorage.delete(key: 'token');
      await _secureStorage.delete(key: 'refresh_token');
      await _secureStorage.delete(key: 'id_user');
      await _secureStorage.delete(key: 'username');
      await _secureStorage.delete(key: 'nama');
      await _secureStorage.delete(key: 'role');

      AuthMiddleware.clearCredentials();

      // Reset Dio instance to clear any cached requests
      ApiClient.reset();
      print('🚪 Logged out and reset Dio instance');

      // Unregister FCM token locally
      await _unregisterNotificationToken();

      return true;
    } catch (e) {
      print('❌ Logout failed: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
  Future<bool> forgotPassword(String username) async {
    if (username.isEmpty) return false;
    isLoading.value = true;
    try {
      final result = await _authService.forgotPassword(username);
      return result['status'] == 'success';
    } on DioException catch (e) {
      debugLog('❌ Forgot password failed: ${e.message}');
      ErrorHelper.showError(e, title: 'Gagal Kirim Link');
      return false;
    } catch (e) {
      debugLog('❌ Forgot password unexpected error: $e');
      ErrorHelper.showError(e, title: 'Gagal Kirim Link');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    if (token.isEmpty || newPassword.isEmpty) return false;
    isLoading.value = true;
    try {
      final result = await _authService.resetPassword(
        token: token, 
        newPassword: newPassword
      );
      return result['status'] == 'success';
    } on DioException catch (e) {
      debugLog('❌ Reset password failed: ${e.message}');
      ErrorHelper.showError(e, title: 'Reset Password Gagal');
      return false;
    } catch (e) {
      debugLog('❌ Reset password unexpected error: $e');
      ErrorHelper.showError(e, title: 'Reset Password Gagal');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
