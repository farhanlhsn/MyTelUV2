import 'error_helper.dart';

/// Friendly Indonesian texts for the messages the attendance endpoints answer with
/// (POST /biometrik/absen, which also relays translateFaceServiceError, and POST /akademik/absensi).
/// Keys are matched as lower-case substrings, the first match wins; an unknown message is shown as it
/// is (the backend already answers in Indonesian).
const List<(String, String)> _attendanceMessages = <(String, String)>[
  // Face service (backend/utils/faceServiceMessages.js)
  (
    'layanan pengenalan wajah',
    'Layanan pengenalan wajah sedang tidak tersedia. Silakan coba beberapa saat lagi.',
  ),
  (
    'lebih dari satu wajah',
    'Terdeteksi lebih dari satu wajah. Pastikan hanya wajah Anda yang terlihat.',
  ),
  ('gagal mencocokkan wajah', 'Gagal mencocokkan wajah. Silakan coba lagi.'),
  ('gagal mendeteksi wajah', 'Gagal mendeteksi wajah. Coba ambil foto ulang.'),
  (
    'tidak ada wajah yang terdeteksi',
    'Wajah tidak terdeteksi. Pastikan wajah terlihat jelas dan pencahayaan cukup.',
  ),
  (
    'wajah tidak terdeteksi',
    'Wajah tidak terdeteksi. Pastikan wajah terlihat jelas dan pencahayaan cukup.',
  ),
  ('wajah tidak cocok', 'Wajah tidak cocok dengan data terdaftar.'),

  // Input
  ('file gambar wajib diisi', 'Silakan ambil foto terlebih dahulu.'),
  ('foto wajah wajib diunggah', 'Silakan ambil foto terlebih dahulu.'),
  (
    'koordinat tidak valid',
    'Lokasi tidak valid. Pastikan GPS aktif lalu coba lagi.',
  ),
  (
    // POST /akademik/absensi still answers in English for this one
    'invalid coordinates',
    'Lokasi tidak valid. Pastikan GPS aktif lalu coba lagi.',
  ),
  (
    // must stay above 'mock location': the backend text is
    // "Aktivitas absensi mencurigakan terdeteksi (mock location / spoofing)."
    'aktivitas absensi mencurigakan',
    'Aktivitas lokasi tidak wajar terdeteksi. Pastikan GPS asli aktif lalu coba lagi.',
  ),
  (
    'mock location',
    'Lokasi palsu (mock location) terdeteksi. Nonaktifkan aplikasi lokasi palsu lalu coba lagi.',
  ),
  (
    'token liveness',
    'Verifikasi wajah sudah kedaluwarsa. Silakan ulangi verifikasi wajah.',
  ),

  // Enrolment / session
  (
    'belum terdaftar biometrik',
    'Anda belum terdaftar biometrik. Hubungi admin.',
  ),
  (
    'id_sesi_absensi wajib diisi',
    'Konteks sesi absensi tidak tersedia. Silakan pilih sesi absensi dari daftar absensi.',
  ),
  (
    'sesi absensi yang dipilih tidak valid',
    'Sesi absensi tidak valid, tidak sedang berlangsung, atau Anda tidak terdaftar.',
  ),
  (
    'sesi absensi tidak ditemukan',
    'Sesi absensi tidak ditemukan atau sudah ditutup.',
  ),
  ('di luar waktu absensi', 'Di luar waktu absensi.'),
  // POST /akademik/absensi still answers in English for these two
  ('not enrolled in this class', 'Anda tidak terdaftar di kelas ini.'),
  ('kelas not found', 'Kelas tidak ditemukan.'),
  ('sudah melakukan absensi', 'Anda sudah melakukan absensi pada sesi ini.'),
  (
    'terjadi kesalahan pada server',
    'Terjadi kesalahan pada server. Silakan coba lagi nanti.',
  ),
];

String mapAttendanceErrorMessage(String? message) {
  final text = ErrorHelper.stripExceptionPrefix(message ?? '');
  if (text.isEmpty) return 'Terjadi kesalahan';

  final lower = text.toLowerCase();

  // Geofence rejection: keep the distance detail when the server sent one
  if (lower.contains('di luar area absensi')) {
    if (lower.contains('jarak') || lower.contains('radius')) return text;
    return 'Lokasi Anda di luar area absensi. Silakan mendekat ke area kelas.';
  }

  for (final (key, friendly) in _attendanceMessages) {
    if (lower.contains(key)) return friendly;
  }
  return text;
}
