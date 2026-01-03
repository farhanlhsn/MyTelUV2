import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../models/user.dart';

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

      if (token.isEmpty) {
        return false;
      }

      final UserModel user = UserModel.fromMap(data);

      // Simpan token dan data user baru
      await _secureStorage.write(key: 'token', value: token);
      await _secureStorage.write(key: 'id_user', value: user.idUser.toString());
      await _secureStorage.write(key: 'username', value: user.username);
      await _secureStorage.write(key: 'nama', value: user.nama);
      await _secureStorage.write(key: 'role', value: user.role);

      print(
        '✅ Saved new token for user: ${user.username} (ID: ${user.idUser})',
      );
      print('🔑 Token preview: ${token.length > 20 ? token.substring(0, 20) : token}...');

      // Reset Dio instance to ensure new token is used
      ApiClient.reset();
      print('🔄 Reset Dio instance');

      // Register FCM token for push notifications
      await _registerNotificationToken();

      return true;
    } on DioException catch (e) {
      print('❌ Login failed: ${e.message}');
      return false;
    } catch (e) {
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
      );

      return true;
    } on DioException catch (e) {
      return false;
    } catch (e) {
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> logout() async {
    try {
      // Call backend logout to clear FCM token server-side
      await _authService.logout();

      // Clear local storage
      await _secureStorage.delete(key: 'token');
      await _secureStorage.delete(key: 'id_user');
      await _secureStorage.delete(key: 'username');
      await _secureStorage.delete(key: 'nama');
      await _secureStorage.delete(key: 'role');

      // Reset Dio instance to clear any cached requests
      ApiClient.reset();
      print('🚪 Logged out and reset Dio instance');

      // Unregister FCM token locally
      await _unregisterNotificationToken();

      return true;
    } catch (e) {
      print('❌ Logout failed: $e');
      return false;
    }
  }
}
