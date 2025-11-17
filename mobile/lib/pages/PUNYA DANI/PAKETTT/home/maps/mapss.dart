// DIHAPUS: import 'dart:async'; (Tidak terpakai)

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// DIPERBAIKI: Path impor yang benar untuk latlong2
import 'package:latlong2/latlong.dart' as latlng;

// Halaman utama yang mengintegrasikan Peta ke dalam UI dari gambar
class IntegratedMapScreen extends StatefulWidget {
  const IntegratedMapScreen({super.key});

  @override
  State<IntegratedMapScreen> createState() => _IntegratedMapScreenState();
}

class _IntegratedMapScreenState extends State<IntegratedMapScreen> {
  // --- Logika Peta yang Diubah untuk flutter_map ---

  final MapController _mapController = MapController();

  static final latlng.LatLng _kJakartaCenter =
      latlng.LatLng(-6.2088, 106.8456);
  static const double _kJakartaZoom = 11.5;

  // --- Akhir dari Logika Peta ---

  int _selectedIndex = 1;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildCustomAppBar(),
      body: _buildMapBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onItemTapped(1),
        backgroundColor: const Color(0xFFEF4444),
        shape: const CircleBorder(),
        elevation: 4.0,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, color: Colors.white),
            Text("Maps", style: TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  Widget _buildMapBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 6.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _kJakartaCenter,
              initialZoom: _kJakartaZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.android.app', // Ganti dengan nama paket Anda
              ),
              // Anda bisa tambahkan layer lain di sini, misal: MarkerLayer
            ],
          ),
        ),
      ),
    );
  }

  // Widget untuk build AppBar kustom
  PreferredSizeWidget _buildCustomAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFEF4444),
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 80.0,
      title: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(
              'https://placehold.co/100x100/png',
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Hi, Lorem Ipsum",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // BARU: Tombol untuk mendemonstrasikan fungsi _goToJakarta
        IconButton(
          icon: const Icon(
            Icons.location_city,
            color: Colors.white,
            size: 28,
          ),
          tooltip: "Kembali ke Jakarta",
          onPressed: _goToJakarta, // Memanggil fungsi saat ditekan
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () {},
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: const Text(
                  '3',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  // Widget untuk build Bottom Navigation Bar kustom
  Widget _buildCustomBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      elevation: 10.0,
      child: SizedBox(
        height: 60.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBottomNavItem(Icons.home, "Home", 0),
                const SizedBox(width: 20), // Spacer kiri
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBottomNavItem(Icons.add_circle_outline, "Add", 2),
                _buildBottomNavItem(Icons.settings, "Settings", 3),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget untuk satu item di Bottom Nav
  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    final Color color = isSelected ? const Color(0xFFEF4444) : Colors.grey;

    // DIHAPUS: Baris `if (index == 1) ...` dihapus karena tidak terjangkau (dead code)

    return MaterialButton(
      minWidth: 40,
      onPressed: () => _onItemTapped(index),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  // Fungsi untuk menggerakkan kamera
  void _goToJakarta() {
    // DIPERBAIKI: Mengganti .animateTo() kembali ke .move()
    // DAN Menghapus parameter 'animation:' yang tidak ada
    // Ini akan memindahkan peta secara instan (tanpa animasi)
    _mapController.move(
      _kJakartaCenter,
      _kJakartaZoom,
    );
  }
}