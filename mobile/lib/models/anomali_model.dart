class AnomaliModel {
  final int idUser;
  final String typeAnomali;
  final String description;
  final String? nama;

  AnomaliModel({
    required this.idUser,
    required this.typeAnomali,
    required this.description,
    this.nama,
  });

  factory AnomaliModel.fromJson(Map<String, dynamic> json) {
    String? parsedNama;
    if (json['nama'] != null) {
      parsedNama = json['nama'] as String?;
    } else if (json['user'] != null && json['user']['nama'] != null) {
      parsedNama = json['user']['nama'] as String?;
    }

    return AnomaliModel(
      idUser: json['id_user'] ?? 0,
      typeAnomali: json['type_anomali'] ?? 'UNKNOWN',
      description: json['description'] ?? json['deskripsi'] ?? 'Deteksi anomali',
      nama: parsedNama,
    );
  }
}