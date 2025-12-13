import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ==========================================
// 1. HALAMAN UTAMA (LIST MATA KULIAH)
// ==========================================
class AbsensiPage extends StatelessWidget {
  const AbsensiPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Warna utama (Merah Coral)
    final Color primaryRed = const Color(0xFFE63946);

    return Scaffold(
      backgroundColor: primaryRed,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- Header Bagian Atas ---
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
                    "Histori kehadiran",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // --- Body Bagian Bawah (Putih Melengkung) ---
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
                    // Item 1: Teori Peluang (Bisa Di-klik)
                    _buildMatkulCard(
                      context: context,
                      title: "Teori Peluang (TAI)",
                      date: "20 Desember 2024 | 15.30 WIB",
                      primaryRed: primaryRed,
                      onTap: () {
                        // Navigasi ke Halaman Detail (Kode yang Anda berikan)
                        Get.to(() => const AbsensiDetailPage());
                      },
                    ),
                    const SizedBox(height: 16),

                    // Item 2: Kalkulus (Hanya Tampilan)
                    _buildMatkulCard(
                      context: context,
                      title: "Kalkulus (SUM)",
                      date: "20 Desember 2024 | 15.30 WIB",
                      primaryRed: primaryRed,
                      onTap: () {
                        Get.snackbar("Info", "Detail Kalkulus belum tersedia",
                            snackPosition: SnackPosition.BOTTOM);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Item 3: Struktur Data (Hanya Tampilan)
                    _buildMatkulCard(
                      context: context,
                      title: "Struktur Data (SRE)",
                      date: "20 Desember 2024 | 15.30 WIB",
                      primaryRed: primaryRed,
                      onTap: () {
                         Get.snackbar("Info", "Detail Struktur Data belum tersedia",
                            snackPosition: SnackPosition.BOTTOM);
                      },
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

  Widget _buildMatkulCard({
    required BuildContext context,
    required String title,
    required String date,
    required Color primaryRed,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryRed.withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              date,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ==========================================
// 2. HALAMAN DETAIL (YANG ANDA BERIKAN)
// ==========================================
class AbsensiDetailPage extends StatelessWidget {
  const AbsensiDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Warna utama (Merah Coral seperti di gambar)
    final Color primaryRed = const Color(0xFFE63946);

    return Scaffold(
      backgroundColor: primaryRed,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- Header Bagian Atas (Merah) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Daftar Absensi",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // --- Body Bagian Bawah (Putih Melengkung) ---
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tombol CETAK
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "CETAK",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Judul Mata Kuliah
                    const Text(
                      "Teori Peluang",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 15),

                    // List Container dengan Border Merah Tipis
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: primaryRed.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _buildAttendanceItem(
                              date: "Fri, 14 April 2023",
                              time: "08:00 AM - 05:00 PM",
                              isLate: false,
                            ),
                            _buildDivider(),
                            _buildAttendanceItem(
                              date: "Thu, 13 April 2023",
                              time: "08:45 AM - 05:00 PM",
                              isLate: true, // Merah sesuai gambar
                            ),
                            _buildDivider(),
                            _buildAttendanceItem(
                              date: "Wed, 12 April 2023",
                              time: "07:55 AM - 05:00 PM",
                              isLate: false,
                            ),
                            _buildDivider(),
                            _buildAttendanceItem(
                              date: "Tue, 11 April 2023",
                              time: "07:58 AM - 05:00 PM",
                              isLate: false,
                            ),
                            _buildDivider(),
                            _buildAttendanceItem(
                              date: "Mon, 10 April 2023",
                              time: "08:15 AM - 05:00 PM",
                              isLate: true, // Merah sesuai gambar
                            ),
                            _buildDivider(),
                            _buildAttendanceItem(
                              date: "Sun, 9 April 2023",
                              time: "08:00 AM - 05:00 PM",
                              isLate: false,
                              isLastItem: true,
                            ),
                          ],
                        ),
                      ),
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

  // Widget untuk Divider tipis
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.grey.shade300,
      indent: 16,
      endIndent: 16,
    );
  }

  // Widget untuk Item List Absensi
  Widget _buildAttendanceItem({
    required String date,
    required String time,
    required bool isLate,
    bool isLastItem = false,
  }) {
    // Warna teks waktu (Merah jika terlambat/sesuai gambar, Abu jika normal)
    final Color timeColor = isLate ? const Color(0xFFFF5A5F) : Colors.grey.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tanggal
          Text(
            date,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          // Waktu dengan Icon Jam
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: timeColor,
              ),
              const SizedBox(width: 4),
              Text(
                time,
                style: TextStyle(
                  color: timeColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}