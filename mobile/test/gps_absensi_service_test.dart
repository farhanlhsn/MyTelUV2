import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/akademik_service.dart';

/// Answers every request with a canned JSON body and remembers the request.
class _StubAdapter implements HttpClientAdapter {
  final int statusCode;
  final Map<String, dynamic> body;
  RequestOptions? lastRequest;

  _StubAdapter(this.statusCode, this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AkademikService _serviceAnswering(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
  dio.httpClientAdapter = adapter;
  return AkademikService(dio: dio);
}

void main() {
  group('AkademikService.createAbsensi (GPS-only attendance)', () {
    test('posts the session, the position and the mock flag', () async {
      final adapter = _StubAdapter(201, <String, dynamic>{
        'status': 'success',
        'message': 'Absensi recorded successfully',
        'data': <String, dynamic>{'id_absensi': 1, 'status': 'TELAT'},
      });

      final body = await _serviceAnswering(adapter).createAbsensi(
        idKelas: 4,
        idSesiAbsensi: 9,
        latitude: -6.97,
        longitude: 107.63,
        isMockLocation: true,
      );

      final request = adapter.lastRequest!;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/akademik/absensi');
      expect(request.data, <String, dynamic>{
        'id_kelas': 4,
        'id_sesi_absensi': 9,
        'latitude': -6.97,
        'longitude': 107.63,
        'is_mock_location': true,
      });
      expect(body['status'], 'success');
      expect((body['data'] as Map<String, dynamic>)['status'], 'TELAT');
    });

    test('is not a mock location unless the position says so', () async {
      final adapter = _StubAdapter(201, <String, dynamic>{'status': 'success'});

      await _serviceAnswering(adapter).createAbsensi(
        idKelas: 4,
        idSesiAbsensi: 9,
        latitude: -6.97,
        longitude: 107.63,
      );

      expect((adapter.lastRequest!.data as Map)['is_mock_location'], false);
    });

    test(
      'carries the backend message of a duplicate attendance (409)',
      () async {
        final adapter = _StubAdapter(409, <String, dynamic>{
          'status': 'error',
          'message': 'Anda sudah melakukan absensi untuk sesi ini',
        });

        expect(
          () => _serviceAnswering(adapter).createAbsensi(
            idKelas: 4,
            idSesiAbsensi: 9,
            latitude: -6.97,
            longitude: 107.63,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Anda sudah melakukan absensi untuk sesi ini'),
            ),
          ),
        );
      },
    );

    test('adds the distance to a geofence rejection (403)', () async {
      final adapter = _StubAdapter(403, <String, dynamic>{
        'status': 'error',
        'message': 'Lokasi di luar area absensi',
        'distance': 245,
        'required_radius': 100,
      });

      expect(
        () => _serviceAnswering(adapter).createAbsensi(
          idKelas: 4,
          idSesiAbsensi: 9,
          latitude: -6.97,
          longitude: 107.63,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Jarak: 245 m, Radius: 100 m'),
          ),
        ),
      );
    });
  });
}
