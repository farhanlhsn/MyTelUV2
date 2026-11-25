import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/notification_inbox.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_controller_test.mocks.dart';

/// The local notification inbox is per user: `notifications_<id_user>`. The old global key
/// (`local_notifications`) is dropped, never shown to whoever logs in next.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> entry(String id, {String type = 'ABSENSI_NOTIFICATION', String? timestamp}) =>
      <String, dynamic>{
        'id': id,
        'title': 'Judul $id',
        'body': 'Isi $id',
        'data': <String, dynamic>{'type': type},
        'timestamp': timestamp ?? '2026-10-13T10:00:00.000',
        'type': type,
      };

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('keys', () {
    test('the inbox and its read marker are namespaced by user id', () {
      expect(NotificationInbox.notificationsKey(7), 'notifications_7');
      expect(NotificationInbox.notificationsKey(8), 'notifications_8');
      expect(NotificationInbox.lastReadKey(7), isNot(NotificationInbox.lastReadKey(8)));
      expect(NotificationInbox.lastReadKey(7), isNot(NotificationInbox.legacyLastReadKey));
    });
  });

  group('append / read', () {
    test('entries come back oldest first', () async {
      final prefs = await prefsWith(<String, Object>{});
      await NotificationInbox.append(prefs, 7, entry('1'));
      await NotificationInbox.append(prefs, 7, entry('2'));

      expect(NotificationInbox.read(prefs, 7).map((e) => e['id']), <Object?>['1', '2']);
    });

    test('two users never see each other\'s notifications', () async {
      final prefs = await prefsWith(<String, Object>{});
      await NotificationInbox.append(prefs, 7, entry('a'));
      await NotificationInbox.append(prefs, 8, entry('b'));

      expect(NotificationInbox.read(prefs, 7).map((e) => e['id']), <Object?>['a']);
      expect(NotificationInbox.read(prefs, 8).map((e) => e['id']), <Object?>['b']);
      expect(prefs.containsKey('notifications_7'), isTrue);
      expect(prefs.containsKey('notifications_8'), isTrue);
    });

    test('only the last 50 entries are kept', () async {
      final prefs = await prefsWith(<String, Object>{});
      for (var i = 1; i <= 55; i++) {
        await NotificationInbox.append(prefs, 7, entry('$i'));
      }

      final stored = NotificationInbox.read(prefs, 7);
      expect(stored, hasLength(NotificationInbox.maxEntries));
      expect(stored.first['id'], '6');
      expect(stored.last['id'], '55');
    });

    test('the same message saved twice (background handler + opened app) is one entry', () async {
      final prefs = await prefsWith(<String, Object>{});
      await NotificationInbox.append(prefs, 7, entry('m1'));
      await NotificationInbox.append(prefs, 7, entry('m1'));

      expect(NotificationInbox.read(prefs, 7), hasLength(1));
    });

    test('entries without a message id are all kept', () async {
      final prefs = await prefsWith(<String, Object>{});
      await NotificationInbox.append(prefs, 7, <String, dynamic>{'id': null, 'title': 'a'});
      await NotificationInbox.append(prefs, 7, <String, dynamic>{'id': null, 'title': 'b'});

      expect(NotificationInbox.read(prefs, 7), hasLength(2));
    });

    test('a corrupt inbox reads as empty and is replaced by the next entry', () async {
      final prefs = await prefsWith(<String, Object>{'notifications_7': '{not json'});
      expect(NotificationInbox.read(prefs, 7), isEmpty);

      await NotificationInbox.append(prefs, 7, entry('1'));
      expect(NotificationInbox.read(prefs, 7).map((e) => e['id']), <Object?>['1']);
    });

    test('values that are not entries are skipped', () async {
      final prefs = await prefsWith(<String, Object>{
        'notifications_7': jsonEncode(<Object?>[entry('1'), 'junk', 3, null]),
      });
      expect(NotificationInbox.read(prefs, 7).map((e) => e['id']), <Object?>['1']);
    });
  });

  group('legacy global inbox', () {
    test('is removed, and nothing from it reaches any user', () async {
      final prefs = await prefsWith(<String, Object>{
        'local_notifications': jsonEncode(<Object?>[entry('old')]),
        'last_read_timestamp': '2026-10-13T09:00:00.000',
      });

      await NotificationInbox.removeLegacy(prefs);

      expect(prefs.containsKey('local_notifications'), isFalse);
      expect(prefs.containsKey('last_read_timestamp'), isFalse);
      expect(NotificationInbox.read(prefs, 7), isEmpty);
    });

    test('is removed the first time an entry is saved with the new code', () async {
      final prefs = await prefsWith(<String, Object>{
        'local_notifications': jsonEncode(<Object?>[entry('old')]),
      });

      await NotificationInbox.append(prefs, 7, entry('new'));

      expect(prefs.containsKey('local_notifications'), isFalse);
      expect(NotificationInbox.read(prefs, 7).map((e) => e['id']), <Object?>['new']);
    });

    test('removing it when it is not there is fine', () async {
      final prefs = await prefsWith(<String, Object>{});
      await NotificationInbox.removeLegacy(prefs);
      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('read marker and unread count', () {
    test('the marker is per user', () async {
      final prefs = await prefsWith(<String, Object>{});
      final seven = DateTime(2026, 10, 13, 10);
      await NotificationInbox.markRead(prefs, 7, seven);

      expect(NotificationInbox.lastRead(prefs, 7), seven);
      expect(NotificationInbox.lastRead(prefs, 8), isNull);
    });

    test('without a marker everything is unread', () {
      final entries = <Map<String, dynamic>>[entry('1'), entry('2')];
      expect(NotificationInbox.unreadCount(entries, null), 2);
    });

    test('only entries newer than the marker are unread; no timestamp is not unread', () {
      final entries = <Map<String, dynamic>>[
        entry('1', timestamp: '2026-10-13T09:00:00.000'),
        entry('2', timestamp: '2026-10-13T11:00:00.000'),
        entry('3', timestamp: 'garbage'),
        <String, dynamic>{'id': '4'},
      ];
      expect(NotificationInbox.unreadCount(entries, DateTime(2026, 10, 13, 10)), 1);
    });
  });

  group('clear', () {
    test('removes that user\'s inbox and marker, not another user\'s, and the legacy keys', () async {
      final prefs = await prefsWith(<String, Object>{
        'notifications_7': jsonEncode(<Object?>[entry('a')]),
        'notifications_last_read_7': '2026-10-13T10:00:00.000',
        'notifications_8': jsonEncode(<Object?>[entry('b')]),
        'local_notifications': jsonEncode(<Object?>[entry('old')]),
        'last_read_timestamp': '2026-10-13T09:00:00.000',
      });

      await NotificationInbox.clearFor(prefs, 7);

      expect(prefs.containsKey('notifications_7'), isFalse);
      expect(prefs.containsKey('notifications_last_read_7'), isFalse);
      expect(prefs.containsKey('local_notifications'), isFalse);
      expect(prefs.containsKey('last_read_timestamp'), isFalse);
      expect(NotificationInbox.read(prefs, 8).map((e) => e['id']), <Object?>['b']);
    });

    test('clear(null) (nobody known) still drops the legacy inbox', () async {
      await prefsWith(<String, Object>{
        'local_notifications': jsonEncode(<Object?>[entry('old')]),
        'notifications_8': jsonEncode(<Object?>[entry('b')]),
      });

      await NotificationInbox.clear(null);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('local_notifications'), isFalse);
      expect(prefs.containsKey('notifications_8'), isTrue);
    });

    test('clear(id) works on the shared preferences instance', () async {
      await prefsWith(<String, Object>{
        'notifications_7': jsonEncode(<Object?>[entry('a')]),
      });

      await NotificationInbox.clear(7);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('notifications_7'), isFalse);
    });
  });

  group('currentUserId', () {
    test('is the stored id_user', () async {
      final storage = MockFlutterSecureStorage();
      when(storage.read(key: 'id_user')).thenAnswer((_) async => '12');
      expect(await NotificationInbox.currentUserId(storage: storage), 12);
    });

    test('is null when logged out, garbage, or storage fails', () async {
      final storage = MockFlutterSecureStorage();

      when(storage.read(key: 'id_user')).thenAnswer((_) async => null);
      expect(await NotificationInbox.currentUserId(storage: storage), isNull);

      when(storage.read(key: 'id_user')).thenAnswer((_) async => 'abc');
      expect(await NotificationInbox.currentUserId(storage: storage), isNull);

      when(storage.read(key: 'id_user')).thenAnswer((_) async => '0');
      expect(await NotificationInbox.currentUserId(storage: storage), isNull);

      when(storage.read(key: 'id_user')).thenThrow(Exception('keystore locked'));
      expect(await NotificationInbox.currentUserId(storage: storage), isNull);
    });
  });
}
