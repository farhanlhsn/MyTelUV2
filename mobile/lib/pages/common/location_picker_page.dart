import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

/// Model untuk menyimpan data lokasi
class LocationData {
  final String name;
  final double lat;
  final double lng;

  LocationData({required this.name, required this.lat, required this.lng});
}

/// Halaman untuk memilih lokasi dengan peta dan pencarian
class LocationPickerPage extends StatefulWidget {
  final String? initialLocation;
  
  const LocationPickerPage({super.key, this.initialLocation});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio();
  
  // Default ke Bandung (Tel-U area)
  LatLng _selectedLocation = const LatLng(-6.9732, 107.6308);
  String _locationName = '';
  bool _isLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;
  
  static const Color primaryColor = Color(0xFFE63946);

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Mendapatkan lokasi saat ini
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        // Use default location
        setState(() => _isLoading = false);
        return;
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
        
        _mapController.move(_selectedLocation, 16);
        await _reverseGeocode(_selectedLocation);
      }
    } catch (e) {
      print('Error getting location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Reverse geocoding - mendapatkan nama lokasi dari koordinat
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
        
        // Simplify the name - take first 2-3 parts
        final parts = displayName.split(', ');
        final simpleName = parts.take(3).join(', ');
        
        setState(() {
          _locationName = simpleName;
        });
      }
    } catch (e) {
      print('Reverse geocode error: $e');
    }
  }

  /// Search lokasi dengan Nominatim API
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    setState(() => _isSearching = true);
    
    try {
      final response = await _dio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 5,
          'countrycodes': 'id', // Prioritize Indonesia
          'addressdetails': 1,
        },
        options: Options(
          headers: {'User-Agent': 'MyTelUV2-App'},
        ),
      );
      
      if (response.data != null) {
        setState(() {
          _searchResults = response.data!.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  /// Handle search input dengan debounce
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchLocation(query);
    });
  }

  /// Pilih lokasi dari hasil search
  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat'].toString()) ?? 0;
    final lng = double.tryParse(result['lon'].toString()) ?? 0;
    final name = result['display_name'] as String? ?? '';
    
    final parts = name.split(', ');
    final simpleName = parts.take(3).join(', ');
    
    setState(() {
      _selectedLocation = LatLng(lat, lng);
      _locationName = simpleName;
      _searchResults = [];
      _searchController.clear();
    });
    
    _mapController.move(_selectedLocation, 16);
    FocusScope.of(context).unfocus();
  }

  /// Handle tap pada peta
  void _onMapTap(TapPosition tapPosition, LatLng location) {
    setState(() {
      _selectedLocation = location;
      _locationName = 'Memuat...';
    });
    _reverseGeocode(location);
  }

  /// Konfirmasi dan return lokasi
  void _confirmLocation() {
    if (_locationName.isEmpty || _locationName == 'Memuat...') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tunggu lokasi dimuat...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    Navigator.pop(context, LocationData(
      name: _locationName,
      lat: _selectedLocation.latitude,
      lng: _selectedLocation.longitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mobile',
              ),
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
          
          // Top Bar with Search
          SafeArea(
            child: Column(
              children: [
                Container(
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search Bar
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Cari lokasi...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          if (_isSearching)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else if (_searchController.text.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                              icon: const Icon(Icons.clear),
                            )
                          else
                            IconButton(
                              onPressed: _getCurrentLocation,
                              icon: const Icon(Icons.my_location, color: primaryColor),
                            ),
                        ],
                      ),
                      
                      // Search Results
                      if (_searchResults.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              final name = result['display_name'] as String? ?? '';
                              final parts = name.split(', ');
                              final title = parts.first;
                              final subtitle = parts.skip(1).take(2).join(', ');
                              
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on, color: primaryColor),
                                title: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                                onTap: () => _selectSearchResult(result),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
          
          // Bottom Card with Location Info
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                'Lokasi Dipilih',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _locationName.isEmpty ? 'Tap peta untuk pilih lokasi' : _locationName,
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _locationName.isNotEmpty && _locationName != 'Memuat...' 
                            ? _confirmLocation 
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          disabledBackgroundColor: primaryColor.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Pilih Lokasi Ini',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Geser peta atau tap untuk memilih lokasi',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
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
