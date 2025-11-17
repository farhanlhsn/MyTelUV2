import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:mobile/pages/PUNYA%20DANI/PAKETTT/home/maps/maps.dart';
import 'package:mobile/pages/PUNYA%20DANI/PAKETTT/home/post/post.dart';
import 'package:mobile/pages/PUNYA%20DANI/PAKETTT/home/setting/settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  late PageController _pageController;
  double _currentPageValue = 0.0;
  late final MapController _mapController;

  // --- Daftar halaman untuk navigasi ---
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9)
      ..addListener(() {
        setState(() {
          _currentPageValue = _pageController.page!;
        });
      });

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
      const Center(child: SettingsPage()),
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
    },
    {
      'icon': Icons.assignment_ind_outlined,
      'label': 'Absence',
      'color': const Color(0xFFE63946),
    },
    {
      'icon': Icons.qr_code_scanner,
      'label': 'Biometric',
      'color': const Color(0xFFE63946),
    },
    {
      'icon': Icons.local_parking,
      'label': 'Parking',
      'color': const Color(0xFFE63946),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          // Konten Halaman Utama
          IndexedStack(index: _selectedIndex, children: _pages),

          // Navigasi di bagian bawah
          Align(alignment: Alignment.bottomCenter, child: _buildBottomNav()),
        ],
      ),
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
        child: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFFE63946)),
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
                    const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Plat Status 🚀",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            "Cek Kembali Status Plat Anda..",
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.notifications, color: Colors.white, size: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardCarousel() {
    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _pageController,
        itemCount: 3,
        itemBuilder: (context, index) {
          double scale = 1.0;
          if (_pageController.position.haveDimensions) {
            double pageOffset = _pageController.page! - index;
            scale = (1 - (pageOffset.abs() * 0.2)).clamp(0.8, 1.0);
          }

          return Transform.scale(scale: scale, child: _buildInfoCard(index));
        },
      ),
    );
  }

  Widget _buildInfoCard(int index) {
    const cardData = {
      'title': 'Teori Peluang (TAI)',
      'time': '8.00 - 11.00',
      'location': 'KU 03.04.10',
      'warning': 'Kehadiran : 20%',
    };

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
                Icons.house_outlined,
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
                  cardData['title']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  cardData['time']!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  cardData['location']!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade800,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cardData['warning']!,
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: gridMenuItems.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final item = gridMenuItems[index];
              return _buildGridItem(item['icon'], item['label'], item['color']);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem(IconData icon, String label, Color color) {
    return Container(
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
    bool isSelected = _selectedIndex == index;

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
          padding: const EdgeInsets.symmetric(vertical: 10),
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: isSelected ? 16 : 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSelected ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
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
}
