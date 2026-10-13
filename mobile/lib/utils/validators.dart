/// Client-side form validators shared by the auth, vehicle and attendance forms.
///
/// Every validator has the `FormFieldValidator<String>` shape (returns an Indonesian error
/// message, or null when the value is acceptable) so it can be passed straight to a
/// `TextFormField`. The rules mirror the backend Zod schemas, so a value that passes here is not
/// bounced by the server.
class Validators {
  Validators._();

  /// Indonesian plate: 1-2 region letters, 1-4 digits, 0-3 suffix letters, optional single spaces.
  /// Matched against the trimmed value; the input field uppercases while typing.
  static final RegExp _platPattern = RegExp(
    r'^[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{0,3}$',
  );

  /// Same rule as the server: starts with a letter, then letters, digits or underscore.
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  /// NIM of a student: 11 or 12 digits (public registration is MAHASISWA only).
  static final RegExp _nimPattern = RegExp(r'^\d{11,12}$');

  /// NIP / NIDN of a lecturer or admin: the server accepts 8-20 digits (an 18 digit NIP fits).
  static final RegExp _nipPattern = RegExp(r'^\d{8,20}$');

  static const int minPasswordLength = 8;
  static const int minDurasiMenit = 1;
  static const int maxDurasiMenit = 240;

  static String? platNomor(String? value) {
    final String plat = value?.trim() ?? '';
    if (plat.isEmpty) return 'Plat nomor wajib diisi';
    if (!_platPattern.hasMatch(plat)) {
      return 'Format plat nomor tidak valid. Contoh: D 1234 ABC';
    }
    return null;
  }

  static String? nama(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nama wajib diisi';
    return null;
  }

  /// 3-30 characters, starting with a letter; letters, digits and underscore only.
  static String? username(String? value) {
    final String username = value?.trim() ?? '';
    if (username.isEmpty) return 'Username wajib diisi';
    if (username.length < 3) return 'Username minimal 3 karakter';
    if (username.length > 30) return 'Username maksimal 30 karakter';
    if (!_usernamePattern.hasMatch(username)) {
      return 'Username harus diawali huruf dan hanya boleh berisi huruf, angka, dan underscore';
    }
    return null;
  }

  static String? namaKendaraan(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama kendaraan wajib diisi';
    }
    return null;
  }

  /// At least 8 characters with a letter and a digit (same rule as the server).
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';
    if (value.length < minPasswordLength) {
      return 'Password minimal $minPasswordLength karakter';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
      return 'Password harus mengandung huruf dan angka';
    }
    return null;
  }

  static String? confirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) return 'Konfirmasi password wajib diisi';
    if (value != password) return 'Konfirmasi password tidak cocok';
    return null;
  }

  /// Optional. A student's NIM has 11-12 digits; for DOSEN / ADMIN the NIP / NIDN has 8-20.
  static String? nimNip(String? value, {String role = 'MAHASISWA'}) {
    final String nomor = value?.trim() ?? '';
    if (nomor.isEmpty) return null;
    if (role == 'MAHASISWA') {
      return _nimPattern.hasMatch(nomor) ? null : 'NIM harus 11 atau 12 digit angka';
    }
    return _nipPattern.hasMatch(nomor)
        ? null
        : 'NIP/NIDN harus 8 sampai 20 digit angka';
  }

  /// Optional.
  static String? email(String? value) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    return _emailPattern.hasMatch(email) ? null : 'Format email tidak valid';
  }

  /// Length of an attendance session in minutes: a whole number from 1 to 240.
  static String? durasiMenit(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return 'Durasi wajib diisi';
    final int? menit = int.tryParse(text);
    if (menit == null) return 'Durasi harus berupa angka';
    if (menit < minDurasiMenit || menit > maxDurasiMenit) {
      return 'Durasi harus antara $minDurasiMenit dan $maxDurasiMenit menit';
    }
    return null;
  }

  /// Whether [input] is the exact word the user must type to confirm a destructive action.
  static bool matchesConfirmation(String? input, {String keyword = 'HAPUS'}) {
    return input?.trim() == keyword;
  }
}
