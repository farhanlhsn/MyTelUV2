import 'package:dio/dio.dart';
import '../models/kelas.dart';
import '../models/kelas_hari_ini.dart';
import '../models/matakuliah.dart';
import '../models/absensi.dart';
import 'api_client.dart';

class AkademikService {
  final Dio _dio;

  AkademikService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  /// Get kelas hari ini (classes scheduled for today based on user role)
  Future<List<KelasHariIniModel>> getKelasHariIni() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/akademik/kelas/hari-ini',
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final List<dynamic> kelasData = data['data'] as List<dynamic>? ?? [];

        return kelasData
            .map(
              (dynamic item) =>
                  KelasHariIniModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to get kelas hari ini: ${e.message}');
    }
  }

  /// Get jadwal mingguan (weekly schedule grouped by day)
  Future<Map<String, List<dynamic>>> getJadwalMingguan() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/akademik/kelas/jadwal-mingguan',
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final Map<String, dynamic> jadwalData = data['data'] as Map<String, dynamic>? ?? {};

        return jadwalData.map((key, value) => MapEntry(
          key,
          (value as List<dynamic>),
        ));
      }
      return {};
    } on DioException catch (e) {
      throw Exception('Failed to get jadwal mingguan: ${e.message}');
    }
  }

  /// Create jadwal pengganti (override)
  Future<bool> createJadwalPengganti({
    required int idKelas,
    required DateTime tanggalAsli,
    required String status,
    required String alasan,
    DateTime? tanggalGanti,
    String? ruanganGanti,
  }) async {
    try {
      final data = {
        'id_kelas': idKelas,
        'tanggal_asli': tanggalAsli.toIso8601String(),
        'status': status,
        'alasan': alasan,
        if (tanggalGanti != null) 'tanggal_ganti': tanggalGanti.toIso8601String(),
        if (ruanganGanti != null) 'ruangan_ganti': ruanganGanti,
      };

      final Response<dynamic> response = await _dio.post(
        '/api/akademik/kelas/$idKelas/jadwal-pengganti',
        data: data,
      );

      return response.statusCode == 201;
    } on DioException catch (e) {
      throw Exception('Failed to create jadwal pengganti: ${e.message}');
    }
  }

  /// Delete jadwal pengganti
  Future<bool> deleteJadwalPengganti(int idJadwalPengganti) async {
    try {
      final Response<dynamic> response = await _dio.delete(
        '/api/akademik/jadwal-pengganti/$idJadwalPengganti',
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Failed to delete jadwal pengganti: ${e.message}');
    }
  }

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

  // Get absensi history dengan semua sesi (hadir/tidak hadir)
  Future<List<Map<String, dynamic>>> getAbsensiKuHistory({int? idKelas}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (idKelas != null) {
        queryParams['id_kelas'] = idKelas;
      }

      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/akademik/absensi/ku/history',
        queryParameters: queryParams,
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final List<dynamic> historyData = data['data'] as List<dynamic>? ?? [];
        return historyData.cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to get absensi history: ${e.message}');
    }
  }

  // ==================== ADMIN METHODS ====================

  // Get all matakuliah with pagination
  Future<Map<String, dynamic>> getAllMatakuliah({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/akademik/matakuliah',
        queryParameters: queryParams,
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'data': [], 'pagination': {}};
    } on DioException catch (e) {
      throw Exception('Failed to get matakuliah: ${e.message}');
    }
  }

  // Create matakuliah (Admin only)
  Future<MatakuliahModel> createMatakuliah({
    required String namaMatakuliah,
    required String kodeMatakuliah,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/akademik/matakuliah',
        data: {
          'nama_matakuliah': namaMatakuliah,
          'kode_matakuliah': kodeMatakuliah,
        },
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'] as Map<String, dynamic>;
        return MatakuliahModel.fromJson(data);
      }
      throw Exception('Invalid response format');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception('Kode matakuliah sudah ada');
      }
      throw Exception('Failed to create matakuliah: ${e.message}');
    }
  }

  // Update matakuliah (Admin only)
  Future<MatakuliahModel> updateMatakuliah({
    required int idMatakuliah,
    String? namaMatakuliah,
    String? kodeMatakuliah,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (namaMatakuliah != null) data['nama_matakuliah'] = namaMatakuliah;
      if (kodeMatakuliah != null) data['kode_matakuliah'] = kodeMatakuliah;

      final Response<dynamic> response = await _dio.put<dynamic>(
        '/api/akademik/matakuliah/$idMatakuliah',
        data: data,
      );

      if (response.data is Map<String, dynamic>) {
        final responseData = response.data['data'] as Map<String, dynamic>;
        return MatakuliahModel.fromJson(responseData);
      }
      throw Exception('Invalid response format');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception('Kode matakuliah sudah ada');
      }
      throw Exception('Failed to update matakuliah: ${e.message}');
    }
  }

  // Delete matakuliah (Admin only)
  Future<bool> deleteMatakuliah(int idMatakuliah) async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        '/api/akademik/matakuliah/$idMatakuliah',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Tidak bisa menghapus matakuliah yang masih memiliki kelas aktif');
      }
      throw Exception('Failed to delete matakuliah: ${e.message}');
    }
  }

  // Delete ALL kelas (Admin only)
  Future<bool> deleteAllKelas() async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        '/api/akademik/kelas/delete-all',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Failed to delete all kelas: ${e.message}');
    }
  }

  // Create kelas (Admin/Dosen)
  Future<KelasModel> createKelas({
    required int idMatakuliah,
    required int idDosen,
    required String jamMulai,
    required String jamBerakhir,
    required String namaKelas,
    required String ruangan,
    int? hari,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/akademik/kelas',
        data: {
          'id_matakuliah': idMatakuliah,
          'id_dosen': idDosen,
          'jam_mulai': jamMulai,
          'jam_berakhir': jamBerakhir,
          'nama_kelas': namaKelas,
          'ruangan': ruangan,
          if (hari != null) 'hari': hari,
        },
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'] as Map<String, dynamic>;
        return KelasModel.fromJson(data);
      }
      throw Exception('Invalid response format');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception('Jadwal konflik dengan kelas lain');
      }
      throw Exception('Failed to create kelas: ${e.message}');
    }
  }

  // Update kelas (Admin/Dosen)
  Future<KelasModel> updateKelas({
    required int idKelas,
    int? idMatakuliah,
    int? idDosen,
    String? jamMulai,
    String? jamBerakhir,
    String? namaKelas,
    String? ruangan,
    int? hari,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (idMatakuliah != null) data['id_matakuliah'] = idMatakuliah;
      if (idDosen != null) data['id_dosen'] = idDosen;
      if (jamMulai != null) data['jam_mulai'] = jamMulai;
      if (jamBerakhir != null) data['jam_berakhir'] = jamBerakhir;
      if (namaKelas != null) data['nama_kelas'] = namaKelas;
      if (ruangan != null) data['ruangan'] = ruangan;
      if (hari != null) data['hari'] = hari;
      if (jamBerakhir != null) data['jam_berakhir'] = jamBerakhir;
      if (namaKelas != null) data['nama_kelas'] = namaKelas;
      if (ruangan != null) data['ruangan'] = ruangan;

      final Response<dynamic> response = await _dio.put<dynamic>(
        '/api/akademik/kelas/$idKelas',
        data: data,
      );

      if (response.data is Map<String, dynamic>) {
        final responseData = response.data['data'] as Map<String, dynamic>;
        return KelasModel.fromJson(responseData);
      }
      throw Exception('Invalid response format');
    } on DioException catch (e) {
      throw Exception('Failed to update kelas: ${e.message}');
    }
  }

  // Delete kelas (Admin/Dosen)
  Future<bool> deleteKelas(int idKelas) async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        '/api/akademik/kelas/$idKelas',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Failed to delete kelas: ${e.message}');
    }
  }

  // Get peserta kelas (Admin/Dosen)
  Future<List<Map<String, dynamic>>> getPesertaKelas(int idKelas) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/akademik/kelas/$idKelas/peserta',
      );

      if (response.data is Map<String, dynamic>) {
        final List<dynamic> data = response.data['data'] as List<dynamic>? ?? [];
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to get peserta kelas: ${e.message}');
    }
  }

  // Admin add peserta to kelas (Single or Multiple)
  Future<bool> adminAddPeserta({
    required int idKelas,
    required List<int> idsMahasiswa,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/akademik/kelas/peserta/add',
        data: {
          'id_kelas': idKelas,
          'id_mahasiswa': idsMahasiswa,
        },
      );
      return response.statusCode == 201;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception('Beberapa mahasiswa sudah terdaftar di kelas ini');
      }
      throw Exception('Failed to add peserta: ${e.message}');
    }
  }

  // Get all mahasiswa (for dropdown)
  Future<List<Map<String, dynamic>>> getAllMahasiswa() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/auth/users',
        queryParameters: {'role': 'MAHASISWA', 'limit': 100},
      );

      if (response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        final dataMap = responseData['data'] as Map<String, dynamic>?;
        if (dataMap != null && dataMap['users'] is List) {
          return (dataMap['users'] as List).cast<Map<String, dynamic>>();
        }
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to get mahasiswa list: ${e.message}');
    }
  }

  // Get all dosen (for dropdown)
  Future<List<Map<String, dynamic>>> getAllDosen() async {
    try {
      // Using auth endpoint to get users with DOSEN role
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/auth/users',
        queryParameters: {'role': 'DOSEN', 'limit': 100},
      );

      if (response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        // API returns data.users, not data directly
        final dataMap = responseData['data'] as Map<String, dynamic>?;
        if (dataMap != null && dataMap['users'] is List) {
          return (dataMap['users'] as List).cast<Map<String, dynamic>>();
        }
      }
      return [];
    } on DioException catch (e) {
      // Fallback: get from kelas list
      try {
        final kelasResponse = await getAllKelas(limit: 100);
        final List<Map<String, dynamic>> dosenList = [];
        final Set<int> seenIds = {};
        for (final kelas in kelasResponse) {
          if (kelas.dosen != null && !seenIds.contains(kelas.dosen!.idUser)) {
            seenIds.add(kelas.dosen!.idUser);
            dosenList.add({
              'id_user': kelas.dosen!.idUser,
              'nama': kelas.dosen!.nama,
              'username': kelas.dosen!.username,
            });
          }
        }
        return dosenList;
      } catch (_) {
        throw Exception('Failed to get dosen list: ${e.message}');
      }
    }
  }

  /// Download Laporan Sesi PDF
  Future<List<int>> downloadLaporanSesi(int idSesi) async {
    try {
      final response = await _dio.get(
        '/api/akademik/laporan/sesi/$idSesi/pdf',
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('Gagal download laporan: ${e.message}');
    }
  }

  /// Download Laporan Kelas PDF
  Future<List<int>> downloadLaporanKelas(int idKelas) async {
    try {
      final response = await _dio.get(
        '/api/akademik/laporan/kelas/$idKelas/pdf',
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('Gagal download laporan: ${e.message}');
    }
  }
}
