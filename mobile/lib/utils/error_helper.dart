import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:dio/dio.dart';

/// Utility class untuk menangani error secara konsisten di seluruh aplikasi
class ErrorHelper {
  /// Menampilkan error dengan dialog yang jelas dan visible
  static void showError(dynamic error, {String title = 'Terjadi Kesalahan'}) {
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
      String msg = error.toString();
      // Remove "Exception:" prefix if present
      if (msg.startsWith('Exception:')) {
        msg = msg.substring(10).trim();
      }
      return msg;
    }

    // Handle string langsung
    if (error is String) {
      return error;
    }

    return 'Terjadi kesalahan yang tidak diketahui.';
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
      default:
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

  /// Menampilkan success dengan snackbar yang lebih visible
  static void showSuccess(String message, {String title = 'Berhasil'}) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      icon: const Padding(
        padding: EdgeInsets.only(left: 8),
        child: Icon(Icons.check_circle, color: Colors.white, size: 28),
      ),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.TOP,
    );
  }

  /// Menampilkan info dengan snackbar biru
  static void showInfo(String message, {String title = 'Info'}) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.blue.shade600,
      colorText: Colors.white,
      icon: const Padding(
        padding: EdgeInsets.only(left: 8),
        child: Icon(Icons.info_outline, color: Colors.white, size: 28),
      ),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.TOP,
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
