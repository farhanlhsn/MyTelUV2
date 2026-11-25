import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mobile/app/auth_middleware.dart';
import 'package:mobile/controllers/auth_controller.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

// Generate mocks
@GenerateNiceMocks([MockSpec<AuthService>(), MockSpec<FlutterSecureStorage>()])
import 'auth_controller_test.mocks.dart';
import 'support/user_scoped_controllers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthController authController;
  late MockAuthService mockAuthService;
  late MockFlutterSecureStorage mockSecureStorage;
  late List<int?> clearedInboxes;
  late int scheduleCacheClears;

  setUp(() {
    clearedInboxes = <int?>[];
    scheduleCacheClears = 0;
    mockAuthService = MockAuthService();
    mockSecureStorage = MockFlutterSecureStorage();
    
    // Inject mocks and no-op for static callbacks
    authController = AuthController(
      authService: mockAuthService,
      secureStorage: mockSecureStorage,
      registerNotificationToken: () async {},
      unregisterNotificationToken: () async {},
      clearNotificationInbox: (int? idUser) async => clearedInboxes.add(idUser),
      clearScheduleCache: () async => scheduleCacheClears++,
    );
  });

  tearDown(() {
    AuthMiddleware.clearCredentials();
    Get.reset();
  });

  group('AuthController', () {
    test('login success should return true and save token', () async {
      // Arrange
      const username = 'testuser';
      const password = 'password';
      const mockResponse = {
        'data': {
          'token': 'mock_token',
          'id_user': 1,
          'username': 'testuser',
          'nama': 'Test User',
          'role': 'MAHASISWA'
        }
      };

      when(mockAuthService.login(username: username, password: password))
          .thenAnswer((_) async => mockResponse);
      when(mockSecureStorage.read(key: 'token')).thenAnswer((_) async => 'mock_token');

      // Act
      final result = await authController.login(username, password);

      // Assert
      expect(result, true);
      verify(mockSecureStorage.write(key: 'token', value: 'mock_token')).called(1);
      verify(mockSecureStorage.write(key: 'username', value: 'testuser')).called(1);
      // The route guard reads the session from the same (injected) storage, not from a real plugin
      expect(AuthMiddleware.cachedToken, 'mock_token');
    });

    test('login clears previous user controllers before writing the new session', () async {
      putUserScopedControllers();
      expect(registeredUserScopedControllers(), hasLength(4));
      when(mockAuthService.login(username: 'nextuser', password: 'password'))
          .thenAnswer((_) async => <String, dynamic>{
                'data': <String, dynamic>{
                  'token': 'next_token',
                  'id_user': 2,
                  'username': 'nextuser',
                  'nama': 'Next User',
                  'role': 'MAHASISWA',
                },
              });
      var checkedBeforeWrite = false;
      when(mockSecureStorage.write(key: 'token', value: 'next_token'))
          .thenAnswer((_) async {
        checkedBeforeWrite = true;
        expect(registeredUserScopedControllers(), isEmpty,
            reason: 'No controller may retain the old user when the new token is stored');
      });

      expect(await authController.login('nextuser', 'password'), true);
      expect(checkedBeforeWrite, true);
      expect(registeredUserScopedControllers(), isEmpty);
    });

    test('login failure (invalid credentials) should return false', () async {
      // Arrange
      when(mockAuthService.login(username: 'fail', password: 'fail'))
          .thenAnswer((_) async => {}); // Empty response or error

      // Act
      final result = await authController.login('fail', 'fail');

      // Assert
      expect(result, false);
      verifyNever(mockSecureStorage.write(key: 'token', value: anyNamed('value')));
    });

    test('logout should clear storage and return true', () async {
      // Act
      final result = await authController.logout();

      // Assert
      expect(result, true);
      verify(mockSecureStorage.delete(key: 'token')).called(1);
      verify(mockAuthService.logout()).called(1);
    });

    test('logout deletes the controllers that hold user data, so the next user starts clean', () async {
      putUserScopedControllers();
      expect(registeredUserScopedControllers(), hasLength(4), reason: 'precondition');

      final result = await authController.logout();

      expect(result, true);
      expect(registeredUserScopedControllers(), isEmpty);
    });

    test('logout clears the saved schedule: the next user must not get it offline', () async {
      final result = await authController.logout();

      expect(result, true);
      expect(scheduleCacheClears, 1);
    });

    test('a schedule cache that cannot be cleared does not fail the logout', () async {
      final AuthController controller = AuthController(
        authService: mockAuthService,
        secureStorage: mockSecureStorage,
        registerNotificationToken: () async {},
        unregisterNotificationToken: () async {},
        clearNotificationInbox: (int? idUser) async {},
        clearScheduleCache: () async => throw Exception('prefs rusak'),
      );

      expect(await controller.logout(), true);
    });

    test('a logout that failed keeps them: the user is still logged in', () async {
      when(mockAuthService.logout(refreshToken: anyNamed('refreshToken'))).thenThrow(Exception('offline'));
      putUserScopedControllers();

      final result = await authController.logout();

      expect(result, false);
      expect(registeredUserScopedControllers(), hasLength(4));
    });

    test('logout clears the local notification inbox of the user who logs out', () async {
      when(mockSecureStorage.read(key: 'id_user')).thenAnswer((_) async => '7');

      final result = await authController.logout();

      expect(result, true);
      expect(clearedInboxes, <int?>[7]);
    });

    test('logout with no stored user id still clears the (legacy) inbox', () async {
      when(mockSecureStorage.read(key: 'id_user')).thenAnswer((_) async => null);

      final result = await authController.logout();

      expect(result, true);
      expect(clearedInboxes, <int?>[null]);
    });
  });
}
