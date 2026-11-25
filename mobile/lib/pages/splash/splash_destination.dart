import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/auth_middleware.dart';
import '../../app/routes.dart';
import '../../utils/notification_router.dart';

/// Where the splash sends the user: [AppRoutes.home] for a valid session, otherwise
/// [AppRoutes.login] with the stored session and any pending notification cleared.
/// Never throws: a session that cannot be read is no session.
Future<String> resolveSplashDestination({
  FlutterSecureStorage storage = const FlutterSecureStorage(),
}) async {
  try {
    await AuthMiddleware.loadCredentials(storage: storage);
    if (AuthMiddleware.isTokenValid) return AppRoutes.home;
  } catch (_) {
    // Unreadable storage: treated like a missing session below
  }
  NotificationNavigator.clearPending();
  AuthMiddleware.clearCredentials();
  return AppRoutes.login;
}
