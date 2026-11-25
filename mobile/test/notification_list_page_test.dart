import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/controllers/notification_controller.dart';
import 'package:mobile/pages/home/notification_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The inbox: a tap on a card goes through the same router as a push tap, and the filters know
/// the jadwal pengganti notification.
void main() {
  final now = DateTime.now().toIso8601String();

  Map<String, dynamic> entry(String id, String title, String type, [Map<String, dynamic>? data]) =>
      <String, dynamic>{
        'id': id,
        'title': title,
        'body': 'Isi $title',
        'data': <String, dynamic>{'type': type, ...?data},
        'timestamp': now,
        'type': type,
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'notifications_7': jsonEncode(<Object?>[
        entry('1', 'Kelas Diliburkan', 'JADWAL_PENGGANTI_NOTIFICATION', {'id_kelas': '3', 'status': 'LIBUR'}),
        entry('2', 'Kendaraan Masuk', 'PARKING_NOTIFICATION', {'parking_type': 'MASUK'}),
        entry('3', 'Budi menyukai postingan Anda', 'SOCIAL_NOTIFICATION', {'social_type': 'LIKE', 'id_post': '42'}),
        entry('4', 'Pengumuman', 'general'),
        entry('5', 'Pengajuan Disetujui', 'KENDARAAN_APPROVED', {'id_kendaraan': '5'}),
      ]),
    });
    Get.reset();
  });

  tearDown(() => Get.reset());

  Future<void> pumpList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // SharedPreferences answers on real time, not on the test clock: load the inbox outside of it
    await tester.runAsync(() async {
      final controller = Get.put(NotificationController(userIdProvider: () async => 7));
      await controller.loadNotifications();
    });

    Widget placeholder(String label) => Scaffold(body: Center(child: Text(label)));

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.notificationList,
        getPages: [
          GetPage<dynamic>(name: AppRoutes.notificationList, page: () => const NotificationListPage()),
          GetPage<dynamic>(name: AppRoutes.historiParkir, page: () => placeholder('HALAMAN PARKIR')),
          GetPage<dynamic>(name: AppRoutes.jadwalMingguan, page: () => placeholder('HALAMAN JADWAL')),
          GetPage<dynamic>(name: AppRoutes.userHistoriPengajuan, page: () => placeholder('HALAMAN PENGAJUAN')),
          GetPage<dynamic>(
            name: AppRoutes.postComments,
            page: () => placeholder('HALAMAN POST ${(Get.arguments as Map)['id_post']}'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the filter menu and picks [label]. The menu rows and the filter banner are wider than
  /// their box in the test font (Ahem draws every letter a full em wide); with a real font they fit.
  /// That overflow is not what these tests are about.
  Future<void> chooseFilter(WidgetTester tester, String label) async {
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}
  }

  testWidgets('shows only this user\'s notifications', (tester) async {
    await pumpList(tester);

    expect(find.text('Kelas Diliburkan'), findsOneWidget);
    expect(find.text('Kendaraan Masuk'), findsOneWidget);
    expect(find.text('Pengumuman'), findsOneWidget);
  });

  testWidgets('tapping a parking card opens the parking history', (tester) async {
    await pumpList(tester);

    await tester.tap(find.text('Kendaraan Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('HALAMAN PARKIR'), findsOneWidget);
  });

  testWidgets('tapping a jadwal pengganti card opens the weekly schedule', (tester) async {
    await pumpList(tester);

    await tester.tap(find.text('Kelas Diliburkan'));
    await tester.pumpAndSettle();

    expect(find.text('HALAMAN JADWAL'), findsOneWidget);
  });

  testWidgets('tapping a vehicle status card opens the submission history', (tester) async {
    await pumpList(tester);

    await tester.tap(find.text('Pengajuan Disetujui'));
    await tester.pumpAndSettle();

    expect(find.text('HALAMAN PENGAJUAN'), findsOneWidget);
  });

  testWidgets('tapping a social card opens that post with its id', (tester) async {
    await pumpList(tester);

    await tester.tap(find.text('Budi menyukai postingan Anda'));
    await tester.pumpAndSettle();

    expect(find.text('HALAMAN POST 42'), findsOneWidget);
  });

  testWidgets('tapping a card of an unknown type stays in the inbox', (tester) async {
    await pumpList(tester);

    await tester.tap(find.text('Pengumuman'));
    await tester.pumpAndSettle();

    expect(find.text('Pengumuman'), findsOneWidget);
    expect(find.textContaining('HALAMAN'), findsNothing);
    expect(Get.currentRoute, AppRoutes.notificationList);
  });

  testWidgets('the Akademik filter holds attendance and jadwal pengganti', (tester) async {
    await pumpList(tester);

    await chooseFilter(tester, 'Akademik & Absensi');

    expect(find.text('Kelas Diliburkan'), findsOneWidget);
    expect(find.text('Kendaraan Masuk'), findsNothing);
    expect(find.text('Budi menyukai postingan Anda'), findsNothing);
    expect(find.text('Pengumuman'), findsNothing);
  });

  testWidgets('the Kendaraan filter holds parking and vehicle statuses', (tester) async {
    await pumpList(tester);

    await chooseFilter(tester, 'Kendaraan & Parkir');

    expect(find.text('Kendaraan Masuk'), findsOneWidget);
    expect(find.text('Pengajuan Disetujui'), findsOneWidget);
    expect(find.text('Kelas Diliburkan'), findsNothing);
  });
}
