import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    // State lokal sederhana menggunakan GetX
    // Default valuenya true (Nyala)
    final RxBool isNotificationEnabled = true.obs;
    
    // Warna tema
    const Color primaryColor = Color(0xFFE63946);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Notifikasi",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Preferensi",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            
            // --- KARTU SWITCH ON/OFF ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Obx(() => SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                activeColor: primaryColor, // Warna merah saat ON
                title: const Text(
                  "Push Notifikasi",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  "Terima notifikasi di HP Anda",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: isNotificationEnabled.value,
                onChanged: (bool value) {
                  // Ubah nilai state
                  isNotificationEnabled.value = value;
                  
                  // Feedback sederhana (SnackBar)
                  Get.snackbar(
                    value ? "Notifikasi Aktif" : "Notifikasi Non-Aktif", 
                    value ? "Anda akan menerima notifikasi" : "Anda tidak akan menerima notifikasi",
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: value ? Colors.green.shade100 : Colors.red.shade100,
                    colorText: value ? Colors.green.shade900 : Colors.red.shade900,
                    duration: const Duration(seconds: 1),
                    margin: const EdgeInsets.all(16),
                  );
                },
              )),
            ),
          ],
        ),
      ),
    );
  }
}