import 'package:get/get.dart';

import '../controllers/account_controller.dart';
import '../controllers/anomali_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/notification_controller.dart';
import 'logger.dart';

/// Deletes the GetX controllers that hold the logged-in user's data (their Home numbers and classes,
/// inbox, anomaly scan, profile and password fields).
///
/// GetX keeps a registered controller alive after the user is gone, and `Get.put` of one that is
/// already registered hands back the old instance without loading anything again. So whoever logs in
/// next on the same phone would see the previous user's data (their attendance percentage on Home,
/// for one) until it happened to be reloaded. Called when the user logs out and when the session is
/// ended by the server. The auth controller is not here: it holds no user data, and the login page
/// needs it.
Future<void> deleteUserScopedControllers() async {
  await _delete<HomeController>();
  await _delete<NotificationController>();
  await _delete<AnomaliController>();
  await _delete<AccountController>();
}

// Each controller on its own: one that breaks on close must not keep the others (GetX reports it
// through the Future of delete)
Future<void> _delete<T extends GetxController>() async {
  try {
    if (Get.isRegistered<T>()) await Get.delete<T>(force: true);
  } catch (e) {
    debugLog('Failed to delete the controller $T of the ended session: $e');
  }
}
