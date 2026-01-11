import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

/// Data hasil dari GeofencePickerPage
class GeofenceData {
  final double latitude;
  final double longitude;
  final int radiusMeter;
  final String? locationName;

  GeofenceData({
    required this.latitude,
    required this.longitude,
    required this.radiusMeter,
    this.locationName,
  });
}

/// Halaman untuk memilih lokasi dan radius geofence
class GeofencePickerPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final int initialRadius;

  const GeofencePickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialRadius = 100,
  });

  @override
  State<GeofencePickerPage> createState() => _GeofencePickerPageState();
}

class _GeofencePickerPageState extends State<GeofencePickerPage> {
  final MapController _mapController = MapController();
  final Dio _dio = Dio();

  // Default ke Tel-U Bandung
  late LatLng _selectedLocation;
  late double _radius;
  String _locationName = '';
  bool _isLoading = false;

  static const Color primaryColor = Color(0xFFE63946);

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(
      widget.initialLatitude ?? -6.9732,
      widget.initialLongitude ?? 107.6308,
    );
    _radius = widget.initialRadius.toDouble();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );

        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
        });

        _mapController.move(_selectedLocation, 17);
        await _reverseGeocode(_selectedLocation);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': location.latitude,
          'lon': location.longitude,
          'format': 'json',
          'addressdetails': 1,
        },
        options: Options(
          headers: {'User-Agent': 'MyTelUV2-App'},
        ),
      );

      if (response.data != null) {
        final data = response.data!;
        final displayName = data['display_name'] as String? ?? '';
        final parts = displayName.split(', ');
        final simpleName = parts.take(3).join(', ');

        setState(() {
          _locationName = simpleName;
        });
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng location) {
    setState(() {
      _selectedLocation = location;
      _locationName = 'Memuat...';
    });
    _reverseGeocode(location);
  }

  void _confirmLocation() {
    Navigator.pop(
      context,
      GeofenceData(
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        radiusMeter: _radius.round(),
        locationName: _locationName.isNotEmpty ? _locationName : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map with Circle
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 17,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mobile',
              ),
              // Geofence Circle
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _selectedLocation,
                    radius: _radius,
                    useRadiusInMeter: true,
                    color: primaryColor.withOpacity(0.2),
                    borderColor: primaryColor,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              // Center Marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_pin,
                      color: primaryColor,
                      size: 50,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top Bar
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                title: const Text(
                  'Pilih Lokasi Geofence',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: IconButton(
                  onPressed: _getCurrentLocation,
                  icon: Icon(
                    Icons.my_location,
                    color: _isLoading ? Colors.grey : primaryColor,
                  ),
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: primaryColor),
              ),
            ),

          // Bottom Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Location Info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_on, color: primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lokasi Geofence',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                _locationName.isEmpty
                                    ? 'Tap peta untuk pilih lokasi'
                                    : _locationName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Radius Slider
                    Row(
                      children: [
                        const Icon(Icons.radar, color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        const Text('Radius:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Expanded(
                          child: Slider(
                            value: _radius,
                            min: 50,
                            max: 500,
                            divisions: 9,
                            activeColor: primaryColor,
                            onChanged: (value) {
                              setState(() => _radius = value);
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_radius.round()}m',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Confirm Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirmLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Konfirmasi Lokasi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
