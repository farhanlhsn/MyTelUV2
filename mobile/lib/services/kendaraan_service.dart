import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/models/pengajuan_plat_model.dart';
import 'package:mobile/services/api_client.dart';
import '../utils/logger.dart';

class KendaraanService {
  static Dio _dio = ApiClient.dio;
  
  @visibleForTesting
  static set dio(Dio dio) => _dio = dio;

  static FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @visibleForTesting
  static set secureStorage(FlutterSecureStorage ss) => _secureStorage = ss;

  // Get histori pengajuan kendaraan user
  static Future<List<PengajuanPlatModel>> getHistoriPengajuan() async {
    try {
      debugLog('Fetching histori pengajuan');

      final response = await _dio.get('/api/v1/kendaraan/histori-pengajuan');
      debugLog('Histori pengajuan response status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final dynamic rawData = response.data['data'];

        if (rawData == null || rawData is! List) {
          debugLog('Histori pengajuan returned non-list data');
          return [];
        }

        final List<dynamic> data = rawData;
        debugLog('Histori pengajuan item count: ${data.length}');

        // Parse each item with error handling
        final List<PengajuanPlatModel> result = [];
        for (int i = 0; i < data.length; i++) {
          try {
            final item = PengajuanPlatModel.fromJson(
              data[i] as Map<String, dynamic>,
            );
            result.add(item);
          } catch (e) {
            debugLog('Skipping invalid histori pengajuan item at index $i: $e');
            // Skip invalid items
            continue;
          }
        }

        debugLog('Parsed histori pengajuan items: ${result.length}');
        return result;
      } else {
        throw Exception(
          response.data['message'] ?? 'Failed to fetch histori pengajuan',
        );
      }
    } on DioException catch (e) {
      debugLog(
        'Histori pengajuan request failed: status=${e.response?.statusCode ?? '-'} type=${e.type}',
      );
      if (e.response != null) {
        throw Exception(
          e.response?.data['message'] ?? 'Error fetching histori pengajuan',
        );
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      debugLog('Unexpected histori pengajuan error: $e');
      throw Exception('Unexpected error: $e');
    }
  }

  // Register kendaraan baru
  static Future<PengajuanPlatModel> registerKendaraan({
    required String platNomor,
    required String namaKendaraan,
    required List<String> fotoKendaraanPaths,
    required String fotoSTNKPath,
  }) async {
    try {
      debugLog(
        'Registering kendaraan with ${fotoKendaraanPaths.length} vehicle photos',
      );

      // Prepare multipart form data
      // TIDAK mengirim id_user karena backend akan menggunakan id dari token
      FormData formData = FormData.fromMap({
        'plat_nomor': platNomor,
        'nama_kendaraan': namaKendaraan,
      });

      // Add foto kendaraan (3 photos)
      for (int i = 0; i < fotoKendaraanPaths.length; i++) {
        formData.files.add(
          MapEntry(
            'fotoKendaraan',
            await MultipartFile.fromFile(
              fotoKendaraanPaths[i],
              filename: 'foto_kendaraan_$i.jpg',
            ),
          ),
        );
      }

      // Add foto STNK
      formData.files.add(
        MapEntry(
          'fotoSTNK',
          await MultipartFile.fromFile(fotoSTNKPath, filename: 'foto_stnk.jpg'),
        ),
      );

      final response = await _dio.post(
        '/api/v1/kendaraan/register',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      debugLog('Register kendaraan response status: ${response.statusCode}');

      if (response.statusCode == 201 && response.data['status'] == 'success') {
        return PengajuanPlatModel.fromJson(response.data['data']);
      } else {
        throw Exception(
          response.data['message'] ?? 'Failed to register kendaraan',
        );
      }
    } on DioException catch (e) {
      debugLog(
        'Register kendaraan request failed: status=${e.response?.statusCode ?? '-'} type=${e.type}',
      );
      if (e.response != null) {
        throw Exception(
          e.response?.data['message'] ?? 'Error registering kendaraan',
        );
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  // Resubmit kendaraan yang ditolak
  static Future<PengajuanPlatModel> resubmitKendaraan({
    required int idKendaraan,
    List<String>? fotoKendaraanPaths,
    String? fotoSTNKPath,
  }) async {
    try {
      debugLog('🚗 Resubmitting kendaraan ID: $idKendaraan...');
      FormData formData = FormData.fromMap({});

      if (fotoKendaraanPaths != null && fotoKendaraanPaths.isNotEmpty) {
        if (fotoKendaraanPaths.length != 3) {
          throw Exception('Pilih tepat 3 foto kendaraan untuk diubah.');
        }
        for (int i = 0; i < fotoKendaraanPaths.length; i++) {
          formData.files.add(
            MapEntry(
              'fotoKendaraan',
              await MultipartFile.fromFile(
                fotoKendaraanPaths[i],
                filename: 'foto_kendaraan_$i.jpg',
              ),
            ),
          );
        }
      }

      if (fotoSTNKPath != null && fotoSTNKPath.isNotEmpty) {
        formData.files.add(
          MapEntry(
            'fotoSTNK',
            await MultipartFile.fromFile(fotoSTNKPath, filename: 'foto_stnk.jpg'),
          ),
        );
      }

      final response = await _dio.put(
        '/api/v1/kendaraan/$idKendaraan/resubmit',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return PengajuanPlatModel.fromJson(response.data['data']);
      } else {
        throw Exception(
          response.data['message'] ?? 'Failed to resubmit kendaraan',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          e.response?.data['message'] ?? 'Error resubmitting kendaraan',
        );
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  // Get detail kendaraan by ID
  static Future<PengajuanPlatModel> getKendaraanById(int idKendaraan) async {
    try {
      final response = await _dio.get('/api/v1/kendaraan/');

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final List<dynamic> data = response.data['data'];
        final kendaraan = data.firstWhere(
          (item) => item['id_kendaraan'] == idKendaraan,
          orElse: () => throw Exception('Kendaraan not found'),
        );
        return PengajuanPlatModel.fromJson(kendaraan);
      } else {
        throw Exception(
          response.data['message'] ?? 'Failed to fetch kendaraan',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          e.response?.data['message'] ?? 'Error fetching kendaraan',
        );
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  // ========== ADMIN METHODS ==========

  // Get all unverified kendaraan (for Admin)
  static Future<Map<String, dynamic>> getAllUnverifiedKendaraan({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/kendaraan/all-unverified',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final List<dynamic> data = response.data['data'] ?? [];
        final items = data
            .map((item) => PengajuanPlatModel.fromJson(item as Map<String, dynamic>))
            .toList();
        
        return {
          'items': items,
          'totalPages': response.data['totalPages'] ?? 1,
          'total': response.data['total'] ?? 0,
          'currentPage': response.data['currentPage'] ?? 1,
        };
      } else {
        throw Exception(
          response.data['message'] ?? 'Failed to fetch unverified kendaraan',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          e.response?.data['message'] ?? 'Error fetching unverified kendaraan',
        );
      } else {
        throw Exception('Network error: ${e.message}');
      }
    }
  }

  // Verify kendaraan (for Admin)
  static Future<bool> verifyKendaraan({
    required int idKendaraan,
    required int idUser,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/kendaraan/verify',
        data: {
          'id_kendaraan': idKendaraan,
          'id_user': idUser,
        },
      );

      return response.statusCode == 200 && response.data['status'] == 'success';
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          e.response?.data['message'] ?? 'Error verifying kendaraan',
        );
      } else {
        throw Exception('Network error: ${e.message}');
      }
    }
  }

  // Reject kendaraan (for Admin)
  static Future<bool> rejectKendaraan({
    required int idKendaraan,
    required int idUser,
    required String feedback,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/kendaraan/reject',
        data: {
          'id_kendaraan': idKendaraan,
          'id_user': idUser,
          'feedback': feedback,
        },
      );

      return response.statusCode == 200 && response.data['status'] == 'success';
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          e.response?.data['message'] ?? 'Error rejecting kendaraan',
        );
      } else {
        throw Exception('Network error: ${e.message}');
      }
    }
  }
}
