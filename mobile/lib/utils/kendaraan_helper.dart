import 'error_helper.dart';

/// Turns whatever a vehicle submission threw into one Indonesian sentence for the user.
///
/// `KendaraanService` wraps failures in plain `Exception`s whose text is either the server's own
/// message or a technical prefix ("Network error: ...", "Unexpected error: ..."); a few server
/// messages are still English. The user should see neither the Dart wrapper nor the English text.
String kendaraanErrorMessage(Object error) {
  final String message = ErrorHelper.parseError(error);

  final RegExpMatch? limit = RegExp(
    r'maximum limit of (\d+)',
    caseSensitive: false,
  ).firstMatch(message);
  if (limit != null) {
    return 'Anda telah mencapai batas maksimal ${limit.group(1)} kendaraan.';
  }
  if (message.startsWith('Exactly 3 fotoKendaraan')) {
    return 'Lengkapi 3 foto kendaraan (depan, samping, belakang).';
  }
  if (message.startsWith('fotoSTNK is required')) {
    return 'Foto STNK wajib dilampirkan.';
  }
  if (message.startsWith('Network error')) {
    return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
  }
  if (message.startsWith('Unexpected error')) {
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
  return message;
}
