import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/controllers/notification_controller.dart';
import '../utils/logger.dart';
import 'api_client.dart';

String _maskToken(String token) => '${token.substring(0, 8)}...${token.substring(token.length - 8)}';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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

      debugLog('Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        _fcmToken = await _messaging.getToken();
        if (_fcmToken != null && kDebugMode) {
          debugLog('FCM Token: ${_maskToken(_fcmToken!)}');
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((String newToken) {
          debugLog('FCM Token refreshed: ${_maskToken(newToken)}');
          _fcmToken = newToken;
          // Re-register with backend if logged in
          _registerTokenWithBackend(newToken);
        });

        // Setup message handlers
        _setupMessageHandlers();
      }
    } catch (e) {
      debugLog('NotificationService init error: $e');
    }
  }

  /// Get current FCM token
  static String? get token => _fcmToken;

  /// Setup foreground and background message handlers
  static void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugLog('Foreground message: ${message.notification?.title}');
      debugLog('Data type: ${message.data['type']}');

      // Save notification locally
      saveNotification(message);

      // Show snackbar
      if (message.notification != null) {
        Get.snackbar(
          message.notification!.title ?? 'Notifikasi',
          message.notification!.body ?? '',
          icon: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset(
                'assets/images/telyu.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
          ),
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
      debugLog('Notification tapped (from background), type: ${message.data['type']}');
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
      debugLog('Notification saved locally');
      
      if (Get.isRegistered<NotificationController>()) {
        Get.find<NotificationController>().loadNotifications();
      }
    } catch (e) {
      debugPrint('❌ Failed to save notification locally: $e');
    }
  }

  /// Handle parking notification data
  static void _handleParkingNotification(RemoteMessage message) {
    final String? type = message.data['type'];
    if (type == 'PARKING_NOTIFICATION') {
      final String parkingType = message.data['parking_type'] ?? '';
      final String parkiranName = message.data['parkiran_name'] ?? '';

      debugLog('Parking notification: $parkingType at $parkiranName');
    }
  }

  /// Register FCM token with backend
  static Future<void> _registerTokenWithBackend(String token) async {
    try {
      await ApiClient.dio.post<dynamic>(
        '/api/v1/auth/fcm-token',
        data: <String, String>{'fcm_token': token},
      );
      debugLog('FCM token registered with backend');
    } catch (e) {
      debugLog('Failed to register FCM token: $e');
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
  /// Note: FCM token dibersihkan oleh backend saat POST /auth/logout.
  /// Method ini hanya membersihkan state lokal.
  static Future<void> unregisterToken() async {
    _fcmToken = null;
    debugLog('FCM token cleared locally (backend clears on /logout)');
  }
}
