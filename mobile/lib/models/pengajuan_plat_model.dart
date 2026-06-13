import 'package:json_annotation/json_annotation.dart';

part 'pengajuan_plat_model.g.dart';

@JsonSerializable()
class PengajuanPlatModel {
  @JsonKey(name: 'id_kendaraan', fromJson: _parseId)
  final int idKendaraan;

  @JsonKey(name: 'id_user', fromJson: _parseIdNullable)
  final int? idUser;

  @JsonKey(readValue: _readUserName)
  final String? userName; // Nama user yang mengajukan

  @JsonKey(readValue: _readUserUsername)
  final String? userUsername; // Username user yang mengajukan

  @JsonKey(name: 'plat_nomor', defaultValue: '')
  final String platNomor;

  @JsonKey(name: 'nama_kendaraan', defaultValue: '')
  final String namaKendaraan;

  @JsonKey(name: 'status_pengajuan', defaultValue: 'MENUNGGU')
  final String statusPengajuan; // 'MENUNGGU', 'DISETUJUI', 'DITOLAK'

  final String? feedback;

  @JsonKey(name: 'fotoKendaraan', fromJson: _parseStringList)
  final List<String> fotoKendaraan;

  @JsonKey(name: 'fotoSTNK', defaultValue: '')
  final String fotoSTNK;

  @JsonKey(name: 'createdAt', fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime createdAt;

  @JsonKey(name: 'updatedAt', fromJson: _parseDateTime, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  PengajuanPlatModel({
    required this.idKendaraan,
    this.idUser,
    this.userName,
    this.userUsername,
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
  factory PengajuanPlatModel.fromJson(Map<String, dynamic> json) =>
      _$PengajuanPlatModelFromJson(json);

  // Konversi ke JSON
  Map<String, dynamic> toJson() => _$PengajuanPlatModelToJson(this);
}

// Static helper functions for json_serializable
int _parseId(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is double) return value.toInt();
  return 0;
}

int? _parseIdNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

Object? _readUserName(Map json, String key) {
  if (json['user'] != null && json['user'] is Map) {
    return json['user']['nama']?.toString();
  }
  return null;
}

Object? _readUserUsername(Map json, String key) {
  if (json['user'] != null && json['user'] is Map) {
    return json['user']['username']?.toString();
  }
  return null;
}

List<String> _parseStringList(dynamic value) {
  if (value == null) {
    return [];
  }
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  if (value is String) {
    return [value];
  }
  return [];
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) {
    return DateTime.now();
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

String _dateTimeToJson(DateTime dateTime) => dateTime.toIso8601String();
