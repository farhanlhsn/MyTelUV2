import 'package:flutter/material.dart'; // Tambahkan import ini!

class PengajuanPlatModel {
  final String id;
  final String namaPengaju;
  final String nomorPlat;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime tanggalPengajuan;

  PengajuanPlatModel({
    required this.id,
    required this.namaPengaju,
    required this.nomorPlat,
    required this.status,
    required this.tanggalPengajuan,
  });

  // Helper untuk mendapatkan warna status
  Color getStatusColor() {
    switch (status) {
      case 'approved':
        return const Color(0xFF00C853); // Hijau
      case 'rejected':
        return const Color(0xFFFF1744); // Merah
      default:
        return const Color(0xFFFC5F57); // Orange (Menunggu)
    }
  }

  // Helper untuk mendapatkan text status
  String getStatusText() {
    switch (status) {
      case 'approved':
        return 'Diterima';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Menunggu Persetujuan';
    }
  }
}