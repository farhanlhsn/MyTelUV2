import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile/pages/settings/notification_page.dart';
import 'package:mobile/services/auth_service.dart';

import 'support/stub_http_adapter.dart';

/// AuthService with only what the preference page calls.
class _FakeAuthService extends Fake implements AuthService {
  /// What GET /auth/me answers; one entry per call, the last one repeats.
  final List<FutureOr<Map<String, dynamic>> Function()> meAnswers;
  final List<bool> saved = <bool>[];
  FutureOr<Map<String, dynamic>> Function(bool enabled)? onSave;
  int meCalls = 0;

  _FakeAuthService({required this.meAnswers});

  @override
  Future<Map<String, dynamic>> getMe() async {
    final index = meCalls < meAnswers.length ? meCalls : meAnswers.length - 1;
    meCalls++;
    return meAnswers[index]();
  }

  @override
  Future<Map<String, dynamic>> updatePushPreference({required bool enabled}) async {
    saved.add(enabled);
    final save = onSave;
    if (save != null) return save(enabled);
    return <String, dynamic>{
      'status': 'success',
      'data': <String, dynamic>{'push_notifications_enabled': enabled},
    };
  }
}

Map<String, dynamic> _me({Object? push = true, bool includePush = true}) => <String, dynamic>{
  'status': 'success',
  'data': <String, dynamic>{
    'id': 7,
    'username': 'budi',
    'nama': 'Budi',
    'role': 'MAHASISWA',
    if (includePush) 'push_notifications_enabled': push,
  },
};

void main() {
  tearDown(() => Get.reset());

  Future<void> pumpPage(WidgetTester tester, AuthService service) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(home: NotificationPage(authService: service)));
  }

  Switch theSwitch(WidgetTester tester) => tester.widget<Switch>(find.byType(Switch));

  group('AuthService push preference', () {
    test('saves with PUT /auth/preferences {push_notifications_enabled}', () async {
      final adapter = StubHttpAdapter(200, <String, dynamic>{
        'status': 'success',
        'data': <String, dynamic>{'id_user': 7, 'push_notifications_enabled': false},
      });
      final service = AuthService(dio: adapter.dio());

      final result = await service.updatePushPreference(enabled: false);

      expect(result['status'], 'success');
      final request = adapter.lastRequest!;
      expect(request.method, 'PUT');
      expect(request.path, '/api/v1/auth/preferences');
      expect(request.data, <String, dynamic>{'push_notifications_enabled': false});
    });

    test('a server error reaches the caller', () async {
      final adapter = StubHttpAdapter(500, <String, dynamic>{
        'status': 'error',
        'message': 'Terjadi kesalahan',
      });
      final service = AuthService(dio: adapter.dio());

      await expectLater(
        service.updatePushPreference(enabled: true),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('NotificationPage (push preference)', () {
    testWidgets('shows the switch ON when the profile says push is enabled', (tester) async {
      final service = _FakeAuthService(meAnswers: [() => _me(push: true)]);
      await pumpPage(tester, service);
      await tester.pumpAndSettle();

      expect(theSwitch(tester).value, isTrue);
      expect(service.meCalls, 1);
    });

    testWidgets('shows the switch OFF when the profile says push is disabled', (tester) async {
      final service = _FakeAuthService(meAnswers: [() => _me(push: false)]);
      await pumpPage(tester, service);
      await tester.pumpAndSettle();

      expect(theSwitch(tester).value, isFalse);
    });

    testWidgets('a profile without the field (older server) means enabled, the server default', (tester) async {
      final service = _FakeAuthService(meAnswers: [() => _me(includePush: false)]);
      await pumpPage(tester, service);
      await tester.pumpAndSettle();

      expect(theSwitch(tester).value, isTrue);
    });

    testWidgets('while the profile loads there is no switch to flip', (tester) async {
      final completer = Completer<Map<String, dynamic>>();
      final service = _FakeAuthService(meAnswers: [() => completer.future]);
      await pumpPage(tester, service);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Switch), findsNothing);

      completer.complete(_me(push: false));
      await tester.pumpAndSettle();
      expect(theSwitch(tester).value, isFalse);
    });

    testWidgets('a failed load shows an error with Coba Lagi, which loads again', (tester) async {
      final service = _FakeAuthService(
        meAnswers: [
          () => throw DioException(
            requestOptions: RequestOptions(path: '/api/v1/auth/me'),
            type: DioExceptionType.connectionError,
          ),
          () => _me(push: false),
        ],
      );
      await pumpPage(tester, service);
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsNothing);
      expect(find.text('Coba Lagi'), findsOneWidget);

      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(service.meCalls, 2);
      expect(theSwitch(tester).value, isFalse);
    });

    testWidgets('flipping the switch saves the new value on the server', (tester) async {
      final service = _FakeAuthService(meAnswers: [() => _me(push: true)]);
      await pumpPage(tester, service);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();

      expect(service.saved, <bool>[false]);
      expect(theSwitch(tester).value, isFalse);
      expect(find.text('Notifikasi non-aktif - Anda tidak akan menerima notifikasi'), findsOneWidget);
    });

    testWidgets('a failed save puts the switch back and shows an error', (tester) async {
      final service = _FakeAuthService(meAnswers: [() => _me(push: true)]);
      service.onSave = (_) => throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/preferences'),
        type: DioExceptionType.connectionError,
      );
      await pumpPage(tester, service);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(service.saved, <bool>[false]);
      expect(theSwitch(tester).value, isTrue, reason: 'reverted: the server still has push on');
      expect(find.textContaining('Gagal menyimpan pengaturan notifikasi'), findsOneWidget);
    });

    testWidgets('the switch is locked while a save is in flight', (tester) async {
      final completer = Completer<Map<String, dynamic>>();
      final service = _FakeAuthService(meAnswers: [() => _me(push: true)]);
      service.onSave = (_) => completer.future;
      await pumpPage(tester, service);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(theSwitch(tester).onChanged, isNull);

      await tester.tap(find.byType(Switch), warnIfMissed: false);
      await tester.pump();
      expect(service.saved, <bool>[false], reason: 'a second tap must not send another request');

      completer.complete(<String, dynamic>{'status': 'success'});
      await tester.pump();
      await tester.pump();
      expect(theSwitch(tester).onChanged, isNotNull);
    });
  });
}
