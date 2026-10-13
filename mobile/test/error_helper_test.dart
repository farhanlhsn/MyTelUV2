import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/error_helper.dart';
import 'package:mobile/utils/server_messages.dart';

void main() {
  group('ErrorHelper.parseError', () {
    test('strips the "Exception:" prefix', () {
      expect(
        ErrorHelper.parseError(Exception('Anda sudah melakukan absensi')),
        'Anda sudah melakukan absensi',
      );
    });

    test('strips nested "Exception:" prefixes', () {
      expect(
        ErrorHelper.parseError(Exception('Exception: Gagal memuat sesi')),
        'Gagal memuat sesi',
      );
    });

    test(
      'strips the prefix from a plain string too (e.toString() callers)',
      () {
        expect(
          ErrorHelper.parseError('Exception: Lokasi tidak aktif'),
          'Lokasi tidak aktif',
        );
        expect(ErrorHelper.parseError('Sudah bersih'), 'Sudah bersih');
      },
    );

    test('an empty exception falls back to a generic message', () {
      expect(
        ErrorHelper.parseError(Exception('')),
        'Terjadi kesalahan yang tidak diketahui.',
      );
    });

    test('unknown objects get the generic message', () {
      expect(
        ErrorHelper.parseError(42),
        'Terjadi kesalahan yang tidak diketahui.',
      );
    });

    test('takes the message of a backend error response', () {
      final request = RequestOptions(path: '/x');
      final error = DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: request,
          statusCode: 409,
          data: <String, dynamic>{
            'status': 'error',
            'message': 'Anda sudah melakukan absensi untuk sesi ini',
          },
        ),
      );
      expect(
        ErrorHelper.parseError(error),
        'Anda sudah melakukan absensi untuk sesi ini',
      );
    });
  });

  // Some backend controllers still answer in English; the app words the ones a person can run into
  group('English server messages the app can word in Indonesian', () {
    DioException responseWith(String message, {int status = 400}) {
      final request = RequestOptions(path: '/x');
      return DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: request,
          statusCode: status,
          data: <String, dynamic>{'status': 'error', 'message': message},
        ),
      );
    }

    test('a backend error response', () {
      expect(
        ErrorHelper.parseError(responseWith('You can only edit your own posts', status: 403)),
        'Anda hanya dapat mengubah postingan Anda sendiri.',
      );
      expect(
        ErrorHelper.parseError(responseWith('Post not found', status: 404)),
        'Postingan tidak ditemukan.',
      );
      expect(
        ErrorHelper.parseError(responseWith('Already enrolled in this class', status: 400)),
        'Anda sudah terdaftar di kelas ini.',
      );
    });

    test('an exception or a string carrying the message (what the services rethrow)', () {
      expect(
        ErrorHelper.parseError(Exception('Parkiran not found')),
        'Parkiran tidak ditemukan.',
      );
      expect(
        ErrorHelper.parseError('Exception: User account is deactivated'),
        'Akun Anda telah dinonaktifkan.',
      );
    });

    test('an Indonesian or unknown message is shown as it is', () {
      expect(
        ErrorHelper.parseError(responseWith('Kelas tidak ditemukan', status: 404)),
        'Kelas tidak ditemukan',
      );
      expect(
        ErrorHelper.parseError(responseWith('Something the app has never heard of')),
        'Something the app has never heard of',
      );
    });

    test('no mapped text is English or empty', () {
      for (final MapEntry<String, String> entry in serverMessagesId.entries) {
        expect(entry.value, isNotEmpty, reason: entry.key);
        expect(entry.value, isNot(entry.key), reason: entry.key);
        expect(entry.value, endsWith('.'), reason: entry.key);
      }
    });
  });
}
