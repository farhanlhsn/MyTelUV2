class LogParkirModel {
  final int idLogParkir;
  final int idKendaraan;
  final int idParkiran;
  final int? idUser;
  final String? type; // MASUK or KELUAR
  final double? confidence;
  final String? imageUrl;
  final String? faceImageUrl;    // Face capture (cropped or full frame)
  final bool faceDetected;       // True if face was detected, false = full frame fallback
  final DateTime timestamp;
  final KendaraanInfo? kendaraan;
  final ParkiranInfo? parkiran;

  LogParkirModel({
    required this.idLogParkir,
    required this.idKendaraan,
    required this.idParkiran,
    this.idUser,
    this.type,
    this.confidence,
    this.imageUrl,
    this.faceImageUrl,
    this.faceDetected = false,
    required this.timestamp,
    this.kendaraan,
    this.parkiran,
  });

  /// Get timestamp in local timezone
  DateTime get localTimestamp => timestamp.toLocal();

  /// Check if this is an entry log
  bool get isMasuk => type == 'MASUK';

  /// Check if this is an exit log  
  bool get isKeluar => type == 'KELUAR';

  factory LogParkirModel.fromJson(Map<String, dynamic> json) {
    return LogParkirModel(
      idLogParkir: json['id_log_parkir'] as int,
      idKendaraan: json['id_kendaraan'] as int,
      idParkiran: json['id_parkiran'] as int,
      idUser: json['id_user'] as int?,
      type: json['type'] as String?,
      confidence: json['confidence'] != null 
          ? (json['confidence'] as num).toDouble() 
          : null,
      imageUrl: json['image_url'] as String?,
      faceImageUrl: json['face_image_url'] as String?,
      faceDetected: json['face_detected'] as bool? ?? false,
      timestamp: DateTime.parse(json['timestamp'] as String),
      kendaraan: json['kendaraan'] != null
          ? KendaraanInfo.fromJson(json['kendaraan'] as Map<String, dynamic>)
          : null,
      parkiran: json['parkiran'] != null
          ? ParkiranInfo.fromJson(json['parkiran'] as Map<String, dynamic>)
          : null,
    );
  }
}


class KendaraanInfo {
  final int idKendaraan;
  final String platNomor;
  final String namaKendaraan;

  KendaraanInfo({
    required this.idKendaraan,
    required this.platNomor,
    required this.namaKendaraan,
  });

  factory KendaraanInfo.fromJson(Map<String, dynamic> json) {
    return KendaraanInfo(
      idKendaraan: json['id_kendaraan'] as int,
      platNomor: json['plat_nomor'] as String,
      namaKendaraan: json['nama_kendaraan'] as String,
    );
  }
}

class ParkiranInfo {
  final int idParkiran;
  final String namaParkiran;

  ParkiranInfo({
    required this.idParkiran,
    required this.namaParkiran,
  });

  factory ParkiranInfo.fromJson(Map<String, dynamic> json) {
    return ParkiranInfo(
      idParkiran: json['id_parkiran'] as int,
      namaParkiran: json['nama_parkiran'] as String,
    );
  }
}

class ParkiranModel {
  final int idParkiran;
  final String namaParkiran;
  final int kapasitas;
  final int liveKapasitas;
  final int slotTersedia;
  final double? persentaseTerisi;
  final double? latitude;
  final double? longitude;

  ParkiranModel({
    required this.idParkiran,
    required this.namaParkiran,
    required this.kapasitas,
    required this.liveKapasitas,
    required this.slotTersedia,
    this.persentaseTerisi,
    this.latitude,
    this.longitude,
  });

  factory ParkiranModel.fromJson(Map<String, dynamic> json) {
    // Helper to parse number that might come as String
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }
    
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return ParkiranModel(
      idParkiran: parseInt(json['id_parkiran']) ?? 0,
      namaParkiran: json['nama_parkiran'] as String? ?? '',
      kapasitas: parseInt(json['kapasitas']) ?? 0,
      liveKapasitas: parseInt(json['live_kapasitas']) ?? 0,
      slotTersedia: parseInt(json['slot_tersedia']) ?? 0,
      persentaseTerisi: parseDouble(json['persentase_terisi']),
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
    );
  }
}

class ParkirAnalitikModel {
  final List<ParkiranModel> parkiran;
  final ParkirSummary summary;

  ParkirAnalitikModel({
    required this.parkiran,
    required this.summary,
  });

  factory ParkirAnalitikModel.fromJson(Map<String, dynamic> json) {
    return ParkirAnalitikModel(
      parkiran: (json['parkiran'] as List<dynamic>)
          .map((e) => ParkiranModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: ParkirSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
}

class ParkirSummary {
  final int totalKapasitas;
  final int totalTerisi;
  final int totalTersedia;
  final double persentaseTerisi;

  ParkirSummary({
    required this.totalKapasitas,
    required this.totalTerisi,
    required this.totalTersedia,
    required this.persentaseTerisi,
  });

  factory ParkirSummary.fromJson(Map<String, dynamic> json) {
    // Helper to parse number that might come as String
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return ParkirSummary(
      totalKapasitas: parseInt(json['total_kapasitas']),
      totalTerisi: parseInt(json['total_terisi']),
      totalTersedia: parseInt(json['total_tersedia']),
      persentaseTerisi: parseDouble(json['persentase_terisi']),
    );
  }
}
