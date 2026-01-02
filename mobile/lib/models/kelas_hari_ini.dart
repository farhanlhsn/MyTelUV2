import 'matakuliah.dart';
import 'kelas.dart';

/// Model for Sesi Absensi that's currently active
class SesiAbsensiModel {
  final int idSesiAbsensi;
  final int idKelas;
  final String typeAbsensi;
  final double? latitude;
  final double? longitude;
  final int? radiusMeter;
  final DateTime mulai;
  final DateTime selesai;
  final bool status;

  const SesiAbsensiModel({
    required this.idSesiAbsensi,
    required this.idKelas,
    required this.typeAbsensi,
    this.latitude,
    this.longitude,
    this.radiusMeter,
    required this.mulai,
    required this.selesai,
    required this.status,
  });

  factory SesiAbsensiModel.fromJson(Map<String, dynamic> json) {
    return SesiAbsensiModel(
      idSesiAbsensi: json['id_sesi_absensi'] as int? ?? 0,
      idKelas: json['id_kelas'] as int? ?? 0,
      typeAbsensi: json['type_absensi'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radiusMeter: json['radius_meter'] as int?,
      mulai: DateTime.parse(json['mulai'] as String),
      selesai: DateTime.parse(json['selesai'] as String),
      status: json['status'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_sesi_absensi': idSesiAbsensi,
      'id_kelas': idKelas,
      'type_absensi': typeAbsensi,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meter': radiusMeter,
      'mulai': mulai.toIso8601String(),
      'selesai': selesai.toIso8601String(),
      'status': status,
    };
  }
}

/// Model for "Kelas Hari Ini" response from backend
class KelasHariIniModel {
  final int idKelas;
  final String namaKelas;
  final String? ruangan;
  final String? jamMulai;
  final String? jamBerakhir;
  final MatakuliahModel? matakuliah;
  final DosenModel? dosen;
  final int jumlahPeserta;
  final bool hasActiveAbsensi;
  final SesiAbsensiModel? activeSesiAbsensi;

  const KelasHariIniModel({
    required this.idKelas,
    required this.namaKelas,
    this.ruangan,
    this.jamMulai,
    this.jamBerakhir,
    this.matakuliah,
    this.dosen,
    this.jumlahPeserta = 0,
    this.hasActiveAbsensi = false,
    this.activeSesiAbsensi,
  });

  /// Formatted time range (e.g., "08:00 - 10:00")
  String get jadwal {
    if (jamMulai != null && jamBerakhir != null) {
      // Format jam_mulai and jam_berakhir to show only HH:MM
      final start = jamMulai!.substring(0, 5);
      final end = jamBerakhir!.substring(0, 5);
      return '$start - $end';
    }
    return 'Jadwal tidak tersedia';
  }

  factory KelasHariIniModel.fromJson(Map<String, dynamic> json) {
    return KelasHariIniModel(
      idKelas: json['id_kelas'] as int? ?? 0,
      namaKelas: json['nama_kelas'] as String? ?? '',
      ruangan: json['ruangan'] as String?,
      jamMulai: json['jam_mulai'] as String?,
      jamBerakhir: json['jam_berakhir'] as String?,
      matakuliah: json['matakuliah'] != null
          ? MatakuliahModel.fromJson(json['matakuliah'] as Map<String, dynamic>)
          : null,
      dosen: json['dosen'] != null
          ? DosenModel.fromJson(json['dosen'] as Map<String, dynamic>)
          : null,
      jumlahPeserta: json['jumlah_peserta'] as int? ?? 0,
      hasActiveAbsensi: json['has_active_absensi'] as bool? ?? false,
      activeSesiAbsensi: json['active_sesi_absensi'] != null
          ? SesiAbsensiModel.fromJson(json['active_sesi_absensi'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_kelas': idKelas,
      'nama_kelas': namaKelas,
      'ruangan': ruangan,
      'jam_mulai': jamMulai,
      'jam_berakhir': jamBerakhir,
      'matakuliah': matakuliah?.toJson(),
      'dosen': dosen?.toJson(),
      'jumlah_peserta': jumlahPeserta,
      'has_active_absensi': hasActiveAbsensi,
      'active_sesi_absensi': activeSesiAbsensi?.toJson(),
    };
  }
}
