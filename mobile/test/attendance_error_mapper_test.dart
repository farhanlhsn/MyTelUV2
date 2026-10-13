import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/attendance_error_mapper.dart';

void main() {
  group('mapAttendanceErrorMessage (current Indonesian backend messages)', () {
    test('null and empty messages get a generic text', () {
      expect(mapAttendanceErrorMessage(null), 'Terjadi kesalahan');
      expect(mapAttendanceErrorMessage('   '), 'Terjadi kesalahan');
    });

    test('face service messages (translateFaceServiceError)', () {
      expect(
        mapAttendanceErrorMessage('Tidak ada wajah yang terdeteksi pada foto.'),
        'Wajah tidak terdeteksi. Pastikan wajah terlihat jelas dan pencahayaan cukup.',
      );
      expect(
        mapAttendanceErrorMessage(
          'Wajah tidak terdeteksi pada foto. Pastikan wajah terlihat jelas dan pencahayaan cukup.',
        ),
        'Wajah tidak terdeteksi. Pastikan wajah terlihat jelas dan pencahayaan cukup.',
      );
      expect(
        mapAttendanceErrorMessage(
          'Terdeteksi lebih dari satu wajah. Gunakan foto yang hanya berisi satu wajah.',
        ),
        'Terdeteksi lebih dari satu wajah. Pastikan hanya wajah Anda yang terlihat.',
      );
      expect(
        mapAttendanceErrorMessage(
          'Gagal mendeteksi wajah. Coba ambil foto ulang.',
        ),
        'Gagal mendeteksi wajah. Coba ambil foto ulang.',
      );
      expect(
        mapAttendanceErrorMessage(
          'Gagal mencocokkan wajah. Silakan coba lagi.',
        ),
        'Gagal mencocokkan wajah. Silakan coba lagi.',
      );
      expect(
        mapAttendanceErrorMessage(
          'Layanan pengenalan wajah mengalami gangguan. Silakan coba lagi.',
        ),
        'Layanan pengenalan wajah sedang tidak tersedia. Silakan coba beberapa saat lagi.',
      );
      expect(
        mapAttendanceErrorMessage(
          'Layanan pengenalan wajah sedang tidak tersedia. Silakan coba beberapa saat lagi.',
        ),
        'Layanan pengenalan wajah sedang tidak tersedia. Silakan coba beberapa saat lagi.',
      );
      expect(
        mapAttendanceErrorMessage('Layanan pengenalan wajah tidak tersedia'),
        'Layanan pengenalan wajah sedang tidak tersedia. Silakan coba beberapa saat lagi.',
      );
      expect(
        mapAttendanceErrorMessage('Wajah tidak cocok'),
        'Wajah tidak cocok dengan data terdaftar.',
      );
    });

    test('photo and coordinate input messages', () {
      expect(
        mapAttendanceErrorMessage('File gambar wajib diisi'),
        'Silakan ambil foto terlebih dahulu.',
      );
      expect(
        mapAttendanceErrorMessage('Foto wajah wajib diunggah.'),
        'Silakan ambil foto terlebih dahulu.',
      );
      expect(
        mapAttendanceErrorMessage('Koordinat tidak valid'),
        'Lokasi tidak valid. Pastikan GPS aktif lalu coba lagi.',
      );
      // the GPS endpoint still answers in English for this one
      expect(
        mapAttendanceErrorMessage('Invalid coordinates'),
        'Lokasi tidak valid. Pastikan GPS aktif lalu coba lagi.',
      );
    });

    test('mock location and liveness token', () {
      expect(
        mapAttendanceErrorMessage(
          'Mock location / GPS spoofing terdeteksi. Absensi ditolak.',
        ),
        'Lokasi palsu (mock location) terdeteksi. Nonaktifkan aplikasi lokasi palsu lalu coba lagi.',
      );
      expect(
        mapAttendanceErrorMessage(
          'Token liveness tidak valid atau sudah kadaluarsa. Silakan ulangi verifikasi wajah.',
        ),
        'Verifikasi wajah sudah kedaluwarsa. Silakan ulangi verifikasi wajah.',
      );
    });

    test('enrolment and session messages', () {
      expect(
        mapAttendanceErrorMessage(
          'Anda belum terdaftar biometrik. Hubungi admin untuk pendaftaran.',
        ),
        'Anda belum terdaftar biometrik. Hubungi admin.',
      );
      expect(
        mapAttendanceErrorMessage('Anda tidak terdaftar di kelas manapun'),
        'Anda tidak terdaftar di kelas manapun',
      );
      expect(
        mapAttendanceErrorMessage(
          'id_sesi_absensi wajib diisi untuk absensi biometrik. Silakan pilih sesi absensi terlebih dahulu.',
        ),
        'Konteks sesi absensi tidak tersedia. Silakan pilih sesi absensi dari daftar absensi.',
      );
      expect(
        mapAttendanceErrorMessage(
          'Sesi absensi yang dipilih tidak valid, tidak sedang berlangsung, atau Anda tidak terdaftar di kelas tersebut',
        ),
        'Sesi absensi tidak valid, tidak sedang berlangsung, atau Anda tidak terdaftar.',
      );
      expect(
        mapAttendanceErrorMessage(
          'Sesi absensi tidak ditemukan atau sudah ditutup',
        ),
        'Sesi absensi tidak ditemukan atau sudah ditutup.',
      );
      expect(
        mapAttendanceErrorMessage('Di luar waktu absensi'),
        'Di luar waktu absensi.',
      );
      expect(
        mapAttendanceErrorMessage('Not enrolled in this class'),
        'Anda tidak terdaftar di kelas ini.',
      );
      expect(
        mapAttendanceErrorMessage(
          'Sesi ini membutuhkan verifikasi wajah. Gunakan fitur absen biometrik.',
        ),
        'Sesi ini membutuhkan verifikasi wajah. Gunakan fitur absen biometrik.',
      );
    });

    test('duplicate attendance (both backend wordings)', () {
      expect(
        mapAttendanceErrorMessage('Anda sudah melakukan absensi pada sesi ini'),
        'Anda sudah melakukan absensi pada sesi ini.',
      );
      expect(
        mapAttendanceErrorMessage(
          'Anda sudah melakukan absensi untuk sesi ini',
        ),
        'Anda sudah melakukan absensi pada sesi ini.',
      );
    });

    test('geofence rejection keeps the distance detail', () {
      const withDistance =
          'Lokasi Anda di luar area absensi. Jarak: 245m, Radius: 100m';
      expect(mapAttendanceErrorMessage(withDistance), withDistance);

      const gpsWithDistance =
          'Lokasi di luar area absensi. Jarak: 245 m, Radius: 100 m';
      expect(mapAttendanceErrorMessage(gpsWithDistance), gpsWithDistance);

      expect(
        mapAttendanceErrorMessage('Lokasi Anda di luar area absensi'),
        'Lokasi Anda di luar area absensi. Silakan mendekat ke area kelas.',
      );
      expect(
        mapAttendanceErrorMessage('Lokasi di luar area absensi'),
        'Lokasi Anda di luar area absensi. Silakan mendekat ke area kelas.',
      );
    });

    test('server error and unknown messages', () {
      expect(
        mapAttendanceErrorMessage('Terjadi kesalahan pada server'),
        'Terjadi kesalahan pada server. Silakan coba lagi nanti.',
      );
      // fallback: an unknown (already Indonesian) message is shown as it is
      expect(
        mapAttendanceErrorMessage('Anda tidak terdaftar di kelas manapun'),
        'Anda tidak terdaftar di kelas manapun',
      );
    });

    test(
      'suspicious-activity rejection (contains "mock location") is not read as a mock-location one',
      () {
        const friendly =
            'Aktivitas lokasi tidak wajar terdeteksi. Pastikan GPS asli aktif lalu coba lagi.';
        // full backend string, biometrik and akademik endpoint
        expect(
          mapAttendanceErrorMessage(
            'Aktivitas absensi mencurigakan terdeteksi (mock location / spoofing).',
          ),
          friendly,
        );
        expect(
          mapAttendanceErrorMessage(
            'Exception: Aktivitas absensi mencurigakan terdeteksi (mock location / spoofing).',
          ),
          friendly,
        );
        // the plain mock-location rejection keeps its own text
        expect(
          mapAttendanceErrorMessage(
            'Mock location / GPS spoofing terdeteksi. Absensi ditolak.',
          ),
          'Lokasi palsu (mock location) terdeteksi. Nonaktifkan aplikasi lokasi palsu lalu coba lagi.',
        );
      },
    );

    test('matching is case-insensitive and ignores an Exception prefix', () {
      expect(
        mapAttendanceErrorMessage('Exception: WAJAH TIDAK COCOK'),
        'Wajah tidak cocok dengan data terdaftar.',
      );
      expect(
        mapAttendanceErrorMessage('Exception: Pesan baru yang belum dikenal'),
        'Pesan baru yang belum dikenal',
      );
    });
  });
}
