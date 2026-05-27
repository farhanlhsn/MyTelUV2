import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/main.dart' as app;

void main() {
  // Ensure the integration test binding is fully initialized
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MyTelU V2 Flutter End-to-End Test Suite', () {
    testWidgets('Verify complete student login, home navigation, and geofence verification flow', (WidgetTester tester) async {
      // 1. Boot up application
      app.main();
      await tester.pumpAndSettle();

      // Verify splash screen redirection effect
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 2. Login Flow
      // Locates input fields by element types
      final Finder usernameField = find.byType(TextField).first;
      final Finder passwordField = find.byType(TextField).last;
      final Finder loginButton = find.byType(ElevatedButton).first;

      expect(usernameField, findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(loginButton, findsOneWidget);

      // Enter deterministic test user credentials
      await tester.enterText(usernameField, 'mhs_test');
      await tester.enterText(passwordField, 'password123');
      await tester.tap(loginButton);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 3. Home View & Grid Navigation
      // Verify successful login navigation to HomePage grid menu items
      expect(find.text('Lisence Plate'), findsOneWidget);
      expect(find.text('Absence'), findsOneWidget);
      expect(find.text('Biometric'), findsOneWidget);

      // Tap Biometric Absen grid menu to trigger Camera geofence page
      final Finder biometricGridItem = find.text('Biometric');
      await tester.tap(biometricGridItem);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we successfully guarded and loaded the Biometric Absen Page
      expect(find.text('Absen Biometrik'), findsOneWidget);

      // Tap back button to return to home
      final Finder backButton = find.byIcon(Icons.arrow_back_ios);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // 4. Logout Flow
      // Tap on top profile avatar to view details
      final Finder profileAvatar = find.byType(CircleAvatar).first;
      await tester.tap(profileAvatar);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Scroll to logout button if hidden, then tap
      final Finder logoutBtn = find.byIcon(Icons.logout);
      if (logoutBtn.evaluate().isNotEmpty) {
        await tester.tap(logoutBtn);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        
        // Assert redirected back to Login screen successfully
        expect(find.text('LOGIN'), findsOneWidget);
      }
    });
  });
}
