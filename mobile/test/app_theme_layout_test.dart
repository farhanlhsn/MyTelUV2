import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/common/confirm_dialog.dart';
import 'package:mobile/pages/kendaraan/historyPengajuan/userhistoripengajuan.dart';
import 'package:mobile/utils/app_theme.dart';

/// Layouts under the real app theme. The other widget tests pump a bare MaterialApp, which is how
/// a theme-wide full-width button went unnoticed: it blanked every card with a button in a Row and
/// stacked the buttons of every dialog.
Widget _themed(Widget child) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  test('a themed ElevatedButton is as wide as its label, not infinitely wide', () {
    final Size? minimum = AppTheme.light.elevatedButtonTheme.style?.minimumSize?.resolve(
      <WidgetState>{},
    );
    expect(minimum, isNotNull);
    expect(minimum!.width.isFinite, isTrue);
    expect(minimum.height, AppTheme.buttonHeight);
  });

  testWidgets('a submission card with its DETAIL button lays out and shows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themed(
        ListView(
          children: <Widget>[
            VehicleStatusCard(
              title: 'Honda Vario',
              licensePlate: 'B 1234 XYZ',
              status: 'Disetujui',
              statusColor: Colors.green,
              onCheckPressed: () {},
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Honda Vario'), findsOneWidget);
    expect(find.text('DETAIL'), findsOneWidget);
    expect(tester.getSize(find.widgetWithText(ElevatedButton, 'DETAIL')).width, lessThan(200));
  });

  testWidgets('the confirm dialog puts cancel and confirm side by side', (
    WidgetTester tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      _themed(
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              result = await showAppConfirmDialog(
                context,
                title: 'Konfirmasi Keluar',
                message: 'Apakah Anda yakin ingin keluar dari aplikasi?',
                confirmLabel: 'Ya, Keluar',
                icon: Icons.logout,
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    final Offset cancel = tester.getCenter(find.text('Batal'));
    final Offset confirm = tester.getCenter(find.text('Ya, Keluar'));
    expect(cancel.dy, confirm.dy);
    expect(cancel.dx, lessThan(confirm.dx));

    await tester.tap(find.text('Ya, Keluar'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
