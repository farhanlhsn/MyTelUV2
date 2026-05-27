class AnomaliModel {
  final int idUser;
  final String typeAnomali;
  final String description;

  AnomaliModel({required this.idUser, required this.typeAnomali, required this.description});

  factory AnomaliModel.fromJson(Map<String, dynamic> json) {
    return AnomaliModel(
      idUser: json['id_user'] ?? 0,
      typeAnomali: json['type_anomali'] ?? 'UNKNOWN',
      description: json['description'] ?? 'Deteksi anomali',
    );
  }
}