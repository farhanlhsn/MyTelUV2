import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/biometrik/biometrik_status_page.dart';
import 'package:mobile/pages/biometrik/biometrik_status_widget.dart';

void main() {
  testWidgets(
    'the student Biometrik page shows the status, not a dead-end action',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BiometrikStatusPage()));

      expect(find.byType(BiometrikStatusWidget), findsOneWidget);
      expect(find.text('Data Biometrik'), findsOneWidget);
      // no "Daftar"/"Verifikasi" button: verifying needs an attendance session
      expect(find.text('Daftar'), findsNothing);
      expect(find.text('Verifikasi'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'does not claim a face is (not) registered when that is unknown',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BiometrikStatusWidget(showAction: false)),
        ),
      );

      expect(find.text('Wajah sudah terdaftar'), findsNothing);
      expect(find.text('Wajah belum terdaftar'), findsNothing);
    },
  );

  testWidgets('shows the registration state when it is known', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BiometrikStatusWidget(isRegistered: true, showAction: false),
        ),
      ),
    );
    expect(find.text('Wajah sudah terdaftar'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BiometrikStatusWidget(isRegistered: false, showAction: false),
        ),
      ),
    );
    expect(find.text('Wajah belum terdaftar'), findsOneWidget);
  });
}
