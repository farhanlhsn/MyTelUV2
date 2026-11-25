import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'app/app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Indonesian is the app's only locale: dates, numbers and the like format as id_ID by default
  Intl.defaultLocale = 'id_ID';
  await initializeDateFormatting('id_ID', null);
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize notification service
  await NotificationService.initialize();
  
  runApp(const MyApp());
}
