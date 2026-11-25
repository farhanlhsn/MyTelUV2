import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile/controllers/auth_controller.dart';
import 'package:mobile/controllers/home_controller.dart';
import 'package:mobile/utils/user_scoped_controllers.dart';

import 'support/user_scoped_controllers.dart';

void main() {
  tearDown(Get.reset);

  test('deletes every controller that holds user data', () async {
    putUserScopedControllers();
    expect(registeredUserScopedControllers(), hasLength(4), reason: 'precondition');

    await deleteUserScopedControllers();

    expect(registeredUserScopedControllers(), isEmpty);
  });

  test('a user who logs in next gets a fresh controller, not the previous one', () async {
    final HomeController previous = Get.put<HomeController>(QuietHomeController());
    previous.kehadiranPercentage.value = 87.5;

    await deleteUserScopedControllers();
    final HomeController next = Get.put<HomeController>(QuietHomeController());

    expect(next, isNot(same(previous)));
    expect(next.kehadiranPercentage.value, isNull);
  });

  test('does nothing when none is registered', () async {
    await expectLater(deleteUserScopedControllers(), completes);
  });

  test('one controller that breaks on close does not keep the others', () async {
    putUserScopedControllers();
    await Get.delete<HomeController>(force: true);
    Get.put<HomeController>(BrokenOnCloseHomeController());

    await expectLater(deleteUserScopedControllers(), completes);

    // the broken one may stay behind; every other was deleted
    expect(
      registeredUserScopedControllers().where((String n) => n != 'HomeController'),
      isEmpty,
    );
  });

  test('the auth controller is not user data: the login page still needs it', () async {
    Get.put<AuthController>(AuthController());
    putUserScopedControllers();

    await deleteUserScopedControllers();

    expect(Get.isRegistered<AuthController>(), isTrue);
  });
}
