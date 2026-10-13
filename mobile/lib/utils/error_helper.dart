import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:dio/dio.dart';

/// Utility class untuk menangani error secara konsisten di seluruh aplikasi
class ErrorHelper {
  /// Key of the app's ScaffoldMessenger (given to the GetMaterialApp in app.dart). The toasts are
  /// shown through it, not through `Get.snackbar`: GetX 4.7.2 looks its overlay up in a way current
  /// Flutter rejects ("No Overlay widget found"), and the failed snackbar then stays "open" in
  /// GetX's queue, so every later `Get.back()` only tries to close it and never leaves the page.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Menampilkan error dengan dialog yang jelas dan visible
  static void showError(dynamic error, {String title = 'Terjadi Kesalahan'}) {
    String message = parseError(error);

    if (Get.context == null) {
      debugPrint('Error dialog (no context): $title - $message');
      return;
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.error_outline, color: Colors.red.shade400, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Menampilkan dialog error dengan opsi retry
  static void showErrorWithRetry(
    dynamic error, {
    String title = 'Terjadi Kesalahan',
    required VoidCallback onRetry,
  }) {
    String message = parseError(error);

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.error_outline, color: Colors.red.shade400, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    onRetry();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE63946),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Parse error untuk mendapatkan pesan yang user-friendly
  static String parseError(dynamic error) {
    // Handle DioException
    if (error is DioException) {
      return _parseDioError(error);
    }

    // Handle Exception biasa
    if (error is Exception) {
      return _orUnknown(stripExceptionPrefix(error.toString()));
    }

    // Handle string langsung (mis. hasil e.toString() dari pemanggil)
    if (error is String) {
      return _orUnknown(stripExceptionPrefix(error));
    }

    return _unknownError;
  }

  static const String _unknownError = 'Terjadi kesalahan yang tidak diketahui.';

  static String _orUnknown(String message) =>
      message.isEmpty ? _unknownError : message;

  /// Menghapus awalan "Exception:" (juga yang bertumpuk, "Exception: Exception: ...")
  /// agar pengguna tidak melihat nama kelas Dart.
  static String stripExceptionPrefix(String message) {
    var text = message.trim();
    while (text.startsWith('Exception:')) {
      text = text.substring('Exception:'.length).trim();
    }
    return text;
  }

  /// Parse DioException untuk pesan yang lebih user-friendly
  static String _parseDioError(DioException error) {
    // Handle berdasarkan tipe error
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi timeout. Silakan periksa jaringan Anda dan coba lagi.';

      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Pastikan Anda memiliki koneksi internet yang stabil.';

      case DioExceptionType.badResponse:
        return _parseResponseError(error.response);

      case DioExceptionType.cancel:
        return 'Permintaan dibatalkan.';

      case DioExceptionType.badCertificate:
        return 'Terjadi masalah keamanan koneksi.';

      case DioExceptionType.unknown:
        if (error.message?.contains('SocketException') == true ||
            error.message?.contains('Connection refused') == true ||
            error.message?.contains('Network is unreachable') == true) {
          return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
        }
        return error.message ?? 'Terjadi kesalahan pada server.';
    }
  }

  /// Parse response error dari backend
  static String _parseResponseError(Response<dynamic>? response) {
    if (response == null) {
      return 'Tidak ada respon dari server.';
    }

    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    // Coba ambil message dari response body
    if (data is Map<String, dynamic>) {
      if (data['message'] != null) {
        return data['message'].toString();
      }
      if (data['error'] != null) {
        return data['error'].toString();
      }
    }

    // Fallback berdasarkan status code
    switch (statusCode) {
      case 400:
        return 'Permintaan tidak valid. Periksa data yang Anda masukkan.';
      case 401:
        return 'Sesi Anda telah berakhir. Silakan login kembali.';
      case 403:
        return 'Anda tidak memiliki akses untuk melakukan ini.';
      case 404:
        return 'Data tidak ditemukan.';
      case 409:
        return 'Data sudah ada atau terjadi konflik.';
      case 422:
        return 'Data yang dimasukkan tidak valid.';
      case 500:
        return 'Terjadi kesalahan pada server. Silakan coba lagi nanti.';
      case 502:
      case 503:
      case 504:
        return 'Server sedang tidak tersedia. Silakan coba lagi nanti.';
      default:
        return 'Terjadi kesalahan (Kode: $statusCode).';
    }
  }

  /// Shows a floating toast: [title] in bold with [message] below it. A toast already on screen is
  /// replaced; a tap runs [onTap] and closes it. Without an app shell to show it in (the app is not
  /// built yet) the toast is skipped, never thrown.
  static void showToast(
    String title,
    String message, {
    Color? backgroundColor,
    Color textColor = Colors.white,
    Widget? icon,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    final ScaffoldMessengerState? messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      debugPrint('Toast (no messenger): $title - $message');
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor ?? Colors.grey.shade800,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: duration,
          content: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              messenger.hideCurrentSnackBar();
              onTap?.call();
            },
            child: Row(
              children: [
                if (icon != null) ...[icon, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (message.isNotEmpty)
                        Text(
                          message,
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  /// Menampilkan success dengan toast hijau
  static void showSuccess(String message, {String title = 'Berhasil'}) {
    showToast(
      title,
      message,
      backgroundColor: Colors.green.shade600,
      icon: const Icon(Icons.check_circle, color: Colors.white, size: 28),
    );
  }

  /// Menampilkan info dengan toast biru
  static void showInfo(String message, {String title = 'Info'}) {
    showToast(
      title,
      message,
      backgroundColor: Colors.blue.shade600,
      icon: const Icon(Icons.info_outline, color: Colors.white, size: 28),
    );
  }

  /// Check apakah error adalah connection error
  static bool isConnectionError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.message?.contains('SocketException') == true ||
          error.message?.contains('Connection refused') == true;
    }
    return false;
  }
}
