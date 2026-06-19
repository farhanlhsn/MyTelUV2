import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/controllers/notification_controller.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationController controller;

  final testNotifications = [
    {
      'id': '1',
      'title': 'Sesi Absensi Dibuka!',
      'body': 'Absensi kelas IF-45-01 dibuka.',
      'type': 'ABSENSI_NOTIFICATION',
      'timestamp': '2026-06-19T10:00:00.000Z'
    },
    {
      'id': '2',
      'title': 'Kendaraan Masuk',
      'body': 'D 1234 ABC masuk area parkir.',
      'type': 'PARKING_NOTIFICATION',
      'timestamp': '2026-06-19T10:30:00.000Z'
    },
    {
      'id': '3',
      'title': 'Post Baru disukai',
      'body': 'User menyukai post Anda.',
      'type': 'SOCIAL_NOTIFICATION',
      'timestamp': '2026-06-19T11:00:00.000Z'
    }
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'local_notifications': jsonEncode(testNotifications),
      'last_read_timestamp': '2026-06-19T10:15:00.000Z'
    });

    if (Get.isRegistered<NotificationController>()) {
      controller = Get.find<NotificationController>();
      await controller.loadNotifications();
    } else {
      controller = Get.put(NotificationController());
    }
  });

  group('NotificationController tests', () {
    test('should load notifications in reverse order (newest first)', () {
      expect(controller.notifications.length, 3);
      expect(controller.notifications[0]['id'], '3');
      expect(controller.notifications[2]['id'], '1');
    });

    test('should calculate unreadCount correctly based on last read timestamp', () {
      expect(controller.unreadCount.value, 2);
    });

    test('should mark all notifications as read', () async {
      await controller.markAllAsRead();
      expect(controller.unreadCount.value, 0);
    });

    test('should delete single notification and adjust lists/unread counts', () async {
      final notifToDelete = controller.notifications[0];
      await controller.deleteNotification(notifToDelete);

      expect(controller.notifications.length, 2);
      expect(controller.notifications.any((n) => n['id'] == '3'), false);
      expect(controller.unreadCount.value, 1);
    });

    test('should clear all notifications', () async {
      await controller.clearAll();
      expect(controller.notifications.isEmpty, true);
      expect(controller.unreadCount.value, 0);
    });
  });
}
