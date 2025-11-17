// lib/maps.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

// BARU: Ubah dari StatefulWidget menjadi StatelessWidget
class MapPage extends StatelessWidget {
  // BARU: Tambahkan controller sebagai parameter
  final MapController mapController;

  const MapPage({
    super.key,
    required this.mapController,
  });

  // Pindahkan konstanta peta ke sini
  static final latlng.LatLng _kJakartaCenter =
      latlng.LatLng(-6.2088, 106.8456);
  static const double _kJakartaZoom = 11.5;

  @override
  Widget build(BuildContext context) {
    // Ini adalah kode dari _buildMapBody() Anda sebelumnya
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
            // BARU: Gunakan controller yang diterima dari parameter
            mapController: mapController,
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
}