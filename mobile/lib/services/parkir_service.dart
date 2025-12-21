import 'package:dio/dio.dart';
import '../models/parkir_model.dart';
import 'api_client.dart';

class ParkirService {
  final Dio _dio = ApiClient.dio;

  // Get histori parkir user
  Future<List<LogParkirModel>> getHistoriParkir() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/parkir/histori',
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final List<dynamic> logData = data['data'] as List<dynamic>? ?? [];

        return logData
            .map((dynamic item) =>
                LogParkirModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to get histori parkir: ${e.message}');
    }
  }

  // Get semua parkiran dengan kapasitas
  Future<List<ParkiranModel>> getAllParkiran() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/parkir/all',
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final List<dynamic> parkirData = data['data'] as List<dynamic>? ?? [];

        return parkirData
            .map((dynamic item) =>
                ParkiranModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to get all parkiran: ${e.message}');
    }
  }

  // Get analitik parkiran
  Future<ParkirAnalitikModel?> getAnalitikParkiran() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/parkir/analitik',
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        if (data['data'] != null) {
          return ParkirAnalitikModel.fromJson(
              data['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } on DioException catch (e) {
      throw Exception('Failed to get analitik parkiran: ${e.message}');
    }
  }
}
