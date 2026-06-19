import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:dio/dio.dart';
import '../models/anomali_model.dart';
import '../services/api_client.dart';
import 'package:mobile/utils/logger.dart';

class AnomaliController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxList<AnomaliModel> anomaliList = <AnomaliModel>[].obs;
  final RxString message = ''.obs;

  final RxInt thresholdJarangHadir = 50.obs;
  final RxInt thresholdKehadiranGanda = 10.obs;

  Future<void> getAnomalySettings() async {
    isLoading.value = true;
    try {
      final Response<dynamic> response = await ApiClient.dio.get<dynamic>(
        '/api/v1/anomali/settings',
      );

      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>? ?? {};
        final data = body['data'] as Map<String, dynamic>? ?? {};
        thresholdJarangHadir.value = data['threshold_jarang_hadir'] as int? ?? 50;
        thresholdKehadiranGanda.value = data['threshold_kehadiran_ganda'] as int? ?? 10;
      }
    } on DioException catch (e) {
      debugLog('Error getAnomalySettings: $e');
      Get.snackbar("Error", "Gagal mengambil konfigurasi threshold");
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateAnomalySettings(int jarangHadir, int ganda) async {
    isLoading.value = true;
    try {
      final Response<dynamic> response = await ApiClient.dio.put<dynamic>(
        '/api/v1/anomali/settings',
        data: {
          'threshold_jarang_hadir': jarangHadir,
          'threshold_kehadiran_ganda': ganda,
        },
      );

      if (response.statusCode == 200) {
        thresholdJarangHadir.value = jarangHadir;
        thresholdKehadiranGanda.value = ganda;
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugLog('Error updateAnomalySettings: $e');
      final responseData = e.response?.data;
      final serverMsg = responseData is Map<String, dynamic> ? responseData['message']?.toString() : null;
      Get.snackbar("Error", serverMsg ?? "Gagal menyimpan konfigurasi threshold");
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> analyzeKelas(int idKelas) async {
    isLoading.value = true;
    message.value = '';
    
    try {
      final Response<dynamic> response = await ApiClient.dio.post<dynamic>(
        '/api/v1/anomali/analyze/$idKelas',
      );

      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>? ?? {};
        message.value = body['message'] ?? 'Analisis selesai';
        final List<dynamic> data = body['data'] as List<dynamic>? ?? [];
        anomaliList.value = data
            .map((dynamic e) => AnomaliModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        message.value = 'Gagal memuat data';
        Get.snackbar("Info", message.value);
      }
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final serverMessage = responseData is Map<String, dynamic>
          ? responseData['message']?.toString()
          : null;
      message.value = serverMessage ?? 'Gagal terhubung ke server';
      debugLog(
        'Error Anomali: status=${e.response?.statusCode ?? '-'} type=${e.type}',
      );
      Get.snackbar("Error", message.value);
    } catch (e) {
      debugLog("Error Anomali: $e");
      message.value = 'Error: $e';
      Get.snackbar("Error", "Gagal terhubung ke server");
    } finally {
      isLoading.value = false;
    }
  }
}

