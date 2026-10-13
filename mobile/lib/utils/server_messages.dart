/// Error messages some backend controllers still answer with in English, worded in Indonesian for the
/// person who runs into them. Matched exactly (after trimming); a message that is not here (the
/// backend answers in Indonesian for almost everything) is shown as it is. Whatever the backend
/// controllers get translated to, these simply stop matching.
const Map<String, String> serverMessagesId = <String, String>{
  // Kendaraan
  'fotoSTNK is required': 'Foto STNK wajib dilampirkan.',
  'Feedback is required when rejecting': 'Alasan penolakan wajib diisi.',
  'Only rejected vehicles can be resubmitted':
      'Hanya kendaraan yang ditolak yang dapat diajukan ulang.',
  'If updating vehicle photos, you must provide exactly 3 photos':
      'Jika mengubah foto kendaraan, lampirkan tepat 3 foto.',
  'Cannot reject already approved kendaraan':
      'Kendaraan yang sudah disetujui tidak dapat ditolak.',

  // Akun
  'User account is deactivated': 'Akun Anda telah dinonaktifkan.',
  'Invalid refresh token': 'Sesi tidak valid. Silakan login kembali.',
  'Nama is required': 'Nama wajib diisi.',
  'Profile picture image is required': 'Foto profil wajib diunggah.',
  'User not found or already deactivated':
      'Pengguna tidak ditemukan atau sudah dinonaktifkan.',
  'User not found or already active': 'Pengguna tidak ditemukan atau sudah aktif.',
  'Cannot deactivate yourself': 'Anda tidak dapat menonaktifkan akun sendiri.',

  // Parkir
  'No parking history found': 'Belum ada riwayat parkir.',
  'Nama parkiran is required': 'Nama parkiran wajib diisi.',
  'Nama parkiran already exists': 'Nama parkiran sudah digunakan.',
  'Kapasitas must be a positive number': 'Kapasitas harus berupa angka positif.',
  'Latitude and longitude are required': 'Latitude dan longitude wajib diisi.',
  'Latitude must be a valid number between -90 and 90':
      'Latitude harus berupa angka antara -90 dan 90.',
  'Longitude must be a valid number between -180 and 180':
      'Longitude harus berupa angka antara -180 dan 180.',
  'Invalid ID format': 'Format ID tidak valid.',
  'Parkiran not found': 'Parkiran tidak ditemukan.',

  // Akademik
  'Invalid time format. Use HH:MM:SS format (e.g., 08:00:00)':
      'Format jam tidak valid. Gunakan format HH:MM:SS (contoh: 08:00:00).',
  'Only Admin can perform this action': 'Hanya admin yang dapat melakukan tindakan ini.',
  'You are not authorized to view this class details':
      'Anda tidak berhak melihat detail kelas ini.',
  'Not authorized for this class': 'Anda tidak berwenang untuk kelas ini.',
  'You can only update your own classes': 'Anda hanya dapat mengubah kelas Anda sendiri.',
  'You can only delete your own classes': 'Anda hanya dapat menghapus kelas Anda sendiri.',
  'You can only close sesi for your own classes':
      'Anda hanya dapat menutup sesi kelas Anda sendiri.',
  'You can only view sesi for your own classes':
      'Anda hanya dapat melihat sesi kelas Anda sendiri.',
  'You can only view absensi for your own classes':
      'Anda hanya dapat melihat absensi kelas Anda sendiri.',
  'You can only view statistics for your own classes':
      'Anda hanya dapat melihat statistik kelas Anda sendiri.',
  'You can only view detail for your own classes':
      'Anda hanya dapat melihat detail kelas Anda sendiri.',
  'Cannot delete matakuliah with active kelas. Delete or archive the kelas first.':
      'Matakuliah yang masih memiliki kelas aktif tidak dapat dihapus.',
  'Already enrolled in this class': 'Anda sudah terdaftar di kelas ini.',
  'Not enrolled in this class': 'Anda tidak terdaftar di kelas ini.',
  'id_kelas and id_mahasiswa are required': 'Kelas dan mahasiswa wajib dipilih.',
  'No mahasiswa IDs provided': 'Pilih minimal satu mahasiswa.',
  'Invalid coordinates': 'Lokasi tidak valid. Pastikan GPS aktif lalu coba lagi.',
  'Radius must be positive': 'Radius harus lebih dari 0.',

  // Postingan
  'Post not found': 'Postingan tidak ditemukan.',
  'Content is required': 'Isi postingan wajib diisi.',
  'You can only edit your own posts': 'Anda hanya dapat mengubah postingan Anda sendiri.',
  'You can only delete your own posts': 'Anda hanya dapat menghapus postingan Anda sendiri.',
  'Comment content is required': 'Isi komentar wajib diisi.',
  'Comment not found': 'Komentar tidak ditemukan.',
  'You can only delete your own comments': 'Anda hanya dapat menghapus komentar Anda sendiri.',
};

/// [message] worded in Indonesian when it is one of the known English server messages, else as it is.
String translateServerMessage(String message) =>
    serverMessagesId[message.trim()] ?? message;
