import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../app/routes.dart';
import 'logger.dart';

/// FCM data `type` values sent by backend/utils/firebase.js and the controllers that call it.
class NotificationTypes {
  NotificationTypes._();

  static const String parking = 'PARKING_NOTIFICATION';
  static const String social = 'SOCIAL_NOTIFICATION';
  static const String absensi = 'ABSENSI_NOTIFICATION';
  static const String jadwalPengganti = 'JADWAL_PENGGANTI_NOTIFICATION';
  static const String kendaraanApproved = 'KENDARAAN_APPROVED';
  static const String kendaraanRejected = 'KENDARAAN_REJECTED';
  static const String kendaraanDeleted = 'KENDARAAN_DELETED';
  static const String kendaraanDeleteRejected = 'KENDARAAN_DELETE_REJECTED';

  static const Set<String> kendaraan = <String>{
    kendaraanApproved,
    kendaraanRejected,
    kendaraanDeleted,
    kendaraanDeleteRejected,
  };
}

/// The `type` of an FCM data map, or null when it is missing or not a string.
String? _typeOf(Map<String, dynamic> data) {
  final Object? type = data['type'];
  return type is String ? type : null;
}

/// A post id from FCM data: a string ("42") or, from the inbox JSON, an int. Anything that is not
/// a positive whole number is not an id.
int? _postIdOf(Map<String, dynamic> data) {
  final Object? raw = data['id_post'];
  final int? id = raw is int ? raw : (raw is String ? int.tryParse(raw.trim()) : null);
  return id != null && id > 0 ? id : null;
}

/// The page a notification opens, from its FCM `data` map. Pure: the same data always gives the
/// same route. Unknown, missing or garbage data opens the notification list.
///
/// - ABSENSI -> attendance page; JADWAL_PENGGANTI -> weekly schedule; PARKING -> parking history;
///   KENDARAAN_* -> the vehicle submission history.
/// - SOCIAL with a usable `id_post` -> the comments of that post (see [argumentsForNotification]).
String routeForNotification(Map<String, dynamic> data) {
  final String? type = _typeOf(data);

  switch (type) {
    case NotificationTypes.absensi:
      return AppRoutes.absensi;
    case NotificationTypes.jadwalPengganti:
      return AppRoutes.jadwalMingguan;
    case NotificationTypes.parking:
      return AppRoutes.historiParkir;
    case NotificationTypes.social:
      return _postIdOf(data) != null ? AppRoutes.postComments : AppRoutes.notificationList;
    default:
      if (type != null && NotificationTypes.kendaraan.contains(type)) {
        return AppRoutes.userHistoriPengajuan;
      }
      return AppRoutes.notificationList;
  }
}

/// The arguments [routeForNotification]'s route needs: only the comments page, which takes the
/// post id. Null for every other target.
Map<String, dynamic>? argumentsForNotification(Map<String, dynamic> data) {
  if (routeForNotification(data) != AppRoutes.postComments) return null;
  return <String, dynamic>{'id_post': _postIdOf(data)};
}

/// The FCM data of an inbox entry (`{id, title, body, data, timestamp, type}`), ready for
/// [routeForNotification]. An entry without usable data still has its own `type`.
Map<String, dynamic> dataOfInboxEntry(Map<String, dynamic> entry) {
  final Object? raw = entry['data'];
  final Map<String, dynamic> data = raw is Map
      ? Map<String, dynamic>.from(raw)
      : <String, dynamic>{};
  if (data['type'] == null && entry['type'] != null) {
    data['type'] = entry['type'];
  }
  return data;
}

/// The inbox filter a notification type belongs to ('Akademik', 'Kendaraan', 'Sosial'), or null
/// when it belongs to none (only shown under 'Semua').
String? notificationCategory(Object? type) {
  if (type is! String) return null;
  if (type == NotificationTypes.absensi || type == NotificationTypes.jadwalPengganti) {
    return 'Akademik';
  }
  if (type == NotificationTypes.parking || NotificationTypes.kendaraan.contains(type)) {
    return 'Kendaraan';
  }
  if (type == NotificationTypes.social) return 'Sosial';
  return null;
}

/// Opens the page of a tapped notification. Safe to call from a push tap, a foreground banner or
/// an inbox card; the routes carry the auth middleware, so a logged-out user lands on the login.
Future<void> openNotification(Map<String, dynamic> data) async {
  final String route = routeForNotification(data);
  final Map<String, dynamic>? arguments = argumentsForNotification(data);

  if (Get.currentRoute == route && arguments == null) {
    // Already on that page: the inbox stays as is, a data page is rebuilt so it shows what is new.
    if (route == AppRoutes.notificationList) return;
    await Get.offNamed<dynamic>(route);
    return;
  }
  await Get.toNamed<dynamic>(route, arguments: arguments);
}

/// The notification that started the app (cold start). Held until the app is ready (GetMaterialApp
/// built, session checked) and opened once by the splash page.
class NotificationNavigator {
  NotificationNavigator._();

  static Map<String, dynamic>? _pending;

  /// How a notification is opened; replaced in tests.
  @visibleForTesting
  static Future<void> Function(Map<String, dynamic> data) opener = openNotification;

  static bool get hasPending => _pending != null;

  static void setPending(Map<String, dynamic> data) {
    _pending = Map<String, dynamic>.from(data);
  }

  static void clearPending() {
    _pending = null;
  }

  /// Opens the pending notification, if any, exactly once. Never throws.
  static Future<void> openPending() async {
    final Map<String, dynamic>? data = _pending;
    _pending = null;
    if (data == null) return;
    try {
      await opener(data);
    } catch (e) {
      debugLog('Failed to open notification: $e');
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _pending = null;
    opener = openNotification;
  }
}
