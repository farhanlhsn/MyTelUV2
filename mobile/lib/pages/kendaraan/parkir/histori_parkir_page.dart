import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HistoriParkirPage extends StatelessWidget {
  const HistoriParkirPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Warna merah utama (sesuaikan dengan tema app Anda, misal 0xFFFC5F57 atau 0xFFE63946)
    final Color primaryRed = const Color(0xFFE63946); 

    return Scaffold(
      backgroundColor: primaryRed, // Background merah agar menyatu dengan status bar
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Histori Parkir",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // --- BODY (Kertas Putih Melengkung) ---
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: ListView(
                  children: [
                    // Kartu 1: Ditolak
                    _buildHistoryCard(
                      platNomor: "DD 0000 KE",
                      waktu: "20 Desember 2024 | 15.30 WIB",
                      status: "Ditolak",
                      primaryColor: primaryRed,
                    ),
                    const SizedBox(height: 16),
                    
                    // Kartu 2: Masuk
                    _buildHistoryCard(
                      platNomor: "DD 1111 AA",
                      waktu: "20 Desember 2024 | 15.30 WIB",
                      status: "Masuk",
                      primaryColor: primaryRed,
                    ),
                    const SizedBox(height: 16),
                    
                    // Kartu 3: Keluar
                    _buildHistoryCard(
                      platNomor: "DD 1111 AA",
                      waktu: "20 Desember 2024 | 15.30 WIB",
                      status: "Keluar",
                      primaryColor: primaryRed,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER UNTUK KARTU ---
  Widget _buildHistoryCard({
    required String platNomor,
    required String waktu,
    required String status,
    required Color primaryColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // Radius sudut kartu
        border: Border.all(color: primaryColor.withOpacity(0.5), width: 1), // Border merah tipis
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plat Nomor (Bold)
          Text(
            platNomor,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          
          // Waktu (Abu-abu)
          Text(
            waktu,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500, // Warna abu sesuai gambar
              fontWeight: FontWeight.w500
            ),
          ),
          const SizedBox(height: 12),
          
          // Chip Status (Tombol Merah)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE63946),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}