import 'package:flutter/material.dart';
import 'package:mobile/pages/PUNYA%20DANI/PAKETTT/Registrasi/plat/detailuserhistoripengajuan.dart';


class UserHistoriPengajuan extends StatelessWidget {
  const UserHistoriPengajuan({super.key});

  @override
  Widget build(BuildContext context) {
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
                    "Pengajuan Register Plat", // Judul disesuaikan
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
                // Kita gunakan ListView agar bisa di-scroll jika card-nya banyak
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 20,
                  ),
                  children: [
                    // Card 1: Sesuai gambar (Ditolak, dengan tombol)
                    VehicleStatusCard(
                      title: "HONDA VARIO",
                      licensePlate: "DD 0000 KE",
                      status: "Ditolak",
                      statusColor: const Color(0xFFF85E55), // Merah
                      onCheckPressed: () {
                        print("Tombol CEK Honda Vario ditekan!");
                      },
                    ),
                    const SizedBox(height: 16), // Spasi antar card

                    // Card 2: Sesuai gambar (Selesai, tanpa tombol)
                    VehicleStatusCard(
                      title: "HONDA BEAT",
                      licensePlate: "DD 0000 KE",
                      status: "Selesai",
                      statusColor: const Color(0xFFF85E55), // Merah
                      // Tidak mengirim onCheckPressed, jadi tombolnya hilang
                    ),
                    const SizedBox(height: 16), // Spasi antar card

                    // Card 3: Sesuai gambar (Menunggu, tanpa tombol)
                    VehicleStatusCard(
                      title: "Fikri",
                      licensePlate: "DD 0000 KE",
                      status: "Menunggu Persetujuan",
                      statusColor: const Color(0xFFF85E55), // Merah
                      // Tidak mengirim onCheckPressed, jadi tombolnya hilang
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
}

/// MODIFIKASI:
/// Widget untuk menampilkan kartu status kendaraan.
/// Tombol "CEK" sekarang opsional (hanya tampil jika onCheckPressed diisi).
class VehicleStatusCard extends StatelessWidget {
  final String title;
  final String licensePlate;
  final String status;
  final Color statusColor;
  // Dibuat opsional (nullable) dengan tanda tanya '?'
  final VoidCallback? onCheckPressed;

  const VehicleStatusCard({
    super.key,
    required this.title,
    required this.licensePlate,
    required this.status,
    required this.statusColor,
    this.onCheckPressed, // Dihapus 'required'
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF85E55);
    const Color borderColor = Color(0xFFF76F68);
    const Color subtitleColor = Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: borderColor,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bagian kiri: Teks dan Status Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    licensePlate,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor, // Menggunakan warna dari parameter
                      borderRadius: BorderRadius.circular(20.0),
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
            ),

            // Bagian kanan: Tombol "CEK" (KONDISIONAL)
            // Tombol hanya akan tampil jika onCheckPressed TIDAK null
            if (onCheckPressed != null)
              ElevatedButton(
                onPressed: (){
                  onCheckPressed;
                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DetailPengajuanPlat(licensePlate: "DD 1930 KE", status: "ditolak", statusColor: Colors.red, feedback: "masih belum jelas",),
                                      ),
                                    );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28.0,
                    vertical: 14.0,
                  ),
                ),
                child: const Text(
                  "CEK",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}