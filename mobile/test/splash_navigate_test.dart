import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/pages/splash_page.dart';
import 'package:mobile/utils/notification_router.dart';

/// splashNavigate pushes the destination over the splash and removes the splash only once the
/// destination has faded in, so the fade never runs over an empty background.
void main() {
  // A long fade: longer than any fixed timer would wait
  const Duration fade = Duration(milliseconds: 1000);
  late List<String> platformCalls;

  Widget app() => GetMaterialApp(
        initialRoute: '/',
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(
            name: '/',
            page: () => const ColoredBox(color: Colors.red, child: Text('SPLASH')),
            transition: Transition.noTransition,
          ),
          GetPage<dynamic>(
            name: AppRoutes.login,
            page: () => const ColoredBox(color: Colors.white, child: Text('LOGIN')),
            transition: Transition.fadeIn,
            transitionDuration: fade,
          ),
          GetPage<dynamic>(
            name: AppRoutes.home,
            page: () => const ColoredBox(color: Colors.white, child: Text('HOME')),
            transition: Transition.fadeIn,
            transitionDuration: fade,
          ),
        ],
      );

  setUp(() {
    platformCalls = <String>[];
    NotificationNavigator.resetForTest();
  });

  tearDown(NotificationNavigator.resetForTest);

  void recordPlatformCalls(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      platformCalls.add(call.method);
      return null;
    });
  }

  final Finder splash = find.text('SPLASH', skipOffstage: false);

  testWidgets('the splash stays under the page until its fade-in completes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app());
    splashNavigate(AppRoutes.login);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(splash, findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(splash, findsNothing);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('back during the fade-in leaves the app instead of emptying the navigator', (
    WidgetTester tester,
  ) async {
    recordPlatformCalls(tester);
    await tester.pumpWidget(app());
    splashNavigate(AppRoutes.login);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(platformCalls, contains('SystemNavigator.pop'));
    expect(splash, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home: the pending notification opens on top of home', (WidgetTester tester) async {
    final List<Map<String, dynamic>> opened = <Map<String, dynamic>>[];
    NotificationNavigator.opener = (Map<String, dynamic> data) async => opened.add(data);
    NotificationNavigator.setPending(<String, dynamic>{'type': 'parkir'});
    await tester.pumpWidget(app());

    splashNavigate(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(opened, <Map<String, dynamic>>[
      <String, dynamic>{'type': 'parkir'},
    ]);
    expect(find.text('HOME'), findsOneWidget);
    expect(splash, findsNothing);
  });
}
