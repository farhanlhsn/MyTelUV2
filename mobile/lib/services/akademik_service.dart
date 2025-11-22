import 'package:dio/dio.dart';
import '../models/kelas.dart';
import '../models/absensi.dart';
import 'api_client.dart';

class AkademikService {
  final Dio _dio = ApiClient.dio;

  // Get kelas mahasiswa (kelas yang diikuti oleh mahasiswa)
  Future<List<PesertaKelasModel>> getKelasKu() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/akademik/kelas/ku',
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final List<dynamic> kelasData = data['data'] as List<dynamic>? ?? [];

        return kelasData
            .map(
              (dynamic item) =>
                  PesertaKelasModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to get kelas: ${e.message}');
    }
  }

  // Get absensi mahasiswa
  Future<List<AbsensiModel>> getAbsensiKu() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/akademik/absensi/ku',
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final List<dynamic> absensiData = data['data'] as List<dynamic>? ?? [];

        return absensiData
            .map(
              (dynamic item) =>
                  AbsensiModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to get absensi: ${e.message}');
    }
  }

  // Get absensi stats untuk mahasiswa
  Future<Map<int, AbsensiStatsModel>> getAbsensiStats() async {
    try {
      final List<AbsensiModel> absensiList = await getAbsensiKu();

      // Group by id_kelas
      final Map<int, List<AbsensiModel>> groupedByKelas = {};
      for (final AbsensiModel absensi in absensiList) {
        if (!groupedByKelas.containsKey(absensi.idKelas)) {
          groupedByKelas[absensi.idKelas] = [];
        }
        groupedByKelas[absensi.idKelas]!.add(absensi);
      }

      // Calculate stats for each kelas
      final Map<int, AbsensiStatsModel> stats = {};
      groupedByKelas.forEach((int idKelas, List<AbsensiModel> absensiList) {
        final Map<String, int> counts = {
          'HADIR': 0,
          'IJIN': 0,
          'SAKIT': 0,
          'ALPHA': 0,
        };

        for (final AbsensiModel absensi in absensiList) {
          counts[absensi.typeAbsensi] = (counts[absensi.typeAbsensi] ?? 0) + 1;
        }

        stats[idKelas] = AbsensiStatsModel.fromJson(counts);
      });

      return stats;
    } on DioException catch (e) {
      throw Exception('Failed to get absensi stats: ${e.message}');
    }
  }

  // Daftar kelas baru
  Future<bool> daftarKelas(int idKelas) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/akademik/kelas/daftar',
        data: {'id_kelas': idKelas},
      );

      return response.statusCode == 201;
    } on DioException catch (e) {
      throw Exception('Failed to daftar kelas: ${e.message}');
    }
  }

  // Drop kelas
  Future<bool> dropKelas(int idKelas) async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        '/api/akademik/kelas/$idKelas/drop',
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Failed to drop kelas: ${e.message}');
    }
  }

  // Get all available kelas
  Future<List<KelasModel>> getAllKelas({
    int page = 1,
    int limit = 10,
    int? idMatakuliah,
    String? ruangan,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {'page': page, 'limit': limit};

      if (idMatakuliah != null) {
        queryParams['id_matakuliah'] = idMatakuliah;
      }
      if (ruangan != null && ruangan.isNotEmpty) {
        queryParams['ruangan'] = ruangan;
      }

      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/akademik/kelas',
        queryParameters: queryParams,
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final List<dynamic> kelasData = data['data'] as List<dynamic>? ?? [];

        return kelasData
            .map(
              (dynamic item) =>
                  KelasModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to get all kelas: ${e.message}');
    }
  }

  // Create absensi
  Future<bool> createAbsensi({
    required int idKelas,
    required int idSesiAbsensi,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/akademik/absensi',
        data: {
          'id_kelas': idKelas,
          'id_sesi_absensi': idSesiAbsensi,
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      return response.statusCode == 201;
    } on DioException catch (e) {
      throw Exception('Failed to create absensi: ${e.message}');
    }
  }
}
