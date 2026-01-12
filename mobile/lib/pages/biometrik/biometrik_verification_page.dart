import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/biometrik_service.dart';

class BiometrikAbsenPage extends StatefulWidget {
  const BiometrikAbsenPage({super.key});

  @override
  State<BiometrikAbsenPage> createState() => _BiometrikAbsenPageState();
}

class _BiometrikAbsenPageState extends State<BiometrikAbsenPage>
    with WidgetsBindingObserver {
  final BiometrikService _biometrikService = BiometrikService();

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraError = false;
  String? _cameraErrorMessage;

  File? _capturedImage;
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;
  Map<String, dynamic>? _result;
  Position? _currentPosition;
  bool _isGettingLocation = false;

  final Color primaryRed = const Color(0xFFE63946);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMessage = 'Tidak ada kamera tersedia';
        });
        return;
      }

      // Find front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isCameraError = false;
        });
      }
    } catch (e) {
      setState(() {
        _isCameraError = true;
        _cameraErrorMessage = 'Gagal membuka kamera: ${e.toString()}';
      });
    }
  }

  /// Map API error messages to user-friendly Indonesian text
  String _mapErrorMessage(String? message) {
    if (message == null) return 'Terjadi kesalahan';

    final errorMap = {
      'Face recognition service unavailable':
          'Layanan pengenalan wajah tidak tersedia. Coba lagi nanti.',
      'No face detected': 'Wajah tidak terdeteksi. Pastikan wajah terlihat jelas.',
      'Face detection failed': 'Gagal mendeteksi wajah. Coba ambil foto ulang.',
      'Wajah tidak cocok': 'Wajah tidak cocok dengan data terdaftar.',
      'Image file is required': 'Silakan ambil foto terlebih dahulu.',
      'Invalid coordinates': 'Lokasi tidak valid. Aktifkan GPS.',
      'Anda belum terdaftar biometrik':
          'Anda belum terdaftar biometrik. Hubungi admin.',
      'Tidak ada sesi absensi': 'Tidak ada kelas yang sedang berlangsung.',
      'Lokasi Anda di luar area absensi': 'Anda berada di luar area kampus.',
    };

    for (final entry in errorMap.entries) {
      if (message.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return message;
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Lokasi tidak aktif. Silakan aktifkan GPS.';
          _isGettingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Izin lokasi ditolak';
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Izin lokasi diblokir. Aktifkan di pengaturan.';
          _isGettingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition = position;
        _isGettingLocation = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mendapatkan lokasi: ${e.toString()}';
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();
      setState(() {
        _capturedImage = File(photo.path);
        _errorMessage = null;
        _isSuccess = false;
        _result = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengambil foto: ${e.toString()}';
      });
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
      _errorMessage = null;
      _isSuccess = false;
      _result = null;
    });
  }

  Future<void> _submitAbsen() async {
    if (_capturedImage == null) {
      setState(() => _errorMessage = 'Silakan ambil foto wajah terlebih dahulu');
      return;
    }

    if (_currentPosition == null) {
      await _getCurrentLocation();
      if (_currentPosition == null) {
        setState(() => _errorMessage = 'Tidak dapat mengambil lokasi');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _biometrikService.biometrikAbsen(
        imageFile: _capturedImage!,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );

      setState(() {
        _result = result;
        _isSuccess = result['status'] == 'success';
        _isLoading = false;
      });

      if (!_isSuccess) {
        setState(() {
          _errorMessage = _mapErrorMessage(result['message']?.toString());
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            _mapErrorMessage(e.toString().replaceFirst('Exception: ', ''));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryRed,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Absen Biometrik",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Body
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Location status
                      _buildLocationStatus(),

                      const SizedBox(height: 20),

                      // Camera preview or captured image
                      _buildCameraPreview(),

                      const SizedBox(height: 24),

                      // Capture/Retake button
                      if (!_isSuccess) _buildCaptureButton(),

                      const SizedBox(height: 24),

                      // Error message
                      if (_errorMessage != null && !_isSuccess)
                        _buildErrorMessage(),

                      // Success result
                      if (_isSuccess && _result != null) _buildSuccessResult(),

                      const SizedBox(height: 16),

                      // Submit button
                      if (_capturedImage != null)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed:
                                (_isLoading || _isSuccess) ? null : _submitAbsen,
                            icon: _isLoading
                                ? const SizedBox.shrink()
                                : Icon(
                                    _isSuccess ? Icons.check : Icons.fingerprint,
                                    color: Colors.white,
                                  ),
                            label: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isSuccess ? 'Berhasil!' : 'Absen Sekarang',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isSuccess ? Colors.green : primaryRed,
                              disabledBackgroundColor:
                                  _isSuccess ? Colors.green : Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _currentPosition != null
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _currentPosition != null
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          _isGettingLocation
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _currentPosition != null
                      ? Icons.location_on
                      : Icons.location_off,
                  color: _currentPosition != null ? Colors.green : Colors.orange,
                  size: 20,
                ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isGettingLocation
                  ? 'Mendapatkan lokasi...'
                  : _currentPosition != null
                      ? 'Lokasi: ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}'
                      : 'Lokasi tidak tersedia',
              style: TextStyle(
                fontSize: 12,
                color: _currentPosition != null
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
            ),
          ),
          if (_currentPosition == null && !_isGettingLocation)
            GestureDetector(
              onTap: _getCurrentLocation,
              child:
                  Icon(Icons.refresh, color: Colors.orange.shade700, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Container(
      width: 240,
      height: 320,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isSuccess ? Colors.green : primaryRed.withOpacity(0.5),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: _buildCameraContent(),
      ),
    );
  }

  Widget _buildCameraContent() {
    // Show captured image
    if (_capturedImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_capturedImage!, fit: BoxFit.cover),
          if (_isSuccess)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.green.withOpacity(0.9),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Absensi Berhasil',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Memverifikasi wajah...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    // Camera error
    if (_isCameraError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _cameraErrorMessage ?? 'Kamera tidak tersedia',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Camera loading
    if (!_isCameraInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Memuat kamera...',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Live camera preview with face guide
    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera preview
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(-1.0, 1.0), // Mirror for selfie
          child: CameraPreview(_cameraController!),
        ),
        // Face oval guide overlay
        CustomPaint(
          size: const Size(180, 240),
          painter: FaceOvalPainter(
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        // Instructions
        Positioned(
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Posisikan wajah dalam bingkai',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureButton() {
    if (_capturedImage == null) {
      // Capture button
      return GestureDetector(
        onTap: _isCameraInitialized ? _capturePhoto : null,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: primaryRed, width: 4),
          ),
          child: Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isCameraInitialized ? primaryRed : Colors.grey,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
            ),
          ),
        ),
      );
    } else {
      // Retake button
      return GestureDetector(
        onTap: _retakePhoto,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                'Ambil Ulang',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_errorMessage!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessResult() {
    final data = _result!['data'] as Map<String, dynamic>?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'Absensi Berhasil!',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (data != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.class_, 'Kelas', data['kelas']?.toString() ?? '-'),
            _buildInfoRow(Icons.room, 'Ruangan', data['ruangan']?.toString() ?? '-'),
            _buildInfoRow(
                Icons.access_time, 'Waktu', _formatTime(data['waktu']?.toString())),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '-';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }
}

/// Custom painter for face oval guide
class FaceOvalPainter extends CustomPainter {
  final Color color;

  FaceOvalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final dashPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.85,
      height: size.height * 0.9,
    );

    // Draw dashed oval
    const double dashLength = 8;
    const double dashSpace = 5;
    final Path ovalPath = Path()..addOval(rect);

    // Draw the oval with dashes
    final pathMetrics = ovalPath.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final extractPath =
            metric.extractPath(distance, distance + dashLength);
        canvas.drawPath(extractPath, dashPaint);
        distance += dashLength + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant FaceOvalPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
