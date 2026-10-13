import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/error_helper.dart';

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
}
