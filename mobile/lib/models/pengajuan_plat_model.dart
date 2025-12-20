import 'package:flutter/material.dart';

class PengajuanPlatModel {
  final int idKendaraan;
  final int? idUser;
  final String platNomor;
  final String namaKendaraan;
  final String statusPengajuan; // 'MENUNGGU', 'DISETUJUI', 'DITOLAK'
  final String? feedback;
  final List<String> fotoKendaraan;
  final String fotoSTNK;
  final DateTime createdAt;
  final DateTime updatedAt;

  PengajuanPlatModel({
    required this.idKendaraan,
    this.idUser,
    required this.platNomor,
    required this.namaKendaraan,
    required this.statusPengajuan,
    this.feedback,
    required this.fotoKendaraan,
    required this.fotoSTNK,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor untuk membuat instance dari JSON
  factory PengajuanPlatModel.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 Parsing JSON: $json');

      // Helper function untuk parsing int dengan aman
      int parseId(dynamic value) {
        print('  - Parsing ID from: $value (${value.runtimeType})');
        if (value == null) return 0;
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? 0;
        if (value is double) return value.toInt();
        return 0;
      }

      // Helper function untuk parsing list string dengan aman
      List<String> parseStringList(dynamic value, String fieldName) {
        print('  - Parsing $fieldName from: $value (${value.runtimeType})');
        if (value == null) {
          print('    -> $fieldName is null, returning empty list');
          return [];
        }
        if (value is List) {
          print('    -> $fieldName is List with ${value.length} items');
          try {
            List<String> result = [];
            for (var item in value) {
              result.add(item.toString());
            }
            print('    -> Successfully parsed ${result.length} items');
            return result;
          } catch (e) {
            print('    -> Error parsing list items: $e');
            return [];
          }
        }
        if (value is String) {
          print('    -> $fieldName is String: $value');
          return [value];
        }
        print('    -> $fieldName is unknown type, returning empty list');
        return [];
      }

      final idKendaraan = parseId(json['id_kendaraan']);
      final idUser = json['id_user'] != null ? parseId(json['id_user']) : null;
      final platNomor = json['plat_nomor']?.toString() ?? '';
      final namaKendaraan = json['nama_kendaraan']?.toString() ?? '';
      final statusPengajuan =
          json['status_pengajuan']?.toString() ?? 'MENUNGGU';
      final feedback = json['feedback']?.toString();
      final fotoKendaraan = parseStringList(
        json['fotoKendaraan'],
        'fotoKendaraan',
      );
      final fotoSTNK = json['fotoSTNK']?.toString() ?? '';
      final createdAt = DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      );
      final updatedAt = DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      );

      print(
        '✅ Successfully parsed: id=$idKendaraan, plat=$platNomor, nama=$namaKendaraan',
      );

      return PengajuanPlatModel(
        idKendaraan: idKendaraan,
        idUser: idUser,
        platNomor: platNomor,
        namaKendaraan: namaKendaraan,
        statusPengajuan: statusPengajuan,
        feedback: feedback,
        fotoKendaraan: fotoKendaraan,
        fotoSTNK: fotoSTNK,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e, stackTrace) {
      print('❌ Error in fromJson: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Konversi ke JSON
  Map<String, dynamic> toJson() {
    return {
      'id_kendaraan': idKendaraan,
      'plat_nomor': platNomor,
      'nama_kendaraan': namaKendaraan,
      'status_pengajuan': statusPengajuan,
      'feedback': feedback,
      'fotoKendaraan': fotoKendaraan,
      'fotoSTNK': fotoSTNK,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

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
