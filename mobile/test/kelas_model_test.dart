import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/kelas_hari_ini.dart';

void main() {
  group('KelasHariIniModel', () {
    test('jadwal getter should format time correctly', () {
      const model = KelasHariIniModel(
        idKelas: 1,
        namaKelas: 'IF-44-01',
        jamMulai: '08:00:00',
        jamBerakhir: '10:00:00',
      );

      expect(model.jadwal, '08:00 - 10:00');
    });

    test('jadwal getter should handle missing time', () {
      const model = KelasHariIniModel(
        idKelas: 1,
        namaKelas: 'IF-44-01',
        jamMulai: null,
        jamBerakhir: null,
      );

      expect(model.jadwal, 'Jadwal tidak tersedia');
    });

    test('fromJson should parse JSON correctly', () {
      final json = {
        'id_kelas': 1,
        'nama_kelas': 'IF-44-01',
        'ruangan': 'A101',
        'jam_mulai': '08:00:00',
        'jam_berakhir': '10:00:00',
        'jumlah_peserta': 30,
        'has_active_absensi': true,
        'active_sesi_absensi': {
          'id_sesi_absensi': 100,
          'id_kelas': 1,
          'type_absensi': 'MASUK',
          'mulai': '2025-01-01T08:00:00.000Z',
          'selesai': '2025-01-01T10:00:00.000Z',
          'status': true
        }
      };

      final model = KelasHariIniModel.fromJson(json);

      expect(model.idKelas, 1);
      expect(model.namaKelas, 'IF-44-01');
      expect(model.hasActiveAbsensi, true);
      expect(model.activeSesiAbsensi?.idSesiAbsensi, 100);
      expect(model.activeSesiAbsensi?.mulai.year, 2025);
    });
  });
}
