import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../models/kelas.dart';
import '../../models/absensi.dart';

class AbsensiPage extends StatelessWidget {
  const AbsensiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.find<HomeController>();
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
                child: Obx(() {
                  if (controller.isLoadingKelas.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (controller.kelasList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.class_outlined, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada kelas terdaftar',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Daftar kelas terlebih dahulu',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: controller.kelasList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final PesertaKelasModel pesertaKelas = controller.kelasList[index];
                      final kelas = pesertaKelas.kelas;
                      final matakuliah = kelas?.matakuliah;
                      final absensiStats = kelas != null 
                          ? controller.getAbsensiStatsForKelas(kelas.idKelas)
                          : null;

                      final String title = matakuliah != null
                          ? '${matakuliah.namaMatakuliah} (${matakuliah.kodeMatakuliah})'
                          : 'Kelas';
                      final String jadwal = kelas?.jadwal ?? 'Jadwal belum tersedia';

                      return _buildMatkulCard(
                        context: context,
                        title: title,
                        subtitle: jadwal,
                        absensiStats: absensiStats,
                        primaryRed: primaryRed,
                        onTap: () {
                          if (kelas != null) {
                            Get.to(() => AbsensiDetailPage(
                              kelasName: title,
                              idKelas: kelas.idKelas,
                            ));
                          }
                        },
                      );
                    },
                  );
                }),
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
    required String subtitle,
    AbsensiStatsModel? absensiStats,
    required Color primaryRed,
    required VoidCallback onTap,
  }) {
    final double kehadiran = absensiStats?.persentaseKehadiran ?? 0;
    final Color statusColor = kehadiran >= 75 ? Colors.green : Colors.orange;

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
        child: Row(
          children: [
            Expanded(
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
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${kehadiran.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class AbsensiDetailPage extends StatelessWidget {
  final String kelasName;
  final int idKelas;

  const AbsensiDetailPage({
    super.key,
    required this.kelasName,
    required this.idKelas,
  });

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.find<HomeController>();
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
                    onTap: () => Navigator.pop(context),
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
                    const SizedBox(height: 10),

                    // Judul Mata Kuliah
                    Text(
                      kelasName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 15),

                    // List Container dengan Border Merah Tipis
                    Expanded(
                      child: Obx(() {
                        // Filter absensi untuk kelas ini
                        final absensiForKelas = controller.absensiList
                            .where((a) => a.idKelas == idKelas)
                            .toList();

                        if (absensiForKelas.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy, size: 60, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum ada data absensi',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          );
                        }

                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: primaryRed.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: absensiForKelas.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              thickness: 0.5,
                              color: Colors.grey.shade300,
                              indent: 16,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              final absensi = absensiForKelas[index];
                              return _buildAttendanceItem(
                                date: _formatDate(absensi.tanggalAbsensi),
                                type: absensi.typeAbsensi,
                              );
                            },
                          ),
                        );
                      }),
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

  String _formatDate(DateTime date) {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildAttendanceItem({
    required String date,
    required String type,
  }) {
    final bool isPresent = type == 'LOKAL_ABSENSI' || type == 'REMOTE_ABSENSI';
    final Color typeColor = isPresent ? Colors.green : Colors.red;
    final String typeText = type == 'LOKAL_ABSENSI' ? 'Lokal' : 'Remote';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            date,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              typeText,
              style: TextStyle(
                color: typeColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}