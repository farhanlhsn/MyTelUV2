import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'routes.dart';
import '../utils/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'MyTelU',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      getPages: AppRoutes.pages,
      initialRoute: AppRoutes.splash,
    );
  }
}
