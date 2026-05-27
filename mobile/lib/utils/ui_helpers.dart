import 'package:flutter/material.dart';
import '../models/pengajuan_plat_model.dart';

extension PengajuanStatusHelper on PengajuanPlatModel {
  // Helper untuk mendapatkan warna status
  Color getStatusColor() {
    switch (statusPengajuan) {
      case 'DISETUJUI':
        return const Color(0xFF00C853); // Hijau
      case 'DITOLAK':
        return const Color(0xFFF85E55); // Merah
      case 'MENUNGGU':
      default:
        return const Color(0xFFFC5F57); // Orange (Menunggu)
    }
  }

  // Helper untuk mendapatkan text status
  String getStatusText() {
    switch (statusPengajuan) {
      case 'DISETUJUI':
        return 'Selesai';
      case 'DITOLAK':
        return 'Ditolak';
      case 'MENUNGGU':
      default:
        return 'Menunggu Persetujuan';
    }
  }

  // Helper untuk cek apakah bisa di-klik (hanya ditolak yang bisa di-klik)
  bool canShowDetails() {
    return statusPengajuan == 'DITOLAK';
  }
}
