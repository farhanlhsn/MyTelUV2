<<<<<<< Updated upstream
import 'package:flutter/material.dart';
=======
import 'package:json_annotation/json_annotation.dart';

part 'pengajuan_plat_model.g.dart';
>>>>>>> Stashed changes

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
<<<<<<< Updated upstream
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
      
      // Parse user info if available
      String? userName;
      String? userUsername;
      if (json['user'] != null) {
        userName = json['user']['nama']?.toString();
        userUsername = json['user']['username']?.toString();
      }
      
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
        userName: userName,
        userUsername: userUsername,
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
=======
  factory PengajuanPlatModel.fromJson(Map<String, dynamic> json) =>
      _$PengajuanPlatModelFromJson(json);
>>>>>>> Stashed changes

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
