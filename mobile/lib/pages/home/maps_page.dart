import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import '../../services/parkir_service.dart';
import '../../models/parkir_model.dart';

class MapPage extends StatefulWidget {
  final MapController mapController;

  const MapPage({super.key, required this.mapController});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final ParkirService _parkirService = ParkirService();
  List<ParkiranModel> _parkiranList = [];
  bool _isLoading = true;

  static final latlng.LatLng _kTelyuCenter = latlng.LatLng(
    -6.973975679076366,
    107.63041937130109,
  );
  static const double _kTelyuZoom = 16.0;
  static const Color primaryColor = Color(0xFFE63946);

  @override
  void initState() {
    super.initState();
    _loadParkiran();
  }

  Future<void> _loadParkiran() async {
    try {
      final data = await _parkirService.getAllParkiran();
      setState(() {
        _parkiranList = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showParkiranInfo(ParkiranModel parkiran) {
    final Color statusColor = parkiran.slotTersedia > 10
        ? Colors.green
        : parkiran.slotTersedia > 0
            ? Colors.orange
            : Colors.red;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_parking,
                      color: primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parkiran.namaParkiran,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kapasitas Total: ${parkiran.kapasitas}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ketersediaan',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${parkiran.slotTersedia} / ${parkiran.kapasitas}',
                        style: TextStyle(
                          fontSize: 14,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: parkiran.kapasitas > 0
                        ? parkiran.slotTersedia / parkiran.kapasitas
                        : 0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 10,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Info Cards Row
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.check_circle_outline,
                      label: 'Tersedia',
                      value: '${parkiran.slotTersedia}',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.directions_car,
                      label: 'Terisi',
                      value: '${parkiran.liveKapasitas}',
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Status Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    parkiran.slotTersedia > 10
                        ? '✅ Tersedia Banyak'
                        : parkiran.slotTersedia > 0
                            ? '⚠️ Hampir Penuh'
                            : '❌ Penuh',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    return _parkiranList
        .where((p) => p.latitude != null && p.longitude != null)
        .map((parkiran) {
      final Color markerColor = parkiran.slotTersedia > 10
          ? Colors.green
          : parkiran.slotTersedia > 0
              ? Colors.orange
              : Colors.red;

      return Marker(
        point: latlng.LatLng(parkiran.latitude!, parkiran.longitude!),
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _showParkiranInfo(parkiran),
          child: Container(
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: markerColor.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.local_parking,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Tambah padding bottom untuk menghindari navbar
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
      child: Card(
        elevation: 6.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: Stack(
            children: [
              FlutterMap(
                mapController: widget.mapController,
                options: MapOptions(
                  initialCenter: _kTelyuCenter,
                  initialZoom: _kTelyuZoom,
                  minZoom: 10,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.android.app',
                  ),
                  MarkerLayer(
                    markers: _buildMarkers(),
                  ),
                ],
              ),
              
              // Loading indicator
              if (_isLoading)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  ),
                ),

              // Zoom Controls
              Positioned(
                top: 60,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Zoom In
                      GestureDetector(
                        onTap: () {
                          final currentZoom = widget.mapController.camera.zoom;
                          widget.mapController.move(
                            widget.mapController.camera.center,
                            currentZoom + 1,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: primaryColor,
                            size: 22,
                          ),
                        ),
                      ),
                      Container(
                        height: 1,
                        width: 30,
                        color: Colors.grey.shade300,
                      ),
                      // Zoom Out
                      GestureDetector(
                        onTap: () {
                          final currentZoom = widget.mapController.camera.zoom;
                          widget.mapController.move(
                            widget.mapController.camera.center,
                            currentZoom - 1,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: const Icon(
                            Icons.remove,
                            color: primaryColor,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Legend (pindah lebih ke atas untuk hindari overlap)
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Keterangan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildLegendItem(Colors.green, 'Tersedia'),
                      _buildLegendItem(Colors.orange, 'Hampir Penuh'),
                      _buildLegendItem(Colors.red, 'Penuh'),
                    ],
                  ),
                ),
              ),

              // Refresh Button
              Positioned(
                top: 16,
                left: 16,
                child: GestureDetector(
                  onTap: _loadParkiran,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // My Location Button (center ke Tel-U)
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () {
                    widget.mapController.move(_kTelyuCenter, _kTelyuZoom);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: primaryColor,
                      size: 20,
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

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
