import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/kelas.dart';
import 'package:mobile/models/kelas_hari_ini.dart';
import 'package:mobile/models/matakuliah.dart';
import 'package:mobile/utils/kelas_helper.dart';

void main() {
  group('kelasIdOf', () {
    test('reads the id from a KelasModel', () {
      const kelas = KelasModel(idKelas: 7, namaKelas: 'IF-44-01');
      expect(kelasIdOf(kelas), 7);
    });

    test('reads the id from a Map (DOSEN kelas diampu)', () {
      expect(
        kelasIdOf(<String, dynamic>{'id_kelas': 12, 'nama_kelas': 'A'}),
        12,
      );
    });

    test('accepts numeric and string ids inside a Map', () {
      expect(kelasIdOf(<String, dynamic>{'id_kelas': 12.0}), 12);
      expect(kelasIdOf(<String, dynamic>{'id_kelas': '15'}), 15);
    });

    test('reads the id from a KelasHariIniModel', () {
      const kelas = KelasHariIniModel(idKelas: 3, namaKelas: 'IF-44-02');
      expect(kelasIdOf(kelas), 3);
    });

    test('returns null instead of throwing for unusable input', () {
      expect(kelasIdOf(null), isNull);
      expect(kelasIdOf('abc'), isNull);
      expect(kelasIdOf(<String, dynamic>{'nama_kelas': 'tanpa id'}), isNull);
      expect(kelasIdOf(<String, dynamic>{'id_kelas': 'bukan angka'}), isNull);
      expect(kelasIdOf(<String, dynamic>{'id_kelas': 0}), isNull);
    });
  });

  group('kelasHariIniTitle', () {
    test('uses the course name as the headline', () {
      const kelas = KelasHariIniModel(
        idKelas: 1,
        namaKelas: 'IF-44-01',
        matakuliah: MatakuliahModel(
          idMatakuliah: 1,
          namaMatakuliah: 'Pemrograman Web',
          kodeMatakuliah: 'CSH4A3',
        ),
      );
      expect(kelasHariIniTitle(kelas), 'Pemrograman Web');
    });

    test('falls back to the class name, then to "Kelas"', () {
      const named = KelasHariIniModel(idKelas: 1, namaKelas: 'IF-44-01');
      expect(kelasHariIniTitle(named), 'IF-44-01');

      const unnamed = KelasHariIniModel(idKelas: 1, namaKelas: '');
      expect(kelasHariIniTitle(unnamed), 'Kelas');
    });
  });
}
