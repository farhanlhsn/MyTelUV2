import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/utils/notification_router.dart';

/// Routing of a tapped push notification / inbox card. The `type` strings and data keys are the
/// ones sent by backend/utils/firebase.js (all data values are strings).
void main() {
  group('routeForNotification', () {
    test('ABSENSI_NOTIFICATION opens the student attendance page', () {
      expect(
        routeForNotification(<String, dynamic>{
          'type': 'ABSENSI_NOTIFICATION',
          'id_kelas': '12',
          'timestamp': '2026-10-13T01:00:00.000Z',
        }),
        AppRoutes.absensi,
      );
    });

    test('JADWAL_PENGGANTI_NOTIFICATION opens the weekly schedule', () {
      for (final status in <String>['LIBUR', 'GANTI_JADWAL']) {
        expect(
          routeForNotification(<String, dynamic>{
            'type': 'JADWAL_PENGGANTI_NOTIFICATION',
            'id_kelas': '12',
            'id_jadwal_pengganti': '3',
            'status': status,
          }),
          AppRoutes.jadwalMingguan,
          reason: status,
        );
      }
    });

    test('PARKING_NOTIFICATION opens the parking history, for entry and exit', () {
      for (final parkingType in <String>['MASUK', 'KELUAR']) {
        expect(
          routeForNotification(<String, dynamic>{
            'type': 'PARKING_NOTIFICATION',
            'parking_type': parkingType,
            'plat_nomor': 'D 1234 ABC',
            'nama_kendaraan': 'Vario',
            'parkiran_name': 'Parkiran Barat',
          }),
          AppRoutes.historiParkir,
          reason: parkingType,
        );
      }
    });

    test('every KENDARAAN_* status opens the vehicle submission history', () {
      for (final type in <String>[
        'KENDARAAN_APPROVED',
        'KENDARAAN_REJECTED',
        'KENDARAAN_DELETED',
        'KENDARAAN_DELETE_REJECTED',
      ]) {
        expect(
          routeForNotification(<String, dynamic>{
            'type': type,
            'id_kendaraan': '5',
            if (type == 'KENDARAAN_REJECTED') 'feedback': 'Foto STNK buram',
          }),
          AppRoutes.userHistoriPengajuan,
          reason: type,
        );
      }
    });

    test('SOCIAL_NOTIFICATION with a post id opens that post\'s comments', () {
      for (final socialType in <String>['LIKE', 'COMMENT']) {
        expect(
          routeForNotification(<String, dynamic>{
            'type': 'SOCIAL_NOTIFICATION',
            'social_type': socialType,
            'actor_name': 'Budi',
            'id_post': '42',
          }),
          AppRoutes.postComments,
          reason: socialType,
        );
      }
    });

    test('SOCIAL_NOTIFICATION with a missing or unusable post id falls back to the inbox', () {
      for (final idPost in <Object?>[null, '', '  ', 'abc', '0', '-4', '12abc', '1.5', <String, dynamic>{}]) {
        expect(
          routeForNotification(<String, dynamic>{
            'type': 'SOCIAL_NOTIFICATION',
            'social_type': 'LIKE',
            'id_post': idPost,
          }),
          AppRoutes.notificationList,
          reason: 'id_post=$idPost',
        );
      }
      expect(
        routeForNotification(<String, dynamic>{'type': 'SOCIAL_NOTIFICATION'}),
        AppRoutes.notificationList,
      );
    });

    test('a numeric post id (inbox JSON may hold an int) works like a string one', () {
      expect(
        routeForNotification(<String, dynamic>{
          'type': 'SOCIAL_NOTIFICATION',
          'id_post': 42,
        }),
        AppRoutes.postComments,
      );
    });

    test('unknown, missing or garbage data opens the notification list', () {
      final cases = <Map<String, dynamic>>[
        <String, dynamic>{},
        <String, dynamic>{'type': 'SOMETHING_NEW'},
        <String, dynamic>{'type': 'general'},
        <String, dynamic>{'type': ''},
        <String, dynamic>{'type': null},
        <String, dynamic>{'type': 42},
        <String, dynamic>{'type': <String, dynamic>{'nested': true}},
        <String, dynamic>{'type': 'absensi_notification'}, // case matters: the backend sends upper case
        <String, dynamic>{'type': 'ABSENSI_NOTIFICATION '},
        <String, dynamic>{'click_action': 'FLUTTER_NOTIFICATION_CLICK'},
        <String, dynamic>{'id_post': '42'}, // a post id alone is not a social notification
      ];
      for (final data in cases) {
        expect(routeForNotification(data), AppRoutes.notificationList, reason: '$data');
      }
    });
  });

  group('argumentsForNotification', () {
    test('only the comments route carries the post id, as an int', () {
      expect(
        argumentsForNotification(<String, dynamic>{
          'type': 'SOCIAL_NOTIFICATION',
          'id_post': '42',
        }),
        <String, dynamic>{'id_post': 42},
      );
      expect(
        argumentsForNotification(<String, dynamic>{
          'type': 'SOCIAL_NOTIFICATION',
          'id_post': 7,
        }),
        <String, dynamic>{'id_post': 7},
      );
    });

    test('every other target has no arguments', () {
      final cases = <Map<String, dynamic>>[
        <String, dynamic>{'type': 'ABSENSI_NOTIFICATION', 'id_kelas': '12'},
        <String, dynamic>{'type': 'JADWAL_PENGGANTI_NOTIFICATION', 'id_kelas': '12'},
        <String, dynamic>{'type': 'PARKING_NOTIFICATION'},
        <String, dynamic>{'type': 'KENDARAAN_APPROVED', 'id_kendaraan': '5'},
        <String, dynamic>{'type': 'SOCIAL_NOTIFICATION', 'id_post': 'abc'},
        <String, dynamic>{'type': 'SOCIAL_NOTIFICATION'},
        <String, dynamic>{},
        <String, dynamic>{'type': 'SOMETHING_NEW'},
      ];
      for (final data in cases) {
        expect(argumentsForNotification(data), isNull, reason: '$data');
      }
    });
  });

  group('dataOfInboxEntry', () {
    test('uses the stored FCM data', () {
      final data = dataOfInboxEntry(<String, dynamic>{
        'id': 'm1',
        'type': 'SOCIAL_NOTIFICATION',
        'data': <String, dynamic>{'type': 'SOCIAL_NOTIFICATION', 'id_post': '42'},
      });
      expect(routeForNotification(data), AppRoutes.postComments);
      expect(argumentsForNotification(data), <String, dynamic>{'id_post': 42});
    });

    test('falls back to the entry\'s own type when the data is missing or not a map', () {
      for (final raw in <Object?>[null, 'garbage', 7, <Object?>[]]) {
        final data = dataOfInboxEntry(<String, dynamic>{
          'type': 'PARKING_NOTIFICATION',
          'data': raw,
        });
        expect(routeForNotification(data), AppRoutes.historiParkir, reason: '$raw');
      }
    });

    test('an entry with nothing usable opens the notification list', () {
      expect(routeForNotification(dataOfInboxEntry(<String, dynamic>{})), AppRoutes.notificationList);
      expect(
        routeForNotification(dataOfInboxEntry(<String, dynamic>{'type': 'general', 'data': <String, dynamic>{}})),
        AppRoutes.notificationList,
      );
    });

    test('does not change the entry it reads', () {
      final entry = <String, dynamic>{
        'type': 'ABSENSI_NOTIFICATION',
        'data': <String, dynamic>{'id_kelas': '1'},
      };
      dataOfInboxEntry(entry);
      expect((entry['data'] as Map<String, dynamic>).containsKey('type'), isFalse);
    });
  });

  group('notificationCategory (inbox filters)', () {
    test('academic category holds attendance and jadwal pengganti', () {
      expect(notificationCategory('ABSENSI_NOTIFICATION'), 'Akademik');
      expect(notificationCategory('JADWAL_PENGGANTI_NOTIFICATION'), 'Akademik');
    });

    test('vehicle category holds parking and every KENDARAAN_* status', () {
      expect(notificationCategory('PARKING_NOTIFICATION'), 'Kendaraan');
      expect(notificationCategory('KENDARAAN_APPROVED'), 'Kendaraan');
      expect(notificationCategory('KENDARAAN_REJECTED'), 'Kendaraan');
      expect(notificationCategory('KENDARAAN_DELETED'), 'Kendaraan');
      expect(notificationCategory('KENDARAAN_DELETE_REJECTED'), 'Kendaraan');
    });

    test('social category holds likes and comments', () {
      expect(notificationCategory('SOCIAL_NOTIFICATION'), 'Sosial');
    });

    test('anything else belongs to no filter category', () {
      expect(notificationCategory('general'), isNull);
      expect(notificationCategory(''), isNull);
      expect(notificationCategory(null), isNull);
      expect(notificationCategory(42), isNull);
    });
  });

  group('NotificationNavigator (cold start)', () {
    late List<Map<String, dynamic>> opened;

    setUp(() {
      opened = <Map<String, dynamic>>[];
      NotificationNavigator.opener = (data) async => opened.add(data);
      NotificationNavigator.clearPending();
    });

    tearDown(() {
      NotificationNavigator.resetForTest();
    });

    test('nothing pending: openPending does nothing', () async {
      expect(NotificationNavigator.hasPending, isFalse);
      await NotificationNavigator.openPending();
      expect(opened, isEmpty);
    });

    test('the notification that started the app is opened once, when asked to', () async {
      NotificationNavigator.setPending(<String, dynamic>{'type': 'PARKING_NOTIFICATION'});
      expect(NotificationNavigator.hasPending, isTrue);
      expect(opened, isEmpty, reason: 'nothing is opened before the app is ready');

      await NotificationNavigator.openPending();
      expect(opened, <Map<String, dynamic>>[
        <String, dynamic>{'type': 'PARKING_NOTIFICATION'},
      ]);

      await NotificationNavigator.openPending();
      expect(opened, hasLength(1), reason: 'a second call must not open it again');
      expect(NotificationNavigator.hasPending, isFalse);
    });

    test('clearPending drops it (e.g. the user is not logged in)', () async {
      NotificationNavigator.setPending(<String, dynamic>{'type': 'ABSENSI_NOTIFICATION'});
      NotificationNavigator.clearPending();
      await NotificationNavigator.openPending();
      expect(opened, isEmpty);
    });

    test('a failing opener does not throw out of openPending', () async {
      NotificationNavigator.opener = (data) async => throw StateError('navigator not ready');
      NotificationNavigator.setPending(<String, dynamic>{'type': 'ABSENSI_NOTIFICATION'});
      await NotificationNavigator.openPending();
      expect(NotificationNavigator.hasPending, isFalse);
    });
  });
}
