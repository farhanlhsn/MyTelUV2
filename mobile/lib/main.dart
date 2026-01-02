import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize date formatting for Indonesian locale
  await initializeDateFormatting('id_ID', null);
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize notification service
  await NotificationService.initialize();
  
  runApp(const MyApp());
}
