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

  testWidgets('without onRetry there is no Coba Lagi button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ErrorRetryView(
            title: 'Postingan tidak tersedia',
            message: 'Postingan tidak ditemukan atau sudah dihapus.',
          ),
        ),
      ),
    );

    expect(find.text('Postingan tidak tersedia'), findsOneWidget);
    expect(find.text('Postingan tidak ditemukan atau sudah dihapus.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}
