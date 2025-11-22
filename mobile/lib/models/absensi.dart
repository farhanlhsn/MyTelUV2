class AbsensiModel {
  final int idAbsensi;
  final int idKelas;
  final int idMahasiswa;
  final String typeAbsensi; // HADIR, IJIN, SAKIT, ALPHA
  final DateTime tanggalAbsensi;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AbsensiModel({
    required this.idAbsensi,
    required this.idKelas,
    required this.idMahasiswa,
    required this.typeAbsensi,
    required this.tanggalAbsensi,
    this.createdAt,
    this.updatedAt,
  });

  factory AbsensiModel.fromJson(Map<String, dynamic> json) {
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
    };
  }
}

class AbsensiStatsModel {
  final int totalHadir;
  final int totalIjin;
  final int totalSakit;
  final int totalAlpha;
  final double persentaseKehadiran;

  const AbsensiStatsModel({
    required this.totalHadir,
    required this.totalIjin,
    required this.totalSakit,
    required this.totalAlpha,
    required this.persentaseKehadiran,
  });

  factory AbsensiStatsModel.fromJson(Map<String, dynamic> json) {
    final int totalHadir = json['HADIR'] as int? ?? 0;
    final int totalIjin = json['IJIN'] as int? ?? 0;
    final int totalSakit = json['SAKIT'] as int? ?? 0;
    final int totalAlpha = json['ALPHA'] as int? ?? 0;
    final int total = totalHadir + totalIjin + totalSakit + totalAlpha;

    return AbsensiStatsModel(
      totalHadir: totalHadir,
      totalIjin: totalIjin,
      totalSakit: totalSakit,
      totalAlpha: totalAlpha,
      persentaseKehadiran: total > 0 ? (totalHadir / total * 100) : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'HADIR': totalHadir,
      'IJIN': totalIjin,
      'SAKIT': totalSakit,
      'ALPHA': totalAlpha,
      'persentase_kehadiran': persentaseKehadiran,
    };
  }
}
