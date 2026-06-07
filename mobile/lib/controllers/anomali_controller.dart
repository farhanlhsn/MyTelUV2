import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../models/anomali_model.dart';
import '../services/api_client.dart';
import 'package:mobile/utils/logger.dart';

class AnomaliController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxList<AnomaliModel> anomaliList = <AnomaliModel>[].obs;
  final RxString message = ''.obs;

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
