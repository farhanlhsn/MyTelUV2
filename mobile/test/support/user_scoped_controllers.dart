import 'package:get/get.dart';
import 'package:mobile/controllers/account_controller.dart';
import 'package:mobile/controllers/anomali_controller.dart';
import 'package:mobile/controllers/home_controller.dart';
import 'package:mobile/controllers/notification_controller.dart';

/// The real controllers hold the logged-in user's data and load it from the network or the storage
/// as soon as they are created; these start quiet so a test can register them without any of that.
class QuietHomeController extends HomeController {
  @override
  // ignore: must_call_super (the real onInit is what loads the data)
  void onInit() {}
}

class QuietAccountController extends AccountController {
  @override
  // ignore: must_call_super (the real onInit is what loads the data)
  void onInit() {}
}

class QuietNotificationController extends NotificationController {
  QuietNotificationController() : super(userIdProvider: () async => null);

  @override
  // ignore: must_call_super (the real onInit is what loads the data)
  void onInit() {}
}

/// A Home that breaks the first time it is deleted (and stays registered then), and lets go the
/// second time, so the cleanup of the test itself (`Get.reset`) can remove it.
class BrokenOnCloseHomeController extends QuietHomeController {
  bool _broke = false;

  @override
  void onClose() {
    if (!_broke) {
      _broke = true;
      throw StateError('home sudah tidak ada');
    }
    super.onClose();
  }
}

/// One of each controller that holds the user's data, registered the way the pages register them.
void putUserScopedControllers() {
  Get.put<HomeController>(QuietHomeController());
  Get.put<NotificationController>(QuietNotificationController());
  Get.put<AnomaliController>(AnomaliController());
  Get.put<AccountController>(QuietAccountController());
}

/// Names of the user-scoped controllers that are still registered.
List<String> registeredUserScopedControllers() => <String>[
  if (Get.isRegistered<HomeController>()) 'HomeController',
  if (Get.isRegistered<NotificationController>()) 'NotificationController',
  if (Get.isRegistered<AnomaliController>()) 'AnomaliController',
  if (Get.isRegistered<AccountController>()) 'AccountController',
];
