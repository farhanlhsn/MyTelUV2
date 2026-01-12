import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/anomali_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';

class AnomaliController extends GetxController {
  var isLoading = false.obs;  // Default false
  var anomaliList = <AnomaliModel>[].obs;
  var message = ''.obs;

  // FlutterSecureStorage untuk konsisten dengan API Client
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Base URL menggunakan AppConfig (sama seperti ApiClient)
  String get baseUrl => '${AppConfig.baseUrl}/api/anomali';

  Future<void> analyzeKelas(int idKelas) async {
    isLoading.value = true;
    message.value = '';
    
    try {
      // Ambil token dari SecureStorage (sama seperti API Client)
      String? token = await _secureStorage.read(key: 'token');
      
      if (token == null || token.isEmpty) {
        message.value = 'Token tidak ditemukan, silakan login ulang';
        Get.snackbar("Error", message.value);
        return;
      }

      // Tambahkan timeout 15 detik
      final response = await http.post(
        Uri.parse('$baseUrl/analyze/$idKelas'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout - server tidak merespon');
        },
      );

      final body = json.decode(response.body);
      if (response.statusCode == 200) {
        message.value = body['message'] ?? 'Analisis selesai';
        List<dynamic> data = body['data'] ?? [];
        anomaliList.value = data.map((e) => AnomaliModel.fromJson(e)).toList();
      } else if (response.statusCode == 401) {
        message.value = 'Token tidak valid, silakan login ulang';
        Get.snackbar("Error", message.value);
      } else {
        message.value = body['message'] ?? 'Gagal memuat data';
        Get.snackbar("Info", message.value);
      }
    } catch (e) {
      print("Error Anomali: $e");
      message.value = 'Error: $e';
      Get.snackbar("Error", "Gagal terhubung ke server");
    } finally {
      isLoading.value = false;
    }
  }
}

