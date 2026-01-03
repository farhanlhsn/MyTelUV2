import 'package:dio/dio.dart';

import 'api_client.dart';

class AuthService {
  final Dio _dio = ApiClient.dio;

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/api/auth/login',
      data: <String, dynamic>{'username': username, 'password': password},
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getMe() async {
    final Response<dynamic> response = await _dio.get<dynamic>('/api/auth/me');

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String nama,
    required String role,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/api/auth/register',
      data: <String, dynamic>{'username': username, 'password': password, 'nama': nama, 'role': role},
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateProfile({
    required String nama,
  }) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      '/api/auth/profile',
      data: <String, dynamic>{'nama': nama},
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      '/api/auth/password',
      data: <String, dynamic>{
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  Future<void> logout() async {
    try {
      await _dio.post<dynamic>('/api/auth/logout');
    } catch (e) {
      // Ignore errors on logout - we'll clear local data anyway
      print('⚠️ Logout API call failed: $e');
    }
  }
}
