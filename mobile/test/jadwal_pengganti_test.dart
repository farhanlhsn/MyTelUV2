import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/akademik_service.dart';
import 'package:mobile/utils/error_helper.dart';
import 'package:mobile/utils/jadwal_pengganti_helper.dart';

import 'support/stub_http_adapter.dart';

AkademikService _service(StubHttpAdapter adapter) => AkademikService(dio: adapter.dio());

Map<String, dynamic> _created() => <String, dynamic>{
  'status': 'success',
  'message': 'Jadwal pengganti berhasil dibuat',
  'data': <String, dynamic>{'id_jadwal_pengganti': 4},
};

void main() {
  group('AkademikService.createJadwalPengganti', () {
    test('posts to the class route; the class id is not in the body', () async {
      final adapter = StubHttpAdapter(201, _created());

      final bool ok = await _service(adapter).createJadwalPengganti(
        idKelas: 3,
        tanggalAsli: DateTime(2026, 10, 14),
        status: 'LIBUR',
        alasan: 'Dosen dinas luar',
      );

      expect(ok, isTrue);
      final request = adapter.lastRequest!;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/akademik/kelas/3/jadwal-pengganti');
      final Map<String, dynamic> body = request.data as Map<String, dynamic>;
      expect(body.containsKey('id_kelas'), isFalse);
      expect(body, <String, dynamic>{
        'tanggal_asli': '2026-10-14T00:00:00.000',
        'status': 'LIBUR',
        'alasan': 'Dosen dinas luar',
      });
    });

    test('GANTI_JADWAL sends the new date, room and both times as HH:MM', () async {
      final adapter = StubHttpAdapter(201, _created());

      await _service(adapter).createJadwalPengganti(
        idKelas: 3,
        tanggalAsli: DateTime(2026, 10, 14),
        status: 'GANTI_JADWAL',
        alasan: 'Bentrok seminar',
        tanggalGanti: DateTime(2026, 10, 16),
        ruanganGanti: 'B203',
        jamMulaiGanti: '13:00',
        jamBerakhirGanti: '15:30',
      );

      final Map<String, dynamic> body =
          adapter.lastRequest!.data as Map<String, dynamic>;
      expect(body.containsKey('id_kelas'), isFalse);
      expect(body['status'], 'GANTI_JADWAL');
      expect(body['tanggal_ganti'], '2026-10-16T00:00:00.000');
      expect(body['ruangan_ganti'], 'B203');
      expect(body['jam_mulai_ganti'], '13:00');
      expect(body['jam_berakhir_ganti'], '15:30');
    });

    test('without times, no jam fields are sent', () async {
      final adapter = StubHttpAdapter(201, _created());

      await _service(adapter).createJadwalPengganti(
        idKelas: 3,
        tanggalAsli: DateTime(2026, 10, 14),
        status: 'GANTI_JADWAL',
        alasan: 'Pindah hari',
        tanggalGanti: DateTime(2026, 10, 16),
      );

      final Map<String, dynamic> body =
          adapter.lastRequest!.data as Map<String, dynamic>;
      expect(body.containsKey('jam_mulai_ganti'), isFalse);
      expect(body.containsKey('jam_berakhir_ganti'), isFalse);
      expect(body.containsKey('ruangan_ganti'), isFalse);
    });

    test('the 400 message of the server is what the user reads', () async {
      final adapter = StubHttpAdapter(400, <String, dynamic>{
        'status': 'error',
        'message': 'Tanggal asli harus jatuh pada hari Rabu sesuai jadwal kelas',
      });

      Object? caught;
      try {
        await _service(adapter).createJadwalPengganti(
          idKelas: 3,
          tanggalAsli: DateTime(2026, 10, 15),
          status: 'LIBUR',
          alasan: 'Libur',
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(
        ErrorHelper.parseError(caught),
        'Tanggal asli harus jatuh pada hari Rabu sesuai jadwal kelas',
      );
    });

    test('a 400 about the times is shown without an English prefix', () async {
      final adapter = StubHttpAdapter(400, <String, dynamic>{
        'status': 'error',
        'message': 'Jam berakhir harus setelah jam mulai',
      });

      Object? caught;
      try {
        await _service(adapter).createJadwalPengganti(
          idKelas: 3,
          tanggalAsli: DateTime(2026, 10, 14),
          status: 'GANTI_JADWAL',
          alasan: 'Pindah',
          tanggalGanti: DateTime(2026, 10, 16),
          jamMulaiGanti: '15:00',
          jamBerakhirGanti: '14:00',
        );
      } catch (e) {
        caught = e;
      }

      final String shown = ErrorHelper.parseError(caught);
      expect(shown, 'Jam berakhir harus setelah jam mulai');
      expect(shown, isNot(contains('Failed')));
    });
  });

  group('formatJamHHmm', () {
    test('zero-pads hour and minute', () {
      expect(formatJamHHmm(const TimeOfDay(hour: 8, minute: 5)), '08:05');
      expect(formatJamHHmm(const TimeOfDay(hour: 0, minute: 0)), '00:00');
      expect(formatJamHHmm(const TimeOfDay(hour: 15, minute: 30)), '15:30');
    });
  });

  group('validateJamGanti', () {
    test('neither time chosen is fine: the original times stay', () {
      expect(validateJamGanti(null, null), isNull);
    });

    test('only one of the two is an error that names the missing one', () {
      expect(
        validateJamGanti(const TimeOfDay(hour: 8, minute: 0), null),
        'Pilih jam berakhir',
      );
      expect(
        validateJamGanti(null, const TimeOfDay(hour: 10, minute: 0)),
        'Pilih jam mulai',
      );
    });

    test('end must be after start', () {
      const message = 'Jam berakhir harus setelah jam mulai';
      expect(
        validateJamGanti(
          const TimeOfDay(hour: 10, minute: 0),
          const TimeOfDay(hour: 9, minute: 0),
        ),
        message,
      );
      expect(
        validateJamGanti(
          const TimeOfDay(hour: 10, minute: 0),
          const TimeOfDay(hour: 10, minute: 0),
        ),
        message,
      );
    });

    test('a later end, even by one minute, is valid', () {
      expect(
        validateJamGanti(
          const TimeOfDay(hour: 10, minute: 0),
          const TimeOfDay(hour: 10, minute: 1),
        ),
        isNull,
      );
    });
  });
}
