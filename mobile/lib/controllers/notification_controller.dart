import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/notification_inbox.dart';

/// The notification inbox of the logged-in user (see [NotificationInbox]: one inbox per user).
class NotificationController extends GetxController {
  final RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool isLoading = false.obs;

  /// Who is logged in. Read on every load, so a new login on the same phone gets their own inbox.
  final Future<int?> Function() _userIdProvider;

  NotificationController({Future<int?> Function()? userIdProvider})
      : _userIdProvider = userIdProvider ?? NotificationInbox.currentUserId;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await NotificationInbox.removeLegacy(prefs);

      final int? idUser = await _userIdProvider();
      if (idUser == null) {
        reset();
        return;
      }

      // Stored oldest first, shown newest first
      final List<Map<String, dynamic>> stored = NotificationInbox.read(prefs, idUser);
      notifications.value = stored.reversed.toList();
      unreadCount.value = NotificationInbox.unreadCount(
        stored,
        NotificationInbox.lastRead(prefs, idUser),
      );
    } catch (e) {
      // ignore
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final int? idUser = await _userIdProvider();
      if (idUser != null) {
        final prefs = await SharedPreferences.getInstance();
        await NotificationInbox.markRead(prefs, idUser, DateTime.now());
      }
      unreadCount.value = 0;
    } catch (e) {
      // ignore
    }
  }

  Future<void> clearAll() async {
    try {
      final int? idUser = await _userIdProvider();
      if (idUser != null) {
        final prefs = await SharedPreferences.getInstance();
        await NotificationInbox.clearFor(prefs, idUser);
      }
      reset();
    } catch (e) {
      // ignore
    }
  }

  Future<void> deleteNotification(Map<String, dynamic> notif) async {
    try {
      final int? idUser = await _userIdProvider();
      if (idUser == null) return;
      final prefs = await SharedPreferences.getInstance();

      notifications.removeWhere((n) =>
        (n['id'] != null && n['id'] == notif['id']) ||
        (n['timestamp'] == notif['timestamp'])
      );

      final chronological = notifications.reversed.toList();
      await NotificationInbox.write(prefs, idUser, chronological);

      unreadCount.value = NotificationInbox.unreadCount(
        chronological,
        NotificationInbox.lastRead(prefs, idUser),
      );
    } catch (e) {
      // ignore
    }
  }

  /// Empties what is shown (logout); the stored inbox is left to [NotificationInbox.clear].
  void reset() {
    notifications.clear();
    unreadCount.value = 0;
  }
}
