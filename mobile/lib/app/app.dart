import 'package:flutter/material.dart';
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
      getPages: AppRoutes.pages,
      initialRoute: AppRoutes.splash,
    );
  }
}
