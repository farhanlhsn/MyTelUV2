import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/common/error_retry_view.dart';

void main() {
  testWidgets('shows the error text and a Coba Lagi button that retries', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorRetryView(
            message: 'Tidak dapat terhubung ke server.',
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text('Tidak dapat terhubung ke server.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    await tester.tap(find.text('Coba Lagi'));
    expect(retries, 1);
  });
}
