import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/auth_middleware.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/pages/splash_page.dart';

/// The splash plays a short intro while the session is checked, leaves through a rising white
/// sheet, and navigates exactly once. It never waits for a fixed delay.
void main() {
  late Completer<String> check;
  late List<String> calls;

  // Created inside each test body: a Completer made in setUp lives outside the fake-async zone of
  // testWidgets, and its callbacks would never run during pump.
  void fresh() {
    check = Completer<String>();
    calls = <String>[];
  }

  Widget splash({bool reducedMotion = false}) => MaterialApp(
        home: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
            child: SplashPage(resolve: () => check.future, navigate: calls.add),
          ),
        ),
      );

  /// Real time passes in frames; one big pump would collapse the intro and the exit into one step.
  Future<void> advance(WidgetTester tester, int ms) async {
    for (int t = 0; t < ms; t += 16) {
      await tester.pump(Duration(milliseconds: ms - t < 16 ? ms - t : 16));
    }
  }

  final Finder progress = find.byKey(const Key('splash-progress'));
  final Finder sheet = find.byKey(const Key('splash-sheet'));

  testWidgets('shows the mark and the MyTelU wordmark', (WidgetTester tester) async {
    fresh();
    await tester.pumpWidget(splash());
    await advance(tester, 700);

    expect(find.text('MyTelU'), findsOneWidget);
    expect(find.text('Telkom University'), findsOneWidget);
  });

  testWidgets('instant check: navigates once after intro and exit, without a fixed delay', (
    WidgetTester tester,
  ) async {
    fresh();
    check.complete(AppRoutes.login);
    await tester.pumpWidget(splash());

    await advance(tester, 1250);
    expect(calls, <String>[AppRoutes.login]);

    await advance(tester, 1000);
    expect(calls, <String>[AppRoutes.login]);
  });

  testWidgets('slow check shows the progress line and navigates once', (WidgetTester tester) async {
    fresh();
    await tester.pumpWidget(splash());

    await advance(tester, 600);
    expect(progress, findsNothing);
    await advance(tester, 200);
    expect(progress, findsOneWidget);

    await advance(tester, 1200);
    expect(calls, isEmpty);
    check.complete(AppRoutes.home);
    await advance(tester, 500);
    expect(calls, <String>[AppRoutes.home]);

    await advance(tester, 1000);
    expect(calls, <String>[AppRoutes.home]);
  });

  testWidgets('fast check never shows the progress line', (WidgetTester tester) async {
    fresh();
    await tester.pumpWidget(splash());
    for (int t = 0; t < 1250; t += 50) {
      if (t == 300) check.complete(AppRoutes.login);
      await advance(tester, 50);
      expect(progress, findsNothing);
    }
    expect(calls, <String>[AppRoutes.login]);
  });

  testWidgets('exit raises the sheet', (WidgetTester tester) async {
    fresh();
    check.complete(AppRoutes.login);
    await tester.pumpWidget(splash());

    await advance(tester, 700);
    expect(sheet, findsNothing);
    await advance(tester, 200);
    expect(sheet, findsOneWidget);
  });

  testWidgets('reduced motion skips intro and sheet', (WidgetTester tester) async {
    fresh();
    check.complete(AppRoutes.login);
    await tester.pumpWidget(splash(reducedMotion: true));

    for (int t = 0; t < 300; t += 16) {
      await advance(tester, 16);
      expect(sheet, findsNothing);
    }
    expect(find.text('MyTelU'), findsOneWidget);
    expect(calls, <String>[AppRoutes.login]);
  });

  testWidgets('disposed splash never navigates', (WidgetTester tester) async {
    fresh();
    await tester.pumpWidget(splash());
    await advance(tester, 200);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    check.complete(AppRoutes.home);
    await advance(tester, 2000);

    expect(calls, isEmpty);
  });

  group('splashSheetTop lands on the first frame of the destination', () {
    tearDown(AuthMiddleware.clearCredentials);

    Future<double> top(WidgetTester tester, String route) async {
      late double value;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
        child: Builder(builder: (BuildContext context) {
          value = splashSheetTop(context, route);
          return const SizedBox();
        }),
      ));
      return value;
    }

    testWidgets('login: below its one-line header', (WidgetTester tester) async {
      expect(await top(tester, AppRoutes.login), 24 + 54);
    });

    testWidgets('home for an admin: no schedule block', (WidgetTester tester) async {
      AuthMiddleware.cachedRole = 'ADMIN';
      expect(await top(tester, AppRoutes.home), 24 + 59);
    });

    testWidgets('home for students and lecturers: below the loading schedule', (
      WidgetTester tester,
    ) async {
      AuthMiddleware.cachedRole = 'MAHASISWA';
      expect(await top(tester, AppRoutes.home), 24 + 282);
      AuthMiddleware.cachedRole = 'DOSEN';
      expect(await top(tester, AppRoutes.home), 24 + 282);
    });
  });
}
