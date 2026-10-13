import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';

void main() {
  testWidgets('the app locale is Indonesian: framework texts are in Indonesian', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: appLocale,
        supportedLocales: const <Locale>[appLocale],
        localizationsDelegates: appLocalizationsDelegates,
        home: Builder(
          builder: (BuildContext context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(appLocale, const Locale('id', 'ID'));
    expect(Localizations.localeOf(captured), const Locale('id', 'ID'));
    // The back button tooltip of an AppBar, a date picker's buttons... all come from here
    expect(MaterialLocalizations.of(captured).backButtonTooltip, 'Kembali');
    expect(MaterialLocalizations.of(captured).cancelButtonLabel, 'Batal');
  });
}
