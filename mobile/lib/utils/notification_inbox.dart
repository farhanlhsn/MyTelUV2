import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger.dart';

/// The local notification inbox (push messages kept on the phone), one per user.
///
/// It lives in SharedPreferences under `notifications_<id_user>` (oldest entry first) with its own
/// read marker, so two accounts on the same phone never see each other's notifications. The old
/// global key (`local_notifications`) is dropped: whose notifications it held is unknown.
class NotificationInbox {
  NotificationInbox._();

  static const String legacyNotificationsKey = 'local_notifications';
  static const String legacyLastReadKey = 'last_read_timestamp';
  static const int maxEntries = 50;

  static String notificationsKey(int idUser) => 'notifications_$idUser';
  static String lastReadKey(int idUser) => 'notifications_last_read_$idUser';

  /// The id of the logged-in user (`id_user` in the secure storage), or null when nobody is logged
  /// in or the storage cannot be read.
  static Future<int?> currentUserId({FlutterSecureStorage? storage}) async {
    try {
      final String? raw = await (storage ?? const FlutterSecureStorage()).read(key: 'id_user');
      final int? id = int.tryParse(raw ?? '');
      return id != null && id > 0 ? id : null;
    } catch (e) {
      debugLog('Cannot read the current user id: $e');
      return null;
    }
  }

  /// Deletes the pre-per-user global inbox and its read marker.
  static Future<void> removeLegacy(SharedPreferences prefs) async {
    if (prefs.containsKey(legacyNotificationsKey)) {
      await prefs.remove(legacyNotificationsKey);
    }
    if (prefs.containsKey(legacyLastReadKey)) {
      await prefs.remove(legacyLastReadKey);
    }
  }

  /// The inbox of [idUser], oldest first. A missing or corrupt inbox reads as empty.
  static List<Map<String, dynamic>> read(SharedPreferences prefs, int idUser) {
    final String? raw = prefs.getString(notificationsKey(idUser));
    if (raw == null) return <Map<String, dynamic>>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Stores [entries] (oldest first) as the inbox of [idUser].
  static Future<void> write(
    SharedPreferences prefs,
    int idUser,
    List<Map<String, dynamic>> entries,
  ) async {
    await prefs.setString(notificationsKey(idUser), jsonEncode(entries));
  }

  /// Adds [entry] to the inbox of [idUser], keeping the last [maxEntries]. A message that is
  /// already there (same non-null `id`: the background handler and the opened app both save it) is
  /// not added twice.
  static Future<void> append(
    SharedPreferences prefs,
    int idUser,
    Map<String, dynamic> entry,
  ) async {
    await removeLegacy(prefs);

    List<Map<String, dynamic>> entries = read(prefs, idUser);
    final Object? id = entry['id'];
    if (id != null && entries.any((Map<String, dynamic> e) => e['id'] == id)) {
      return;
    }

    entries.add(entry);
    if (entries.length > maxEntries) {
      entries = entries.sublist(entries.length - maxEntries);
    }
    await write(prefs, idUser, entries);
  }

  /// When [idUser] last opened the inbox, or null if never.
  static DateTime? lastRead(SharedPreferences prefs, int idUser) {
    final String? raw = prefs.getString(lastReadKey(idUser));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<void> markRead(SharedPreferences prefs, int idUser, DateTime at) async {
    await prefs.setString(lastReadKey(idUser), at.toIso8601String());
  }

  /// How many [entries] are newer than [lastRead] (all of them if the inbox was never opened). An
  /// entry without a readable timestamp is not counted as unread.
  static int unreadCount(List<Map<String, dynamic>> entries, DateTime? lastRead) {
    if (lastRead == null) return entries.length;
    return entries.where((Map<String, dynamic> n) {
      final Object? raw = n['timestamp'];
      final DateTime? at = raw is String ? DateTime.tryParse(raw) : null;
      return at != null && at.isAfter(lastRead);
    }).length;
  }

  /// Removes the inbox and read marker of [idUser], and the legacy global inbox.
  static Future<void> clearFor(SharedPreferences prefs, int idUser) async {
    await prefs.remove(notificationsKey(idUser));
    await prefs.remove(lastReadKey(idUser));
    await removeLegacy(prefs);
  }

  /// Logout: removes the inbox of [idUser] (when known) and the legacy global inbox. Never throws.
  static Future<void> clear(int? idUser) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (idUser == null) {
        await removeLegacy(prefs);
      } else {
        await clearFor(prefs, idUser);
      }
    } catch (e) {
      debugLog('Failed to clear the notification inbox: $e');
    }
  }
}
