import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mobile/controllers/auth_controller.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Generate mocks
@GenerateNiceMocks([MockSpec<AuthService>(), MockSpec<FlutterSecureStorage>()])
import 'auth_controller_test.mocks.dart';

void main() {
  late AuthController authController;
  late MockAuthService mockAuthService;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockAuthService = MockAuthService();
    mockSecureStorage = MockFlutterSecureStorage();
    
    // Inject mocks and no-op for static callbacks
    authController = AuthController(
      authService: mockAuthService,
      secureStorage: mockSecureStorage,
      registerNotificationToken: () async {},
      unregisterNotificationToken: () async {},
    );
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
          
      // Act
      final result = await authController.login(username, password);

      // Assert
      expect(result, true);
      verify(mockSecureStorage.write(key: 'token', value: 'mock_token')).called(1);
      verify(mockSecureStorage.write(key: 'username', value: 'testuser')).called(1);
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
  });
}
