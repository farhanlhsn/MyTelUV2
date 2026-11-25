import 'package:dio/dio.dart';
import 'api_client.dart';

class DosenService {
  final Dio _dio;

  DosenService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  /// Get kelas yang diampu oleh dosen
  Future<List<Map<String, dynamic>>> getKelasDiampu() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/api/v1/akademik/kelas/dosen',
    );

    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      final kelasList = data['data'] as List<dynamic>? ?? [];
      return kelasList.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Open sesi absensi
  Future<Map<String, dynamic>> openAbsensi({
    required int idKelas,
    required DateTime mulai,
    required DateTime selesai,
    double? latitude,
    double? longitude,
    int? radiusMeter,
    bool requireFace = false,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/api/v1/akademik/open-absensi',
      data: {
        'id_kelas': idKelas,
        'mulai': mulai.toUtc().toIso8601String(),
        'selesai': selesai.toUtc().toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (radiusMeter != null) 'radius_meter': radiusMeter,
        'require_face': requireFace,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  /// Get all sesi absensi for a kelas
  Future<List<Map<String, dynamic>>> getSesiAbsensi(int idKelas) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/api/v1/akademik/kelas/$idKelas/sesi',
    );

    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      final sesiList = data['data'] as List<dynamic>? ?? [];
      return sesiList.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Get detail attendance for a sesi
  Future<Map<String, dynamic>> getSesiDetail(int idSesi) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/api/v1/akademik/absensi/sesi/$idSesi',
    );

    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>? ?? {};
    }
    return <String, dynamic>{};
  }

  /// Close sesi absensi
  Future<Map<String, dynamic>> closeSesiAbsensi(int idSesiAbsensi) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      '/api/v1/akademik/absensi/sesi/$idSesiAbsensi/close',
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  /// Set the attendance status of one student of a sesi by hand (dosen of the class or admin).
  /// [status] is one of HADIR, TELAT, IZIN, SAKIT, ALPHA; [keterangan] is an optional note
  /// (max 255, a blank one clears the previous note). Returns the updated absensi row.
  /// A DioException (403 other dosen, 404 not enrolled, 400 invalid) is left to the caller;
  /// `ErrorHelper.parseError` turns it into the server's Indonesian message.
  Future<Map<String, dynamic>> overrideAbsensi({
    required int idSesi,
    required int idUser,
    required String status,
    String? keterangan,
  }) async {
    final String note = keterangan?.trim() ?? '';
    final Response<dynamic> response = await _dio.put<dynamic>(
      '/api/v1/akademik/absensi/sesi/$idSesi/mahasiswa/$idUser',
      data: <String, dynamic>{
        'status': status,
        if (note.isNotEmpty) 'keterangan': note,
      },
    );

    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  /// Download Laporan Sesi
  Future<List<int>> downloadLaporanSesi(int idSesi) async {
    final response = await _dio.get(
      '/api/v1/akademik/laporan/sesi/$idSesi/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data;
  }

  /// Download Laporan Kelas (Rekap)
  Future<List<int>> downloadLaporanKelas(int idKelas) async {
    final response = await _dio.get(
      '/api/v1/akademik/laporan/kelas/$idKelas/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data;
  }

  /// Download Laporan Sesi - Excel
  Future<List<int>> downloadLaporanSesiExcel(int idSesi) async {
    final response = await _dio.get(
      '/api/v1/akademik/laporan/sesi/$idSesi/excel',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data;
  }

  /// Download Laporan Kelas (Rekap) - Excel
  Future<List<int>> downloadLaporanKelasExcel(int idKelas) async {
    final response = await _dio.get(
      '/api/v1/akademik/laporan/kelas/$idKelas/excel',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data;
  }
}
