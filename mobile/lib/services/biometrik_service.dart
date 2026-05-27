import 'dart:io';
import 'package:dio/dio.dart';
import 'api_client.dart';

class BiometrikService {
  final Dio _dio = ApiClient.dio;

  /// Integration Guide for Developers:
  /// To trigger the randomized active liveness flow using 'smart_liveliness_detection'
  /// in your Flutter page controller, do:
  ///
  /// ```dart
  /// import 'package:smart_liveliness_detection/smart_liveliness_detection.dart';
  /// 
  /// void startLivenessFlow(BuildContext context) async {
  ///   final result = await SmartLivelinessDetection.instance.startLivelinessDetection(
  ///     context,
  ///     config: LivelinessDetectionConfig(
  ///       steps: [
  ///         LivelinessStep.blink,
  ///         LivelinessStep.smile,
  ///         LivelinessStep.turnLeft,
  ///         LivelinessStep.turnRight,
  ///       ],
  ///       randomizeSteps: true, // Randomize order to prevent replay attacks
  ///       maxAttempts: 3,
  ///     ),
  ///   );
  ///   
  ///   if (result != null && result.isSuccess) {
  ///     File liveFaceFile = File(result.imagePath);
  ///     // Pass the verified file and isLivenessVerified = true
  ///     await biometrikAbsen(imageFile: liveFaceFile, latitude: lat, longitude: lng, isLivenessVerified: true);
  ///   }
  /// }
  /// ```

  /// Verify current user's face against stored biometric data
  /// Returns verification result with matched status and similarity score
  Future<Map<String, dynamic>> verifyWajah(File imageFile, {bool isLivenessVerified = false}) async {
    try {
      final FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'liveness_verified': isLivenessVerified.toString(),
      });

      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/v1/biometrik/verify',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return <String, dynamic>{};
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Terjadi kesalahan';
      throw Exception(message);
    }
  }

  /// Scan multiple faces in an image (for classroom/CCTV scanning)
  /// Used by ADMIN/DOSEN to scan attendance
  Future<Map<String, dynamic>> scanWajah(File imageFile, {int? idKelas}) async {
    try {
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
        '/api/v1/biometrik/scan',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return <String, dynamic>{};
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Terjadi kesalahan';
      throw Exception(message);
    }
  }

  /// Biometric auto-attendance: verify face + check session + check location + mark present
  /// Returns success with kelas info or error message
  Future<Map<String, dynamic>> biometrikAbsen({
    required File imageFile,
    required double latitude,
    required double longitude,
    bool isLivenessVerified = false,
    bool isMockLocation = false,
  }) async {
    try {
      final FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'absen_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'liveness_verified': isLivenessVerified.toString(),
        'is_mock_location': isMockLocation.toString(),
      });

      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/v1/biometrik/absen',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return <String, dynamic>{};
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Terjadi kesalahan';
      throw Exception(message);
    }
  }

  // ==================== ADMIN METHODS ====================

  /// Admin: Add biometric data for a user (Requires Liveness Verification)
  Future<Map<String, dynamic>> addBiometrik({
    required int idUser,
    required File imageFile,
    bool isLivenessVerified = false,
  }) async {
    try {
      final FormData formData = FormData.fromMap({
        'id_user': idUser.toString(),
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'biometric_${idUser}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'liveness_verified': isLivenessVerified.toString(),
      });

      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/v1/biometrik/add',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return <String, dynamic>{};
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Terjadi kesalahan';
      throw Exception(message);
    }
  }

  /// Admin: Delete biometric data for a user
  Future<bool> deleteBiometrik(int idUser) async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        '/api/v1/biometrik/delete/$idUser',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Terjadi kesalahan';
      throw Exception(message);
    }
  }

  /// Admin: Edit biometric data for a user
  Future<Map<String, dynamic>> editBiometrik({
    required int idUser,
    required File imageFile,
    bool isLivenessVerified = false,
  }) async {
    try {
      final FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'biometric_${idUser}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'liveness_verified': isLivenessVerified.toString(),
      });

      final Response<dynamic> response = await _dio.put<dynamic>(
        '/api/v1/biometrik/edit/$idUser',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return <String, dynamic>{};
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Terjadi kesalahan';
      throw Exception(message);
    }
  }
}
