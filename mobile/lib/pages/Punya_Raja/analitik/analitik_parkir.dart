import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AnalitikParkirPage extends StatelessWidget {
  const AnalitikParkirPage({super.key});

  // Warna utama (Coral Red)
  static const Color primaryColor = Color(0xFFE63946);
  // Warna gelap untuk bayangan/aksen
  static const Color darkRedColor = Color(0xFFC14A44);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor, // 1. Background Merah di Scaffold
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- HEADER (Tanpa tinggi fix, mengikuti padding) ---
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
                    'Analitik Ketersediaan Parkir',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20, // Ukuran font disamakan
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // --- KONTEN UTAMA (Putih Melengkung) ---
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
                // Clip agar konten tidak bocor keluar rounded corner
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        // 1. HORIZONTAL TIME SELECTOR
                        _buildTimeSelector(),

                        const SizedBox(height: 40),

                        // 2. KARTU LOKASI PARKIRAN
                        _buildLocationCard(name: "Lokasi Parkiran : GKU", slot: 19),
                        const SizedBox(height: 16),
                        _buildLocationCard(name: "Lokasi Parkiran : TULT", slot: 19),
                        
                        const SizedBox(height: 50), 
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET 1: TIME SELECTOR (TIDAK BERUBAH) ---
  Widget _buildTimeSelector() {
    final List<Map<String, String>> times = [
      {"day": "Fri", "date": "22", "time": "17:00"},
      {"day": "Fri", "date": "22", "time": "18:00"},
      {"day": "Fri", "date": "22", "time": "19:00"},
      {"day": "Fri", "date": "22", "time": "20:00"},
      {"day": "Fri", "date": "22", "time": "21:00"},
    ];

    return SizedBox(
      height: 150, 
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: times.length,
        itemBuilder: (context, index) {
          final item = times[index];
          return _buildTimeChip(
            item['day']!,
            item['date']!,
            item['time']!,
          );
        },
      ),
    );
  }

  Widget _buildTimeChip(String day, String date, String time) {
    final Gradient cardGradient = LinearGradient(
      colors: [
        primaryColor.withOpacity(1.0),
        const Color(0xFF130B2B).withOpacity(0.78),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    
    final List<BoxShadow> cardShadow = [
      BoxShadow(
        color: darkRedColor.withOpacity(0.3),
        blurRadius: 5,
        offset: const Offset(0, 3),
      )
    ];

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 95,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: cardGradient,
              boxShadow: cardShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),

          Container(
            width: 55,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: cardGradient,
              boxShadow: cardShadow,
            ),
            child: Text(
              time,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET 2: LOCATION CARD (TIDAK BERUBAH) ---
  Widget _buildLocationCard({required String name, required int slot}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE63946),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Slot : $slot",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}