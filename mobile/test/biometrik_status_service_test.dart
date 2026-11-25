import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/biometrik_status.dart';
import 'package:mobile/services/biometrik_service.dart';

import 'support/stub_http_adapter.dart';

BiometrikService _service(StubHttpAdapter adapter) =>
    BiometrikService(dio: adapter.dio());

void main() {
  group('BiometrikService.getStatusBiometrikSaya', () {
    test('registered: terdaftar and the update time', () async {
      final adapter = StubHttpAdapter(200, <String, dynamic>{
        'status': 'success',
        'data': <String, dynamic>{
          'terdaftar': true,
          'diperbarui': '2026-10-01T03:04:05.000Z',
        },
      });

      final BiometrikStatus status = await _service(
        adapter,
      ).getStatusBiometrikSaya();

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.path, '/api/v1/biometrik/status');
      expect(status.terdaftar, isTrue);
      expect(status.diperbarui, DateTime.utc(2026, 10, 1, 3, 4, 5));
    });

    test('not registered: terdaftar false and no update time', () async {
      final adapter = StubHttpAdapter(200, <String, dynamic>{
        'status': 'success',
        'data': <String, dynamic>{'terdaftar': false, 'diperbarui': null},
      });

      final status = await _service(adapter).getStatusBiometrikSaya();

      expect(status.terdaftar, isFalse);
      expect(status.diperbarui, isNull);
    });

    test('an unparsable update time is ignored, not fatal', () async {
      final adapter = StubHttpAdapter(200, <String, dynamic>{
        'status': 'success',
        'data': <String, dynamic>{'terdaftar': true, 'diperbarui': 'kemarin'},
      });

      final status = await _service(adapter).getStatusBiometrikSaya();

      expect(status.terdaftar, isTrue);
      expect(status.diperbarui, isNull);
    });

    test('a response without data is an error, not "not registered"', () async {
      final adapter = StubHttpAdapter(200, <String, dynamic>{
        'status': 'success',
      });

      expect(
        () => _service(adapter).getStatusBiometrikSaya(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Status biometrik tidak dapat dibaca'),
          ),
        ),
      );
    });

    test('carries the backend message of an error response', () async {
      final adapter = StubHttpAdapter(500, <String, dynamic>{
        'status': 'error',
        'message': 'Terjadi kesalahan pada server',
      });

      expect(
        () => _service(adapter).getStatusBiometrikSaya(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Terjadi kesalahan pada server'),
          ),
        ),
      );
    });
  });

  group('BiometrikStatus.fromJson', () {
    test('needs a boolean terdaftar', () {
      expect(
        BiometrikStatus.fromJson(<String, dynamic>{'diperbarui': null}),
        isNull,
      );
      expect(
        BiometrikStatus.fromJson(<String, dynamic>{'terdaftar': 'ya'}),
        isNull,
      );
    });
  });
}
