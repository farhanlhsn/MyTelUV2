// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pengajuan_plat_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PengajuanPlatModel _$PengajuanPlatModelFromJson(Map<String, dynamic> json) =>
    PengajuanPlatModel(
      idKendaraan: _parseId(json['id_kendaraan']),
      idUser: _parseIdNullable(json['id_user']),
      userName: _readUserName(json, 'userName') as String?,
      userUsername: _readUserUsername(json, 'userUsername') as String?,
      platNomor: json['plat_nomor'] as String? ?? '',
      namaKendaraan: json['nama_kendaraan'] as String? ?? '',
      statusPengajuan: json['status_pengajuan'] as String? ?? 'MENUNGGU',
      feedback: json['feedback'] as String?,
      fotoKendaraan: _parseStringList(json['fotoKendaraan']),
      fotoSTNK: json['fotoSTNK'] as String? ?? '',
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );

Map<String, dynamic> _$PengajuanPlatModelToJson(PengajuanPlatModel instance) =>
    <String, dynamic>{
      'id_kendaraan': instance.idKendaraan,
      'id_user': instance.idUser,
      'userName': instance.userName,
      'userUsername': instance.userUsername,
      'plat_nomor': instance.platNomor,
      'nama_kendaraan': instance.namaKendaraan,
      'status_pengajuan': instance.statusPengajuan,
      'feedback': instance.feedback,
      'fotoKendaraan': instance.fotoKendaraan,
      'fotoSTNK': instance.fotoSTNK,
      'createdAt': _dateTimeToJson(instance.createdAt),
      'updatedAt': _dateTimeToJson(instance.updatedAt),
    };
