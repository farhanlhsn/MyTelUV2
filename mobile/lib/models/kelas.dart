import 'matakuliah.dart';

class DosenModel {
  final int idUser;
  final String nama;
  final String username;

  const DosenModel({
    required this.idUser,
    required this.nama,
    required this.username,
  });

  factory DosenModel.fromJson(Map<String, dynamic> json) {
    return DosenModel(
      idUser: json['id_user'] as int? ?? 0,
      nama: json['nama'] as String? ?? '',
      username: json['username'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id_user': idUser, 'nama': nama, 'username': username};
  }
}

class KelasModel {
  final int idKelas;
  final String namaKelas;
  final String? ruangan;
  final String? jadwal;
  final MatakuliahModel? matakuliah;
  final DosenModel? dosen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const KelasModel({
    required this.idKelas,
    required this.namaKelas,
    this.ruangan,
    this.jadwal,
    this.matakuliah,
    this.dosen,
    this.createdAt,
    this.updatedAt,
  });

  factory KelasModel.fromJson(Map<String, dynamic> json) {
    return KelasModel(
      idKelas: json['id_kelas'] as int? ?? 0,
      namaKelas: json['nama_kelas'] as String? ?? '',
      ruangan: json['ruangan'] as String?,
      jadwal: json['jadwal'] as String?,
      matakuliah: json['matakuliah'] != null
          ? MatakuliahModel.fromJson(json['matakuliah'] as Map<String, dynamic>)
          : null,
      dosen: json['dosen'] != null
          ? DosenModel.fromJson(json['dosen'] as Map<String, dynamic>)
          : null,
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
      'id_kelas': idKelas,
      'nama_kelas': namaKelas,
      'ruangan': ruangan,
      'jadwal': jadwal,
      'matakuliah': matakuliah?.toJson(),
      'dosen': dosen?.toJson(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class PesertaKelasModel {
  final int idMahasiswa;
  final int idKelas;
  final KelasModel? kelas;
  final DateTime? createdAt;

  const PesertaKelasModel({
    required this.idMahasiswa,
    required this.idKelas,
    this.kelas,
    this.createdAt,
  });

  factory PesertaKelasModel.fromJson(Map<String, dynamic> json) {
    return PesertaKelasModel(
      idMahasiswa: json['id_mahasiswa'] as int? ?? 0,
      idKelas: json['id_kelas'] as int? ?? 0,
      kelas: json['kelas'] != null
          ? KelasModel.fromJson(json['kelas'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_mahasiswa': idMahasiswa,
      'id_kelas': idKelas,
      'kelas': kelas?.toJson(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
