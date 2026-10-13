import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/common/typed_confirm_dialog.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showTypedConfirmDialog(
                  context,
                  title: 'Hapus SEMUA Kelas',
                  message: 'Tindakan ini tidak dapat dibatalkan.',
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  ElevatedButton confirmButton(WidgetTester tester) {
    return tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'HAPUS SEMUA'),
    );
  }

  testWidgets('the confirm button is disabled until HAPUS is typed exactly', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Hapus SEMUA Kelas'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'hapus');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'HAPUS SEMUA');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'HAPUS');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('typing HAPUS and confirming resolves true', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showTypedConfirmDialog(
                  context,
                  title: 'Hapus',
                  message: 'Yakin?',
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'HAPUS');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'HAPUS SEMUA'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('cancelling resolves false and never confirms', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showTypedConfirmDialog(
                  context,
                  title: 'Hapus',
                  message: 'Yakin?',
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BATAL'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
