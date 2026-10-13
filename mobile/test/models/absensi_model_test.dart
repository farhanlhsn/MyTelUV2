import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/absensi.dart';

Map<String, dynamic> _row({Map<String, dynamic>? extra}) => <String, dynamic>{
  'id_absensi': 77,
  'id_user': 10,
  'id_kelas': 3,
  'id_sesi_absensi': 12,
  'type_absensi': 'REMOTE_ABSENSI',
  'createdAt': '2026-10-14T01:00:00.000Z',
  'updatedAt': '2026-10-14T02:00:00.000Z',
  ...?extra,
};

void main() {
  group('AbsensiModel.fromJson status', () {
    test('a row without status (old data) is HADIR with no note', () {
      final AbsensiModel absensi = AbsensiModel.fromJson(_row());

      expect(absensi.status, 'HADIR');
      expect(absensi.keterangan, isNull);
      expect(absensi.diubahOleh, isNull);
    });

    test('a null status is HADIR too', () {
      expect(AbsensiModel.fromJson(_row(extra: {'status': null})).status, 'HADIR');
    });

    test('parses status, keterangan and diubah_oleh from an override response', () {
      final AbsensiModel absensi = AbsensiModel.fromJson(
        _row(
          extra: {'status': 'IZIN', 'keterangan': 'Surat izin orang tua', 'diubah_oleh': 5},
        ),
      );

      expect(absensi.idAbsensi, 77);
      expect(absensi.idKelas, 3);
      expect(absensi.status, 'IZIN');
      expect(absensi.keterangan, 'Surat izin orang tua');
      expect(absensi.diubahOleh, 5);
    });

    test('every server status survives parsing', () {
      for (final String status in <String>['HADIR', 'TELAT', 'IZIN', 'SAKIT', 'ALPHA']) {
        expect(AbsensiModel.fromJson(_row(extra: {'status': status})).status, status);
      }
    });

    test('a lower-case status is normalised', () {
      expect(AbsensiModel.fromJson(_row(extra: {'status': 'telat'})).status, 'TELAT');
    });

    test('an unknown status falls back to HADIR instead of leaking into the UI', () {
      expect(AbsensiModel.fromJson(_row(extra: {'status': 'BOLOS'})).status, 'HADIR');
    });

    test('a blank keterangan is no keterangan', () {
      expect(AbsensiModel.fromJson(_row(extra: {'keterangan': '   '})).keterangan, isNull);
      expect(AbsensiModel.fromJson(_row(extra: {'keterangan': ''})).keterangan, isNull);
    });

    test('the type of check-in is not confused with the status', () {
      final AbsensiModel absensi = AbsensiModel.fromJson(_row(extra: {'status': 'SAKIT'}));

      expect(absensi.typeAbsensi, 'REMOTE_ABSENSI');
      expect(absensi.status, 'SAKIT');
    });

    test('toJson keeps the status fields', () {
      final AbsensiModel absensi = AbsensiModel.fromJson(
        _row(extra: {'status': 'ALPHA', 'keterangan': 'Tanpa kabar', 'diubah_oleh': 9}),
      );

      final Map<String, dynamic> json = absensi.toJson();

      expect(json['status'], 'ALPHA');
      expect(json['keterangan'], 'Tanpa kabar');
      expect(json['diubah_oleh'], 9);
      expect(AbsensiModel.fromJson(json).status, 'ALPHA');
    });

    test('the const constructor still defaults to HADIR', () {
      final AbsensiModel absensi = AbsensiModel(
        idAbsensi: 1,
        idKelas: 1,
        idMahasiswa: 1,
        typeAbsensi: 'LOKAL_ABSENSI',
        tanggalAbsensi: DateTime.utc(2026, 10, 14),
      );

      expect(absensi.status, 'HADIR');
      expect(absensi.keterangan, isNull);
    });
  });

  group('AbsensiStatsModel', () {
    test('TELAT counts as present and IZIN/SAKIT leave the denominator', () {
      // present 3 + 1 late = 4, countable 4 + 1 alpha = 5 (3 excused are left out) -> 80%
      final AbsensiStatsModel stats = AbsensiStatsModel.fromJson(<String, dynamic>{
        'HADIR': 3,
        'TELAT': 1,
        'IZIN': 2,
        'SAKIT': 1,
        'ALPHA': 1,
      });

      expect(stats.totalHadir, 3);
      expect(stats.totalTelat, 1);
      expect(stats.totalIzin, 2);
      expect(stats.totalSakit, 1);
      expect(stats.totalAlpha, 1);
      expect(stats.totalDihitung, 5);
      expect(stats.persentaseKehadiran, 80.0);
    });

    test('only excused records: 0%, not 100%', () {
      final AbsensiStatsModel stats = AbsensiStatsModel.fromJson(<String, dynamic>{
        'IZIN': 2,
        'SAKIT': 1,
      });

      expect(stats.totalDihitung, 0);
      expect(stats.persentaseKehadiran, 0.0);
    });

    test('no records at all: 0%', () {
      expect(AbsensiStatsModel.fromJson(<String, dynamic>{}).persentaseKehadiran, 0.0);
    });

    test('toJson writes the new keys', () {
      final Map<String, dynamic> json = AbsensiStatsModel.fromJson(<String, dynamic>{
        'HADIR': 1,
        'TELAT': 1,
        'IZIN': 1,
        'SAKIT': 1,
        'ALPHA': 1,
      }).toJson();

      expect(json['HADIR'], 1);
      expect(json['TELAT'], 1);
      expect(json['IZIN'], 1);
      expect(json['SAKIT'], 1);
      expect(json['ALPHA'], 1);
      expect(json.containsKey('IJIN'), isFalse);
    });
  });
}
