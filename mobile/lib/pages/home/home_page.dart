import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mobile/pages/home/maps_page.dart';
import 'package:mobile/pages/home/post_page.dart';
import 'package:mobile/pages/home/settings_page.dart';
import 'package:mobile/pages/biometrik/biometrik_verification_page.dart';
import 'package:mobile/pages/dosen/dosen_manage_absensi_page.dart';
import 'package:mobile/pages/absensi/absensi_page.dart';
import 'package:mobile/pages/home/notification_list_page.dart';
import 'package:mobile/utils/error_helper.dart';

import '../../controllers/home_controller.dart';
import '../../app/routes.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final HomeController _homeController = Get.put(HomeController());

  late PageController _pageController;
  late final MapController _mapController;

  // --- Daftar halaman untuk navigasi ---
  late final List<Widget> _pages;

  // --- FUNGSI BARU UNTUK MENU PARKIR ---
  void _showParkingOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Manajemen Parkir', // Judul disesuaikan
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Opsi 1: Analitik Ketersediaan Parkir
              ListTile(
                leading: const Icon(Icons.pie_chart, color: Color(0xFFE63946)), // Icon Chart untuk Analitik
                title: const Text('Analitik Ketersediaan Parkir'),
                subtitle: const Text('Cek slot parkir yang tersedia'),
                onTap: () {
                  Navigator.pop(context);
                  Get.toNamed(AppRoutes.analitikParkir);
                },
              ),
              const Divider(),
              
              // Opsi 2: Histori Parkir
              ListTile(
                leading: const Icon(Icons.history, color: Color(0xFFE63946)),
                title: const Text('Histori Parkir'),
                subtitle: const Text('Lihat riwayat parkir kendaraan'),
                onTap: () {
                  Navigator.pop(context);
                  Get.toNamed(AppRoutes.historiParkir);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  void _showBiometricDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User tidak bisa tap di luar untuk menutup (opsional)
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent, // Transparan agar rounded corner terlihat rapi
          insetPadding: const EdgeInsets.all(20), // Jarak dari tepi layar
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            decoration: BoxDecoration(
              color: const Color(0xFFE63946), // Merah gelap sesuai gambar background
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Agar tinggi menyesuaikan konten
              children: [
                const Text(
                  "Apa Benar Anda sudah berada pada Lokasi?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Tombol TIDAK
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Tutup dialog
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFE63946), // Warna Teks Merah
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "TIDAK",
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16), // Jarak antar tombol
                    // Tombol BETUL
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showSelfieDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5252), // Merah muda
                          foregroundColor: Colors.white, // Warna Teks Putih
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "BETUL",
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
  void _showSelfieDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            // Background Merah Besar
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE63946), // Warna merah background utama
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- KOTAK KAMERA (Placeholder Gambar) ---
                Container(
                  height: 250, 
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(20),
                    image: const DecorationImage(
                      // Menggunakan gambar placeholder orang selfie
                      image: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&q=80'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Jika internet mati, tampilkan icon kamera
                  child: const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.camera_alt, color: Colors.white54),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

                // --- TOMBOL AMBIL ---
                SizedBox(
                  width: 200, // Lebar tombol agak panjang
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Tutup dialog
                      
                      // LOGIKA ABSENSI FINISH DI SINI
                      ErrorHelper.showSuccess(
                        "Data Biometrik & Lokasi tercatat!",
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5252), // Warna Salmon/Merah Muda
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Ambil",
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);

    _mapController = MapController();

    // --- PERBAIKAN DI SINI ---
    // Kita harus mendaftarkan 4 widget, sesuai dengan 4 tombol navigasi
    _pages = [
      _buildHomeContent(), // Halaman 0 - Home
      // Halaman 1 - Maps (Widget Pengganti)
      Center(child: MapPage(mapController: _mapController)),

      // Halaman 2 - Post (Widget Pengganti)
      const Center(child: PostPage()),

      // Halaman 3 - Settings (Widget Pengganti)
      Center(child: SettingsPage()),
    ];
    // --- AKHIR PERBAIKAN ---
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> gridMenuItems = [
    {
      'icon': Icons.badge_outlined,
      'label': 'Lisence Plate',
      'color': const Color(0xFFE63946),
      'route': AppRoutes.userHistoriPengajuan,
    },
    {
      'icon': Icons.assignment_ind_outlined,
      'label': 'Absence',
      'color': const Color(0xFFE63946),
      'route': AppRoutes.absensi,
    },
    {
      'icon': Icons.qr_code_scanner,
      'label': 'Biometric',
      'color': const Color(0xFFE63946),
      'route': null,
    },
    {
      'icon': Icons.local_parking,
      'label': 'Parking',
      'color': const Color(0xFFE63946),
      'route': null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Obx(() {
        // Show error message if any
        if (_homeController.errorMessage.value.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_homeController.errorMessage.value),
                backgroundColor: Colors.red,
              ),
            );
            _homeController.errorMessage.value = '';
          });
        }

        return RefreshIndicator(
          onRefresh: _homeController.refreshData,
          child: Stack(
            children: [
              // Konten Halaman Utama
              IndexedStack(index: _selectedIndex, children: _pages),

              // Navigasi di bagian bawah
              Align(
                alignment: Alignment.bottomCenter,
                child: _buildBottomNav(),
              ),
            ],
          ),
        );
      }),
    );
  }

  // --- Widget untuk konten Halaman Home (Index 0) ---
  Widget _buildHomeContent() {
    return Container(
      color: const Color(0xFFE63946),
      child: Column(
        children: [
          _buildTopBar(),
          _buildCardCarousel(),
          Expanded(child: _buildGridSection()),
        ],
      ),
    );
  }

  // --- (Semua method _build... Anda yang lain tetap sama) ---

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Obx(() {
          final userName = _homeController.currentUser.value?.nama ?? 'User';
          final totalKehadiran = _homeController.totalKehadiranPercentage;

          return Row(
            children: [
              Tooltip(
                message: 'Lihat Profile',
                child: InkWell(
                  onTap: () {
                    Get.toNamed(AppRoutes.me);
                  },
                  borderRadius: BorderRadius.circular(20),
                  splashColor: Colors.white.withOpacity(0.3),
                  highlightColor: Colors.white.withOpacity(0.1),
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFFE63946)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Halo, $userName! 👋",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Kehadiran: ${totalKehadiran.toStringAsFixed(1)}%",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Get.to(() => const NotificationListPage()),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: const Icon(Icons.notifications, color: Colors.white, size: 30),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCardCarousel() {
    return Obx(() {
      // Hide card carousel for ADMIN role
      final userRole = _homeController.currentUser.value?.role;
      if (userRole == 'ADMIN') {
        return const SizedBox.shrink();
      }

      if (_homeController.isLoadingKelasHariIni.value) {
        return const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      }

      final kelasHariIni = _homeController.kelasHariIniList;

      if (kelasHariIni.isEmpty) {
        return SizedBox(
          height: 180,
          child: Center(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_available, size: 40, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'Tidak ada kelas hari ini',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Get.toNamed(AppRoutes.jadwalMingguan),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Lihat jadwal mingguan →',
                        style: TextStyle(fontSize: 12, color: Color(0xFFE63946)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return Column(
        children: [
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _pageController,
              itemCount: kelasHariIni.length,
              itemBuilder: (context, index) {
                double scale = 1.0;
                if (_pageController.position.haveDimensions) {
                  double pageOffset = _pageController.page! - index;
                  scale = (1 - (pageOffset.abs() * 0.2)).clamp(0.8, 1.0);
                }

                return Transform.scale(
                  scale: scale,
                  child: _buildKelasHariIniCard(kelasHariIni[index]),
                );
              },
            ),
          ),
          // Lihat semua jadwal button
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: TextButton(
              onPressed: () => Get.toNamed(AppRoutes.jadwalMingguan),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lihat Jadwal Mingguan',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildKelasHariIniCard(dynamic kelasData) {
    final kelas = kelasData;
    final matakuliah = kelas.matakuliah;
    final dosen = kelas.dosen;
    final hasActiveAbsensi = kelas.hasActiveAbsensi;
    final activeSesi = kelas.activeSesiAbsensi;

    final String title = matakuliah != null
        ? '${matakuliah.namaMatakuliah}'
        : 'Kelas';
    final String jadwal = kelas.jadwal ?? 'Jadwal tidak tersedia';
    final String location = kelas.ruangan ?? 'Ruangan belum ditentukan';

    // Get require_face from active session
    final bool requireFace = activeSesi?.requireFace ?? false;

    return GestureDetector(
      onTap: hasActiveAbsensi ? () {
        // Navigate based on require_face setting
        if (requireFace) {
          // Need face verification
          Get.to(() => const BiometrikAbsenPage());
        } else {
          // GPS only - still use BiometrikAbsenPage for now
          // (it already has location validation)
          Get.to(() => const BiometrikAbsenPage());
        }
      } : null,
      child: Card(
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.3),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              bottom: -80,
              right: -80,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946).withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Active absensi badge with mode indicator
            if (hasActiveAbsensi)
              Positioned(
                top: 10,
                left: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            requireFace ? Icons.face : Icons.location_on,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            requireFace ? 'Absen + Selfie' : 'Absen GPS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Tap untuk absen →',
                        style: TextStyle(
                          color: Color(0xFFE63946),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              top: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Color(0xFFE63946),
                  size: 28,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasActiveAbsensi) const SizedBox(height: 50),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (dosen != null)
                    Text(
                      'Dosen: ${dosen.nama}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        jadwal,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(dynamic pesertaKelas) {
    final kelas = pesertaKelas.kelas;
    final matakuliah = kelas?.matakuliah;
    final dosen = kelas?.dosen;

    // Get absensi stats for this class
    final absensiStats = kelas != null
        ? _homeController.getAbsensiStatsForKelas(kelas.idKelas)
        : null;

    final String title = matakuliah != null
        ? '${matakuliah.namaMatakuliah} (${matakuliah.kodeMatakuliah})'
        : 'Kelas';
    final String jadwal = kelas?.jadwal ?? 'Jadwal belum tersedia';
    final String location = kelas?.ruangan ?? 'Ruangan belum ditentukan';
    final String kehadiran = absensiStats != null
        ? 'Kehadiran: ${absensiStats.persentaseKehadiran.toStringAsFixed(1)}%'
        : 'Kehadiran: 0%';

    // Determine warning color based on attendance
    final double percentage = absensiStats?.persentaseKehadiran ?? 0.0;
    final Color warningColor = percentage < 75 ? Colors.red : Colors.green;
    final IconData warningIcon = percentage < 75
        ? Icons.warning_amber_rounded
        : Icons.check_circle_outline;

    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFE63946).withOpacity(0.8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE63946).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.class_outlined,
                color: Color(0xFFE63946),
                size: 32,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (dosen != null)
                  Text(
                    'Dosen: ${dosen.nama}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  jadwal,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: warningColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(warningIcon, color: warningColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        kehadiran,
                        style: TextStyle(
                          color: warningColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20.0,
            20.0,
            20.0,
            100.0,
          ), // Padding atas 20, bawah 100
          child: Obx(() {
            // Filter menu items based on role (hide Biometric for DOSEN)
            final userRole = _homeController.currentUser.value?.role;
            final List<Map<String, dynamic>> filteredMenuItems = gridMenuItems.where((item) {
              if (item['label'] == 'Biometric' && userRole == 'DOSEN') {
                return false;
              }
              return true;
            }).toList();

            // Add Academic menu for ADMIN
            if (userRole == 'ADMIN') {
              filteredMenuItems.add({
                'icon': Icons.school,
                'label': 'Academic',
                'color': const Color(0xFFE63946),
                'route': AppRoutes.adminAkademik,
              });
              filteredMenuItems.add({
                'icon': Icons.manage_accounts,
                'label': 'Users',
                'color': const Color(0xFFE63946),
                'route': AppRoutes.adminUserManagement,
              });
            }

            // Add Anomaly menu for ADMIN and DOSEN
            if (userRole == 'ADMIN' || userRole == 'DOSEN') {
              filteredMenuItems.add({
                'icon': Icons.warning_amber_rounded,
                'label': 'Anomaly',
                'color': const Color(0xFFE63946),
                'route': AppRoutes.anomaliDashboard,
              });
            }

            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: filteredMenuItems.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final item = filteredMenuItems[index];
                return _buildGridItem(
                  item['icon'],
                  item['label'],
                  item['color'],
                  item['route'],
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildGridItem(
    IconData icon,
    String label,
    Color color,
    String? route,
  ) {
    return InkWell(
      onTap: () {
        if (label == 'Biometric'){
          // Role-based navigation for Biometric
          final userRole = _homeController.currentUser.value?.role;
          if (userRole == 'ADMIN') {
            Get.toNamed(AppRoutes.adminBiometrik);
          } else {
            Get.to(() => const BiometrikAbsenPage());
          }
        }
        else if (label == 'Absence'){
          // Role-based navigation for Absence
          final userRole = _homeController.currentUser.value?.role;
          if (userRole == 'ADMIN') {
            Get.toNamed(AppRoutes.adminAbsensiMonitoring);
          } else if (userRole == 'DOSEN') {
            Get.to(() => const DosenManageAbsensiPage());
          } else {
            Get.to(() => const AbsensiPage());
          }
        }
        else if (label == 'Parking'){
          _showParkingOptions();
        }
        else if (route != null) {
          // Special handling for License Plate - show options dialog
          if (route == AppRoutes.userHistoriPengajuan) {
            _showLicensePlateOptions();
          } else {
            Get.toNamed(route);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label - Coming Soon!'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, "Home", 0),
            _buildNavItem(Icons.location_on_outlined, "Maps", 1),
            _buildNavItem(Icons.post_add_rounded, "Post", 2),
            _buildNavItem(Icons.settings_outlined, "Settings", 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
  final bool isSelected = _selectedIndex == index;

  return Expanded(
    child: InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutBack,
        // 👉 merahnya selalu setinggi navbar
        height: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE63946) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 28,
            ),
            const SizedBox(height: 4),
            // 👉 tingginya yg dianimasikan, bukan background-nya
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: isSelected ? 16 : 0, // cukup buat fontSize 12
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isSelected ? 1.0 : 0.0,
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // Show options for License Plate menu
  void _showLicensePlateOptions() {
    final userRole = _homeController.currentUser.value?.role;
    final isAdmin = userRole == 'ADMIN';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Manajemen Kendaraan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Admin only: Persetujuan Kendaraan
              if (isAdmin) ...[
                ListTile(
                  leading: const Icon(Icons.verified_user, color: Color(0xFFE63946)),
                  title: const Text('Persetujuan Kendaraan'),
                  subtitle: const Text('Setujui atau tolak pengajuan'),
                  onTap: () {
                    Navigator.pop(context);
                    Get.toNamed(AppRoutes.adminPengajuanList);
                  },
                ),
                const Divider(),
              ],

              ListTile(
                leading: const Icon(Icons.add_circle, color: Color(0xFFE63946)),
                title: const Text('Daftar Kendaraan Baru'),
                subtitle: const Text('Tambahkan kendaraan ke sistem'),
                onTap: () {
                  Navigator.pop(context);
                  Get.toNamed(AppRoutes.registerPlat);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.history, color: Color(0xFFE63946)),
                title: const Text('Histori Pengajuan'),
                subtitle: const Text('Lihat status pengajuan kendaraan'),
                onTap: () {
                  Navigator.pop(context);
                  Get.toNamed(AppRoutes.userHistoriPengajuan);
                },
              ),
            ],
          ),
        );
      },
    );
  }

}
