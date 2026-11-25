import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'routes.dart';
import '../utils/app_theme.dart';
import '../utils/error_helper.dart';

/// The whole app is Indonesian: date pickers, dialogs, tooltips and the like follow it.
const Locale appLocale = Locale('id', 'ID');

const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'MyTelU',
      debugShowCheckedModeBanner: false,
      // The toasts of ErrorHelper are shown through this messenger
      scaffoldMessengerKey: ErrorHelper.scaffoldMessengerKey,
      theme: AppTheme.light,
      locale: appLocale,
      supportedLocales: const <Locale>[appLocale],
      localizationsDelegates: appLocalizationsDelegates,
      // Most pages sit under a red header: light status bar icons unless a page says otherwise
      // (the white tabs of HomePage, an AppBar through its systemOverlayStyle).
      builder: (BuildContext context, Widget? child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: statusBarOnRed,
        child: child ?? const SizedBox.shrink(),
      ),
      getPages: AppRoutes.pages,
      initialRoute: AppRoutes.splash,
    );
  }
}
