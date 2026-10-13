import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'routes.dart';
import '../utils/app_theme.dart';
import '../utils/error_helper.dart';

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
      getPages: AppRoutes.pages,
      initialRoute: AppRoutes.splash,
    );
  }
}
