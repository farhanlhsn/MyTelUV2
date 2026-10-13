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
import 'auth_result.dart';

export 'auth_result.dart';

class AuthController extends GetxController {
  final RxBool isLoading = false.obs;
  final AuthService _authService;
  final FlutterSecureStorage _secureStorage;
  final Future<void> Function() _registerNotificationToken;
  final Future<void> Function() _unregisterNotificationToken;
  final Future<void> Function(int? idUser) _clearNotificationInbox;

  AuthController({
    AuthService? authService, 
    FlutterSecureStorage? secureStorage,
    Future<void> Function()? registerNotificationToken,
    Future<void> Function()? unregisterNotificationToken,
    Future<void> Function(int? idUser)? clearNotificationInbox,
  }) : _authService = authService ?? AuthService(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _registerNotificationToken = registerNotificationToken ?? NotificationService.registerToken,
       _unregisterNotificationToken = unregisterNotificationToken ?? NotificationService.unregisterToken,
       _clearNotificationInbox = clearNotificationInbox ?? NotificationService.clearInbox;

  Future<bool> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      return false;
    }
    isLoading.value = true;
    try {
      // Hapus token lama terlebih dahulu untuk memastikan clean state
      await _secureStorage.deleteAll();
      debugLog('🗑️ Cleared all old tokens and user data');

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

      await AuthMiddleware.loadCredentials(storage: _secureStorage);

      debugLog(
        '✅ Saved new token for user: ${user.username} (ID: ${user.idUser})',
      );

      // Reset Dio instance to ensure new token is used
      ApiClient.reset();
      debugLog('🔄 Reset Dio instance');

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

  /// Public registration: the server always creates a MAHASISWA.
  Future<AuthResult> register(
    String username,
    String password,
    String nama, {
    String? nimNip,
    String? email,
  }) async {
    if (username.isEmpty || password.isEmpty || nama.isEmpty) {
      return const AuthResult.failure('Nama, username, dan password wajib diisi');
    }
    isLoading.value = true;
    try {
      final Map<String, dynamic> result = await _authService.register(
        username: username,
        password: password,
        nama: nama,
        nimNip: nimNip,
        email: email,
      );

      if (result['status'] == 'success') {
        return AuthResult.success(result['message']?.toString() ?? 'Akun berhasil dibuat');
      }
      return AuthResult.failure(
        result['message']?.toString() ?? 'Registrasi gagal. Silakan coba lagi.',
      );
    } catch (e) {
      debugLog('❌ Register failed: $e');
      return _failureOf(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> logout() async {
    try {
      final String? refreshToken = await _secureStorage.read(key: 'refresh_token');
      // Whose inbox to clear: read before the user data is removed below
      final int? idUser = int.tryParse(await _secureStorage.read(key: 'id_user') ?? '');

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
      debugLog('🚪 Logged out and reset Dio instance');

      // Unregister FCM token locally
      await _unregisterNotificationToken();

      // The notification inbox is local to this phone: it must not outlive the session
      await _clearNotificationInbox(idUser);

      return true;
    } catch (e) {
      debugLog('❌ Logout failed: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<AuthResult> forgotPassword(String username) async {
    if (username.isEmpty) {
      return const AuthResult.failure('Username atau email wajib diisi');
    }
    isLoading.value = true;
    try {
      final result = await _authService.forgotPassword(username);
      if (result['status'] == 'success') {
        return AuthResult.success(result['message']?.toString() ?? '');
      }
      return AuthResult.failure(
        result['message']?.toString() ?? 'Terjadi kesalahan saat mengirim permintaan reset.',
      );
    } catch (e) {
      debugLog('❌ Forgot password failed: $e');
      return _failureOf(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<AuthResult> resetPassword(String token, String newPassword) async {
    if (token.isEmpty || newPassword.isEmpty) {
      return const AuthResult.failure('Token dan password baru wajib diisi');
    }
    isLoading.value = true;
    try {
      final result = await _authService.resetPassword(
        token: token,
        newPassword: newPassword,
      );
      if (result['status'] == 'success') {
        return AuthResult.success(result['message']?.toString() ?? '');
      }
      return AuthResult.failure(
        result['message']?.toString() ?? 'Reset password gagal. Silakan coba lagi.',
      );
    } catch (e) {
      debugLog('❌ Reset password failed: $e');
      return _failureOf(e);
    } finally {
      isLoading.value = false;
    }
  }

  AuthResult _failureOf(Object error) {
    return AuthResult.failure(
      ErrorHelper.parseError(error),
      isConnectionError: ErrorHelper.isConnectionError(error),
    );
  }
}
