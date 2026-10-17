import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/kendaraan_helper.dart';

void main() {
  group('kendaraanErrorMessage', () {
    test('passes through a server message that is already Indonesian', () {
      expect(
        kendaraanErrorMessage(Exception('Plat nomor sudah terdaftar')),
        'Plat nomor sudah terdaftar',
      );
    });

    test('translates the vehicle limit message and keeps the number', () {
      expect(
        kendaraanErrorMessage(
          Exception('User has reached the maximum limit of 3 vehicles'),
        ),
        'Anda telah mencapai batas maksimal 3 kendaraan.',
      );
    });

    test('translates missing photo messages', () {
      expect(
        kendaraanErrorMessage(
          Exception('Exactly 3 fotoKendaraan are required (you uploaded 2)'),
        ),
        'Lengkapi 3 foto kendaraan (depan, samping, belakang).',
      );
      expect(
        kendaraanErrorMessage(Exception('fotoSTNK is required')),
        'Foto STNK wajib dilampirkan.',
      );
    });

    test('current Indonesian vehicle limits and photo counts keep the same guidance', () {
      expect(
        kendaraanErrorMessage(
          Exception('Pengguna sudah mencapai batas maksimal 4 kendaraan'),
        ),
        'Anda telah mencapai batas maksimal 4 kendaraan.',
      );
      expect(
        kendaraanErrorMessage(
          Exception('Wajib melampirkan tepat 3 foto kendaraan (Anda mengunggah 2)'),
        ),
        'Lengkapi 3 foto kendaraan (depan, samping, belakang).',
      );
    });

    test('hides the service wrappers for network and unexpected errors', () {
      expect(
        kendaraanErrorMessage(Exception('Network error: Connection refused')),
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
      expect(
        kendaraanErrorMessage(Exception('Unexpected error: Exception: boom')),
        'Terjadi kesalahan. Silakan coba lagi.',
      );
    });

    test('never leaks the Exception prefix', () {
      expect(
        kendaraanErrorMessage(Exception('Data tidak valid')),
        'Data tidak valid',
      );
    });
  });
}
