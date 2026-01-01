import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message: ${message.notification?.title}');
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

      // You can show a local notification or snackbar here
      _handleParkingNotification(message);
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Notification tapped (from background):');
      debugPrint('   Data: ${message.data}');
      // Navigate to parking history or relevant page
    });
  }

  /// Handle parking notification data
  static void _handleParkingNotification(RemoteMessage message) {
    final String? type = message.data['type'];
    if (type == 'PARKING_NOTIFICATION') {
      final String parkingType = message.data['parking_type'] ?? '';
      final String platNomor = message.data['plat_nomor'] ?? '';
      final String parkiranName = message.data['parkiran_name'] ?? '';

      debugPrint('🚗 Parking notification: $parkingType - $platNomor at $parkiranName');
      // Could show a snackbar or update UI here using GetX
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
