import 'dart:io';
import 'package:dio/dio.dart';
import 'api_client.dart';

class BiometrikService {
  final Dio _dio = ApiClient.dio;

  /// Verify current user's face against stored biometric data
  /// Returns verification result with matched status and similarity score
  Future<Map<String, dynamic>> verifyWajah(File imageFile) async {
    final FormData formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    final Response<dynamic> response = await _dio.post<dynamic>(
      '/api/biometrik/verify',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  /// Scan multiple faces in an image (for classroom/CCTV scanning)
  /// Used by ADMIN/DOSEN to scan attendance
  Future<Map<String, dynamic>> scanWajah(File imageFile, {int? idKelas}) async {
    final Map<String, dynamic> formDataMap = {
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    };

    if (idKelas != null) {
      formDataMap['id_kelas'] = idKelas.toString();
    }

    final FormData formData = FormData.fromMap(formDataMap);

    final Response<dynamic> response = await _dio.post<dynamic>(
      '/api/biometrik/scan',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  /// Biometric auto-attendance: verify face + check session + check location + mark present
  /// Returns success with kelas info or error message
  Future<Map<String, dynamic>> biometrikAbsen({
    required File imageFile,
    required double latitude,
    required double longitude,
  }) async {
    final FormData formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'absen_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
    });

    final Response<dynamic> response = await _dio.post<dynamic>(
      '/api/biometrik/absen',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  // ==================== ADMIN METHODS ====================

  /// Admin: Add biometric data for a user
  Future<Map<String, dynamic>> addBiometrik({
    required int idUser,
    required File imageFile,
  }) async {
    final FormData formData = FormData.fromMap({
      'id_user': idUser.toString(),
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'biometric_${idUser}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    final Response<dynamic> response = await _dio.post<dynamic>(
      '/api/biometrik/add',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  /// Admin: Delete biometric data for a user
  Future<bool> deleteBiometrik(int idUser) async {
    final Response<dynamic> response = await _dio.delete<dynamic>(
      '/api/biometrik/delete/$idUser',
    );
    return response.statusCode == 200;
  }

  /// Admin: Edit biometric data for a user
  Future<Map<String, dynamic>> editBiometrik({
    required int idUser,
    required File imageFile,
  }) async {
    final FormData formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'biometric_${idUser}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    final Response<dynamic> response = await _dio.put<dynamic>(
      '/api/biometrik/edit/$idUser',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }
}
