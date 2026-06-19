import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationController extends GetxController {
  final RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notificationsString = prefs.getString('local_notifications');
      
      if (notificationsString != null) {
        final List<dynamic> decoded = jsonDecode(notificationsString);
        notifications.value = List<Map<String, dynamic>>.from(decoded).reversed.toList();
      } else {
        notifications.clear();
      }

      // Check unread count based on last read timestamp
      final String? lastReadStr = prefs.getString('last_read_timestamp');
      if (lastReadStr == null) {
        unreadCount.value = notifications.length;
      } else {
        final lastRead = DateTime.parse(lastReadStr);
        unreadCount.value = notifications.where((n) {
          final timestampStr = n['timestamp'];
          if (timestampStr == null) return false;
          final timestamp = DateTime.parse(timestampStr);
          return timestamp.isAfter(lastRead);
        }).length;
      }
    } catch (e) {
      // ignore
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_read_timestamp', DateTime.now().toIso8601String());
      unreadCount.value = 0;
    } catch (e) {
      // ignore
    }
  }

  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('local_notifications');
      notifications.clear();
      unreadCount.value = 0;
    } catch (e) {
      // ignore
    }
  }

  Future<void> deleteNotification(Map<String, dynamic> notif) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      notifications.removeWhere((n) => 
        (n['id'] != null && n['id'] == notif['id']) || 
        (n['timestamp'] == notif['timestamp'])
      );

      final chronological = notifications.reversed.toList();
      await prefs.setString('local_notifications', jsonEncode(chronological));
      
      final String? lastReadStr = prefs.getString('last_read_timestamp');
      if (lastReadStr != null) {
        final lastRead = DateTime.parse(lastReadStr);
        unreadCount.value = notifications.where((n) {
          final timestampStr = n['timestamp'];
          if (timestampStr == null) return false;
          final timestamp = DateTime.parse(timestampStr);
          return timestamp.isAfter(lastRead);
        }).length;
      } else {
        unreadCount.value = notifications.length;
      }
    } catch (e) {
      // ignore
    }
  }
}
