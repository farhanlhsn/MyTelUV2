import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/controllers/account_controller.dart';
import 'package:mockito/mockito.dart';

import 'auth_controller_test.mocks.dart';

void main() {
  late MockAuthService authService;
  late MockFlutterSecureStorage storage;
  late AccountController controller;
  late int credentialReloads;

  setUp(() {
    authService = MockAuthService();
    storage = MockFlutterSecureStorage();
    credentialReloads = 0;
    controller = AccountController(
      authService: authService,
      secureStorage: storage,
      reloadCredentials: () async => credentialReloads++,
    );
  });

  void fillForm({
    String old = 'lama1234',
    String neu = 'baru5678',
    String? confirm,
  }) {
    controller.oldPasswordController.text = old;
    controller.newPasswordController.text = neu;
    controller.confirmPasswordController.text = confirm ?? neu;
  }

  group('submitPasswordChange', () {
    test('stores the fresh token pair so the next refresh keeps working', () async {
      when(
        authService.changePassword(oldPassword: 'lama1234', newPassword: 'baru5678'),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'status': 'success',
          'message': 'Password berhasil diubah',
          'data': <String, dynamic>{
            'id_user': 7,
            'token': 'token-baru',
            'refresh_token': 'refresh-baru',
            'username': 'budi',
            'nama': 'Budi',
            'role': 'MAHASISWA',
          },
        },
      );
      fillForm();

      final result = await controller.submitPasswordChange();

      expect(result.success, isTrue);
      expect(result.message, 'Password berhasil diubah');
      verify(storage.write(key: 'token', value: 'token-baru')).called(1);
      verify(storage.write(key: 'refresh_token', value: 'refresh-baru')).called(1);
      // The route guard caches the old token's expiry; it must be reloaded.
      expect(credentialReloads, 1);
      expect(controller.oldPasswordController.text, isEmpty);
      expect(controller.newPasswordController.text, isEmpty);
      expect(controller.confirmPasswordController.text, isEmpty);
      expect(controller.isLoading.value, isFalse);
    });

    test('a response without a token pair leaves the stored session alone', () async {
      when(
        authService.changePassword(oldPassword: 'lama1234', newPassword: 'baru5678'),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'status': 'success',
          'message': 'Password berhasil diubah',
        },
      );
      fillForm();

      final result = await controller.submitPasswordChange();

      expect(result.success, isTrue);
      verifyNever(storage.write(key: 'token', value: anyNamed('value')));
      verifyNever(storage.write(key: 'refresh_token', value: anyNamed('value')));
      expect(credentialReloads, 0);
    });

    test('does not touch the stored session when the server refuses', () async {
      when(
        authService.changePassword(oldPassword: 'lama1234', newPassword: 'baru5678'),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'status': 'error',
          'message': 'Password lama salah',
        },
      );
      fillForm();

      final result = await controller.submitPasswordChange();

      expect(result.success, isFalse);
      expect(result.message, 'Password lama salah');
      verifyNever(storage.write(key: 'token', value: anyNamed('value')));
      verifyNever(storage.write(key: 'refresh_token', value: anyNamed('value')));
      expect(credentialReloads, 0);
      // The typed passwords stay so the user can correct them.
      expect(controller.oldPasswordController.text, 'lama1234');
      expect(controller.isLoading.value, isFalse);
    });

    test('enforces the 8 character minimum before calling the server', () async {
      fillForm(neu: 'abc123');

      final result = await controller.submitPasswordChange();

      expect(result.success, isFalse);
      expect(result.message, 'Password minimal 8 karakter');
      verifyZeroInteractions(authService);
    });

    test('refuses a mismatching confirmation and blank fields', () async {
      fillForm(neu: 'baru5678', confirm: 'beda5678');
      var result = await controller.submitPasswordChange();
      expect(result.message, 'Konfirmasi password tidak cocok');

      fillForm(old: '');
      result = await controller.submitPasswordChange();
      expect(result.message, 'Password lama dan baru harus diisi');

      verifyZeroInteractions(authService);
    });
  });
}
