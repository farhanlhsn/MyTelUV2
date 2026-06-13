import 'package:mobile/utils/logger.dart';
import 'package:dio/dio.dart';

import 'api_client.dart';
import 'package:mobile/utils/logger.dart';



class AuthService {
  final Dio _dio = ApiClient.dio;

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/api/v1/auth/login',
      data: <String, dynamic>{'username': username, 'password': password},
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Invalid response format from server',
    );
  }

  Future<Map<String, dynamic>> getMe() async {
    final Response<dynamic> response = await _dio.get<dynamic>('/api/v1/auth/me');

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Invalid response format from server',
      );
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String nama,
    required String role,
    String? nimNip,
  }) async {
    final Map<String, dynamic> data = {
      'username': username,
      'password': password,
      'nama': nama,
      'role': role,
    };
    if (nimNip != null && nimNip.isNotEmpty) {
      data['nim_nip'] = nimNip;
    }

    final Response<dynamic> response = await _dio.post<dynamic>(
      '/api/v1/auth/register',
      data: data,
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Invalid response format from server',
    );
  }

  Future<Map<String, dynamic>> updateProfile({
    required String nama,
  }) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      '/api/v1/auth/profile',
      data: <String, dynamic>{'nama': nama},
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Invalid response format from server',
    );
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      '/api/v1/auth/password',
      data: <String, dynamic>{
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Invalid response format from server',
    );
  }

  Future<void> logout({String? refreshToken}) async {
    try {
      final data = refreshToken != null ? {'refresh_token': refreshToken} : null;
      await _dio.post<dynamic>('/api/v1/auth/logout', data: data);
    } catch (e) {
      // Ignore errors on logout - we'll clear local data anyway
      debugLog('⚠️ Logout API call failed: $e');
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String username) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/api/v1/auth/forgot-password',
      data: <String, dynamic>{'username': username},
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Invalid response format from server',
    );
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/api/v1/auth/reset-password',
      data: <String, dynamic>{'token': token, 'newPassword': newPassword},
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Invalid response format from server',
    );
  }
}
