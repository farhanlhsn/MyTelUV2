import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/anomali_controller.dart';

class AnomaliResultPage extends StatelessWidget {
  const AnomaliResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AnomaliController controller = Get.put(AnomaliController());

    // Ambil ID Kelas dari argumen navigasi
    final int idKelas = Get.arguments['id_kelas'];

    // Jalankan analisis saat halaman dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.analyzeKelas(idKelas);
    });

    return Scaffold(
      appBar: AppBar(title: const Text("Hasil Analisis AI")),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.anomaliList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                Text(controller.message.value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.anomaliList.length,
          itemBuilder: (context, index) {
            final item = controller.anomaliList[index];
            final isSevere = item.typeAnomali == 'TIDAK_HADIR_BERULANG';
            return Card(
              color: isSevere ? Colors.red[50] : Colors.orange[50],
              child: ListTile(
                leading: Icon(Icons.warning, color: isSevere ? Colors.red : Colors.orange),
                title: Text("User ID: ${item.idUser}"), // Bisa join nama di backend jika mau
                subtitle: Text(item.description),
                trailing: Chip(
                  label: Text(isSevere ? "Jarang Hadir" : "Ganda"),
                  backgroundColor: Colors.white,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}