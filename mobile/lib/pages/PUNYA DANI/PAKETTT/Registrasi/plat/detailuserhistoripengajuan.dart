import 'package:flutter/material.dart';

// main function untuk menjalankan aplikasi (opsional, untuk tes)
void main() {
  runApp(const DetailUserHistoriPengajuan());
}

class DetailUserHistoriPengajuan extends StatelessWidget {
  const DetailUserHistoriPengajuan({super.key});

  @override
  Widget build(BuildContext context) {
    // Data palsu untuk testing halaman ini secara terpisah
    const String dummyFeedback =
        "LOREM IPSUM\nADLIALDJALKDJAWLJAWKLKLDJAWLKDJAWLDJAWLKDJAWLKDJAWLKDJALDJALDJAWLDKAWJDLAWJDALWIKJD";

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DetailPengajuanPlat(
        licensePlate: "DD 0000 KE",
        status: "Ditolak",
        statusColor: Color(0xFFF85E55),
        feedback: dummyFeedback,
      ),
    );
  }
}

// Ini adalah class baru yang Anda minta: DetailPengajuanPlat
class DetailPengajuanPlat extends StatelessWidget {
  final String licensePlate;
  final String status;
  final Color statusColor;
  final String feedback;

  const DetailPengajuanPlat({
    super.key,
    required this.licensePlate,
    required this.status,
    required this.statusColor,
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    const Color borderColor = Color(0xFFF76F68); // Border merah

    return Scaffold(
      backgroundColor: const Color(0xFFFC5F57), // Warna header
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Anda
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const Text(
                    "Pengajuan Register Plat", // Judul sesuai gambar
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Container yang di-expand
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                width: double.infinity,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // Plat Nomor
                      Center(
                        child: Text(
                          licensePlate,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Status Badge
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, // Dibuat lebih besar
                            vertical: 8.0,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius:
                                BorderRadius.circular(20.0), // Pill shape
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Label Feedback
                      const Text(
                        "Feedback",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Kontainer Feedback
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: borderColor, // Border merah
                            width: 2.0,
                          ),
                        ),
                        child: Text(
                          feedback,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}