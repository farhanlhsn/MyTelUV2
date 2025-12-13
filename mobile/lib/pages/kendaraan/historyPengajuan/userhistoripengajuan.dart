import 'package:flutter/material.dart';
import 'package:mobile/pages/kendaraan/historyPengajuan/detailuserhistoripengajuan.dart';
import 'package:mobile/models/pengajuan_plat_model.dart';
import 'package:mobile/services/kendaraan_service.dart';

class UserHistoriPengajuan extends StatefulWidget {
  const UserHistoriPengajuan({super.key});

  @override
  State<UserHistoriPengajuan> createState() => _UserHistoriPengajuanState();
}

class _UserHistoriPengajuanState extends State<UserHistoriPengajuan> {
  List<PengajuanPlatModel> _historiPengajuan = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistoriPengajuan();
  }

  Future<void> _loadHistoriPengajuan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final histori = await KendaraanService.getHistoriPengajuan();
      setState(() {
        _historiPengajuan = histori;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading histori pengajuan: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE63946), // Warna header
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Anda
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 15, 25, 20),
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
                      height: 1.3,
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 60,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error: $_errorMessage',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadHistoriPengajuan,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : _historiPengajuan.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada pengajuan',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistoriPengajuan,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 20,
                          ),
                          itemCount: _historiPengajuan.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final pengajuan = _historiPengajuan[index];
                            return VehicleStatusCard(
                              title: pengajuan.namaKendaraan,
                              licensePlate: pengajuan.platNomor,
                              status: pengajuan.getStatusText(),
                              statusColor: pengajuan.getStatusColor(),
                              // Tombol CEK hanya untuk status DITOLAK
                              onCheckPressed: pengajuan.canShowDetails()
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              DetailPengajuanPlat(
                                                licensePlate:
                                                    pengajuan.platNomor,
                                                status: pengajuan
                                                    .getStatusText(),
                                                statusColor: pengajuan
                                                    .getStatusColor(),
                                                feedback:
                                                    pengajuan.feedback ??
                                                    'Tidak ada feedback',
                                              ),
                                        ),
                                      );
                                    }
                                  : null,
                            );
                          },
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

/// MODIFIKASI:
/// Widget untuk menampilkan kartu status kendaraan.
/// Tombol "CEK" sekarang opsional (hanya tampil jika onCheckPressed diisi).
class VehicleStatusCard extends StatelessWidget {
  final String title;
  final String licensePlate;
  final String status;
  final Color statusColor;
  final VoidCallback? onCheckPressed;

  const VehicleStatusCard({
    super.key,
    required this.title,
    required this.licensePlate,
    required this.status,
    required this.statusColor,
    this.onCheckPressed,
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
        border: Border.all(color: borderColor, width: 2.0),
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
                      color: statusColor,
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
                onPressed: onCheckPressed,
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
