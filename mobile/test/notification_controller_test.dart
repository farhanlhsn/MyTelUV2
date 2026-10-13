import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/controllers/notification_controller.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationController controller;
  int? currentUser;

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
    currentUser = 7;
    SharedPreferences.setMockInitialValues({
      // the inbox of user 7 and its read marker
      'notifications_7': jsonEncode(testNotifications),
      'notifications_last_read_7': '2026-06-19T10:15:00.000Z',
      // another user's inbox on the same phone
      'notifications_8': jsonEncode([
        {
          'id': 'other',
          'title': 'Punya orang lain',
          'body': '',
          'type': 'SOCIAL_NOTIFICATION',
          'timestamp': '2026-06-19T12:00:00.000Z'
        }
      ]),
      // the old global inbox (every user used to share it)
      'local_notifications': jsonEncode([
        {
          'id': 'legacy',
          'title': 'Lama',
          'body': '',
          'type': 'ABSENSI_NOTIFICATION',
          'timestamp': '2026-06-19T09:00:00.000Z'
        }
      ]),
      'last_read_timestamp': '2026-06-19T08:00:00.000Z',
    });

    Get.reset();
    controller = Get.put(NotificationController(userIdProvider: () async => currentUser));
    // onInit starts the first load: wait for it
    await controller.loadNotifications();
  });

  tearDown(() => Get.reset());

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

    test('marking as read is remembered for that user only', () async {
      await controller.markAllAsRead();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('notifications_last_read_7'), isTrue);
      expect(prefs.containsKey('notifications_last_read_8'), isFalse);
      expect(prefs.getString('notifications_last_read_7'), isNot('2026-06-19T10:15:00.000Z'));
    });

    test('should delete single notification and adjust lists/unread counts', () async {
      final notifToDelete = controller.notifications[0];
      await controller.deleteNotification(notifToDelete);

      expect(controller.notifications.length, 2);
      expect(controller.notifications.any((n) => n['id'] == '3'), false);
      expect(controller.unreadCount.value, 1);

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString('notifications_7')!) as List<dynamic>;
      expect(stored.map((n) => (n as Map<String, dynamic>)['id']), ['1', '2']);
    });

    test('should clear all notifications', () async {
      await controller.clearAll();
      expect(controller.notifications.isEmpty, true);
      expect(controller.unreadCount.value, 0);
    });

    test('clearing removes this user\'s inbox only', () async {
      await controller.clearAll();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('notifications_7'), isFalse);
      expect(prefs.containsKey('notifications_8'), isTrue);
    });
  });

  group('per-user inbox', () {
    test('never shows the old global inbox or another user\'s notifications', () {
      final ids = controller.notifications.map((n) => n['id']).toList();
      expect(ids, ['3', '2', '1']);
      expect(ids, isNot(contains('legacy')));
      expect(ids, isNot(contains('other')));
    });

    test('the old global inbox is deleted on first load', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('local_notifications'), isFalse);
      expect(prefs.containsKey('last_read_timestamp'), isFalse);
    });

    test('the next user logging in on the same phone gets their own inbox', () async {
      currentUser = 8;
      await controller.loadNotifications();

      expect(controller.notifications.map((n) => n['id']), ['other']);
      expect(controller.unreadCount.value, 1);
    });

    test('nobody logged in: an empty inbox', () async {
      currentUser = null;
      await controller.loadNotifications();

      expect(controller.notifications, isEmpty);
      expect(controller.unreadCount.value, 0);
    });

    test('reset empties what is shown (logout) without touching the stored inbox', () async {
      controller.reset();

      expect(controller.notifications, isEmpty);
      expect(controller.unreadCount.value, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('notifications_7'), isTrue);
    });
  });
}
