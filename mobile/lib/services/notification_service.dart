import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/controllers/notification_controller.dart';
import '../utils/error_helper.dart';
import '../utils/logger.dart';
import '../utils/notification_inbox.dart';
import '../utils/notification_router.dart';
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
        await _setupMessageHandlers();
      }
    } catch (e) {
      debugLog('NotificationService init error: $e');
    }
  }

  /// Get current FCM token
  static String? get token => _fcmToken;

  /// Setup foreground and background message handlers
  static Future<void> _setupMessageHandlers() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugLog('Foreground message: ${message.notification?.title}');
      debugLog('Data type: ${message.data['type']}');

      // Save notification locally
      saveNotification(message);

      // Show the banner (a tap opens the page of the notification)
      if (message.notification != null) {
        ErrorHelper.showToast(
          message.notification!.title ?? 'Notifikasi',
          message.notification!.body ?? '',
          icon: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset(
              'assets/images/telyu.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          duration: const Duration(seconds: 4),
          onTap: () => openNotification(message.data),
        );
      }

      _handleParkingNotification(message);
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification tap when app is in background: the app is running, so open the page now
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugLog('Notification tapped (from background), type: ${message.data['type']}');
      saveNotification(message); // Ensure saved if opened
      openNotification(message.data);
    });

    await _captureLaunchNotification();
  }

  /// Cold start: the notification the user tapped to launch the app. The app is not ready yet (no
  /// GetMaterialApp, session not checked), so it is only remembered; the splash page opens it once
  /// the user is on the home page (see [NotificationNavigator.openPending]).
  static Future<void> _captureLaunchNotification() async {
    try {
      final RemoteMessage? initial = await _messaging.getInitialMessage();
      if (initial == null) return;
      debugLog('App launched from a notification, type: ${initial.data['type']}');
      saveNotification(initial); // Deduplicated by message id if the background handler saved it
      NotificationNavigator.setPending(initial.data);
    } catch (e) {
      debugLog('getInitialMessage error: $e');
    }
  }

  /// Save notification to the inbox of the logged-in user (SharedPreferences, `notifications_<id>`)
  static Future<void> saveNotification(RemoteMessage message) async {
    try {
      final int? idUser = await NotificationInbox.currentUserId();
      if (idUser == null) {
        // Nobody is logged in: there is no inbox this message could belong to
        debugLog('Notification not saved locally: no logged-in user');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final newNotification = <String, dynamic>{
        'id': message.messageId,
        'title': message.notification?.title ?? 'Notifikasi Baru',
        'body': message.notification?.body ?? '',
        'data': message.data,
        'timestamp': DateTime.now().toIso8601String(),
        'type': message.data['type'] ?? 'general',
      };

      await NotificationInbox.append(prefs, idUser, newNotification);
      debugLog('Notification saved locally');

      if (Get.isRegistered<NotificationController>()) {
        Get.find<NotificationController>().loadNotifications();
      }
    } catch (e) {
      debugPrint('❌ Failed to save notification locally: $e');
    }
  }

  /// Logout: removes the local inbox of [idUser] and empties the one on screen.
  static Future<void> clearInbox(int? idUser) async {
    await NotificationInbox.clear(idUser);
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().reset();
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
