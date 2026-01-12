import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message: ${message.notification?.title}');
  await NotificationService.saveNotification(message);
}

/// Service to handle Firebase Cloud Messaging for push notifications
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _fcmToken;

  /// Initialize notification service
  /// Call this after Firebase.initializeApp()
  static Future<void> initialize() async {
    try {
      // Request permission for notifications
      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('🔔 Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        _fcmToken = await _messaging.getToken();
        debugPrint('📱 FCM Token: $_fcmToken');

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((String newToken) {
          debugPrint('🔄 FCM Token refreshed: $newToken');
          _fcmToken = newToken;
          // Re-register with backend if logged in
          _registerTokenWithBackend(newToken);
        });

        // Setup message handlers
        _setupMessageHandlers();
      }
    } catch (e) {
      debugPrint('❌ NotificationService init error: $e');
    }
  }

  /// Get current FCM token
  static String? get token => _fcmToken;

  /// Setup foreground and background message handlers
  static void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 Foreground message received:');
      debugPrint('   Title: ${message.notification?.title}');
      debugPrint('   Body: ${message.notification?.body}');
      debugPrint('   Data: ${message.data}');

      // Save notification locally
      saveNotification(message);

      // Show snackbar
      if (message.notification != null) {
        Get.snackbar(
          message.notification!.title ?? 'Notifikasi',
          message.notification!.body ?? '',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
          onTap: (_) {
            // Handle tap
          },
        );
      }
      
      _handleParkingNotification(message);
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Notification tapped (from background):');
      debugPrint('   Data: ${message.data}');
      saveNotification(message); // Ensure saved if opened
    });
  }

  /// Save notification to SharedPreferences
  static Future<void> saveNotification(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingData = prefs.getString('local_notifications');
      List<dynamic> notifications = [];
      
      if (existingData != null) {
        notifications = jsonDecode(existingData);
      }

      final newNotification = {
        'id': message.messageId,
        'title': message.notification?.title ?? 'Notifikasi Baru',
        'body': message.notification?.body ?? '',
        'data': message.data,
        'timestamp': DateTime.now().toIso8601String(),
        'type': message.data['type'] ?? 'general',
      };

      notifications.add(newNotification);
      
      // Limit to last 50 notifications
      if (notifications.length > 50) {
        notifications = notifications.sublist(notifications.length - 50);
      }

      await prefs.setString('local_notifications', jsonEncode(notifications));
      debugPrint('✅ Notification saved locally');
    } catch (e) {
      debugPrint('❌ Failed to save notification locally: $e');
    }
  }

  /// Handle parking notification data
  static void _handleParkingNotification(RemoteMessage message) {
    final String? type = message.data['type'];
    if (type == 'PARKING_NOTIFICATION') {
      final String parkingType = message.data['parking_type'] ?? '';
      final String platNomor = message.data['plat_nomor'] ?? '';
      final String parkiranName = message.data['parkiran_name'] ?? '';

      debugPrint('🚗 Parking notification: $parkingType - $platNomor at $parkiranName');
    }
  }

  /// Register FCM token with backend
  static Future<void> _registerTokenWithBackend(String token) async {
    try {
      await ApiClient.dio.post<dynamic>(
        '/api/auth/fcm-token',
        data: <String, String>{'fcm_token': token},
      );
      debugPrint('✅ FCM token registered with backend');
    } catch (e) {
      debugPrint('❌ Failed to register FCM token: $e');
    }
  }

  /// Register current token with backend (call after login)
  static Future<void> registerToken() async {
    if (_fcmToken != null) {
      await _registerTokenWithBackend(_fcmToken!);
    } else {
      // Try to get token again
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        await _registerTokenWithBackend(_fcmToken!);
      }
    }
  }

  /// Unregister token (call on logout)
  static Future<void> unregisterToken() async {
    try {
      // Clear token on backend by sending empty/null
      await ApiClient.dio.post<dynamic>(
        '/api/auth/fcm-token',
        data: <String, String?>{'fcm_token': null},
      );
      debugPrint('✅ FCM token unregistered');
    } catch (e) {
      debugPrint('❌ Failed to unregister FCM token: $e');
    }
  }
}
