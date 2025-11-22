class MatakuliahModel {
  final int idMatakuliah;
  final String namaMatakuliah;
  final String kodeMatakuliah;

  const MatakuliahModel({
    required this.idMatakuliah,
    required this.namaMatakuliah,
    required this.kodeMatakuliah,
  });

  factory MatakuliahModel.fromJson(Map<String, dynamic> json) {
    return MatakuliahModel(
      idMatakuliah: json['id_matakuliah'] as int? ?? 0,
      namaMatakuliah: json['nama_matakuliah'] as String? ?? '',
      kodeMatakuliah: json['kode_matakuliah'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_matakuliah': idMatakuliah,
      'nama_matakuliah': namaMatakuliah,
      'kode_matakuliah': kodeMatakuliah,
    };
  }
}
