import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/dosen_service.dart';
import 'package:mobile/utils/error_helper.dart';

import 'support/stub_http_adapter.dart';

Map<String, dynamic> _updatedRow({String status = 'IZIN', String? keterangan}) =>
    <String, dynamic>{
      'status': 'success',
      'message': 'Status kehadiran berhasil diperbarui',
      'data': <String, dynamic>{
        'id_absensi': 77,
        'id_user': 10,
        'id_kelas': 3,
        'id_sesi_absensi': 12,
        'status': status,
        'keterangan': keterangan,
        'diubah_oleh': 5,
      },
    };

void main() {
  group('DosenService.overrideAbsensi', () {
    test('PUTs the status to the session/student path', () async {
      final adapter = StubHttpAdapter(200, _updatedRow());
      final service = DosenService(dio: adapter.dio());

      await service.overrideAbsensi(idSesi: 12, idUser: 10, status: 'IZIN');

      final RequestOptions request = adapter.lastRequest!;
      expect(request.method, 'PUT');
      expect(request.path, '/api/v1/akademik/absensi/sesi/12/mahasiswa/10');
      expect(request.data, <String, dynamic>{'status': 'IZIN'});
    });

    test('sends keterangan trimmed when there is one', () async {
      final adapter = StubHttpAdapter(
        200,
        _updatedRow(keterangan: 'Surat izin orang tua'),
      );
      final service = DosenService(dio: adapter.dio());

      await service.overrideAbsensi(
        idSesi: 12,
        idUser: 10,
        status: 'IZIN',
        keterangan: '  Surat izin orang tua  ',
      );

      expect(adapter.lastRequest!.data, <String, dynamic>{
        'status': 'IZIN',
        'keterangan': 'Surat izin orang tua',
      });
    });

    test('a blank keterangan is left out, so the server clears the old one', () async {
      final adapter = StubHttpAdapter(200, _updatedRow(status: 'HADIR'));
      final service = DosenService(dio: adapter.dio());

      await service.overrideAbsensi(
        idSesi: 12,
        idUser: 10,
        status: 'HADIR',
        keterangan: '   ',
      );

      expect(adapter.lastRequest!.data, <String, dynamic>{'status': 'HADIR'});
    });

    test('returns the updated absensi row', () async {
      final adapter = StubHttpAdapter(
        200,
        _updatedRow(status: 'SAKIT', keterangan: 'Demam'),
      );
      final service = DosenService(dio: adapter.dio());

      final Map<String, dynamic> row = await service.overrideAbsensi(
        idSesi: 12,
        idUser: 10,
        status: 'SAKIT',
        keterangan: 'Demam',
      );

      expect(row['status'], 'SAKIT');
      expect(row['keterangan'], 'Demam');
      expect(row['diubah_oleh'], 5);
    });

    test('a response without data gives an empty row instead of crashing', () async {
      final adapter = StubHttpAdapter(200, <String, dynamic>{'status': 'success'});
      final service = DosenService(dio: adapter.dio());

      final row = await service.overrideAbsensi(idSesi: 12, idUser: 10, status: 'ALPHA');

      expect(row, isEmpty);
    });

    test('403 from the server reaches the caller with the Indonesian message', () async {
      final adapter = StubHttpAdapter(403, <String, dynamic>{
        'status': 'error',
        'message': 'Anda hanya dapat mengubah kehadiran pada kelas yang Anda ajar',
      });
      final service = DosenService(dio: adapter.dio());

      Object? caught;
      try {
        await service.overrideAbsensi(idSesi: 12, idUser: 10, status: 'IZIN');
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<DioException>());
      expect(
        ErrorHelper.parseError(caught),
        'Anda hanya dapat mengubah kehadiran pada kelas yang Anda ajar',
      );
    });

    test('404 (not enrolled) keeps the server message', () async {
      final adapter = StubHttpAdapter(404, <String, dynamic>{
        'status': 'error',
        'message': 'Mahasiswa tidak terdaftar di kelas ini',
      });
      final service = DosenService(dio: adapter.dio());

      await expectLater(
        service.overrideAbsensi(idSesi: 12, idUser: 10, status: 'IZIN'),
        throwsA(
          predicate(
            (Object e) =>
                ErrorHelper.parseError(e) == 'Mahasiswa tidak terdaftar di kelas ini',
          ),
        ),
      );
    });
  });
}
