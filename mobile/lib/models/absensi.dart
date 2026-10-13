import '../utils/attendance_status.dart';

class AbsensiModel {
  final int idAbsensi;
  final int idKelas;
  final int idMahasiswa;
  final String typeAbsensi; // How it was recorded: REMOTE_ABSENSI or LOKAL_ABSENSI
  final DateTime tanggalAbsensi;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Attendance status: HADIR, TELAT, IZIN, SAKIT or ALPHA (see `attendance_status.dart`).
  final String status;

  /// Note of the dosen when the status was set by hand.
  final String? keterangan;

  /// id_user of the dosen/admin who last changed the status by hand; null for a normal check-in.
  final int? diubahOleh;

  const AbsensiModel({
    required this.idAbsensi,
    required this.idKelas,
    required this.idMahasiswa,
    required this.typeAbsensi,
    required this.tanggalAbsensi,
    this.createdAt,
    this.updatedAt,
    this.status = 'HADIR',
    this.keterangan,
    this.diubahOleh,
  });

  factory AbsensiModel.fromJson(Map<String, dynamic> json) {
    final String? keterangan = (json['keterangan'] as String?)?.trim();

    return AbsensiModel(
      idAbsensi: json['id_absensi'] as int? ?? 0,
      idKelas: json['id_kelas'] as int? ?? 0,
      idMahasiswa: json['id_mahasiswa'] as int? ?? 0,
      typeAbsensi: json['type_absensi'] as String? ?? 'ALPHA',
      tanggalAbsensi: json['tanggal_absensi'] != null
          ? DateTime.parse(json['tanggal_absensi'] as String)
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      // A row from before statuses existed has none: it was a plain check-in
      status: normalizeAttendanceStatus(json['status']) ?? 'HADIR',
      keterangan: keterangan == null || keterangan.isEmpty ? null : keterangan,
      diubahOleh: json['diubah_oleh'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_absensi': idAbsensi,
      'id_kelas': idKelas,
      'id_mahasiswa': idMahasiswa,
      'type_absensi': typeAbsensi,
      'tanggal_absensi': tanggalAbsensi.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'status': status,
      'keterangan': keterangan,
      'diubah_oleh': diubahOleh,
    };
  }
}

/// Counts of the absensi records of a class by status. Percentage rule of the server: TELAT counts
/// as present, IZIN and SAKIT are excused and leave the denominator, nothing countable is 0.
class AbsensiStatsModel {
  final int totalHadir;
  final int totalTelat;
  final int totalIzin;
  final int totalSakit;
  final int totalAlpha;
  final double persentaseKehadiran;

  const AbsensiStatsModel({
    required this.totalHadir,
    this.totalTelat = 0,
    required this.totalIzin,
    required this.totalSakit,
    required this.totalAlpha,
    required this.persentaseKehadiran,
  });

  /// Present + late + absent: what the percentage is taken over.
  int get totalDihitung => totalHadir + totalTelat + totalAlpha;

  factory AbsensiStatsModel.fromJson(Map<String, dynamic> json) {
    final int totalHadir = json['HADIR'] as int? ?? 0;
    final int totalTelat = json['TELAT'] as int? ?? 0;
    final int totalIzin = json['IZIN'] as int? ?? 0;
    final int totalSakit = json['SAKIT'] as int? ?? 0;
    final int totalAlpha = json['ALPHA'] as int? ?? 0;
    final int dihitung = totalHadir + totalTelat + totalAlpha;

    return AbsensiStatsModel(
      totalHadir: totalHadir,
      totalTelat: totalTelat,
      totalIzin: totalIzin,
      totalSakit: totalSakit,
      totalAlpha: totalAlpha,
      persentaseKehadiran: dihitung > 0
          ? ((totalHadir + totalTelat) / dihitung * 100)
          : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'HADIR': totalHadir,
      'TELAT': totalTelat,
      'IZIN': totalIzin,
      'SAKIT': totalSakit,
      'ALPHA': totalAlpha,
      'persentase_kehadiran': persentaseKehadiran,
    };
  }
}
