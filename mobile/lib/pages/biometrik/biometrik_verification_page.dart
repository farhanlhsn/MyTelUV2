import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_liveliness_detection/smart_liveliness_detection.dart';
import '../../services/biometrik_service.dart';

class BiometrikAbsenPage extends StatefulWidget {
  final int? idSesiAbsensi;

  const BiometrikAbsenPage({super.key, this.idSesiAbsensi});

  @override
  State<BiometrikAbsenPage> createState() => _BiometrikAbsenPageState();
}

class _BiometrikAbsenPageState extends State<BiometrikAbsenPage>
    with WidgetsBindingObserver {
  final BiometrikService _biometrikService = BiometrikService();

  File? _capturedImage;
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;
  Map<String, dynamic>? _result;
  Position? _currentPosition;
  bool _isGettingLocation = false;
  Future<List<CameraDescription>>? _camerasFuture;
  Future<Position?>? _locationFuture;
  Future<String?>? _livenessTokenFuture;
  String? _livenessToken;
  DateTime? _livenessTokenFetchedAt;
  int? _idSesiAbsensi;

  final Color primaryRed = const Color(0xFFE63946);
  static const Duration _livenessTokenMaxAge = Duration(minutes: 4);

  @override
  void initState() {
    super.initState();
    _idSesiAbsensi =
        widget.idSesiAbsensi ?? _readIdSesiAbsensiFromArguments();
    if (_idSesiAbsensi == null) {
      _errorMessage = _missingSessionContextMessage;
    }
    _camerasFuture = availableCameras();
    if (_idSesiAbsensi != null) {
      _prefetchLivenessToken();
    }
    unawaited(_getCurrentLocation());
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Map API error messages to user-friendly Indonesian text
  String _mapErrorMessage(String? message) {
    if (message == null) return 'Terjadi kesalahan';

    final messageLower = message.toLowerCase();

    // Preserve detailed distance info if present in location errors
    if (messageLower.contains('lokasi anda di luar area absensi')) {
      if (messageLower.contains('jarak') || messageLower.contains('radius')) {
        return message;
      }
      return 'Lokasi Anda di luar area absensi. Silakan mendekat ke area kelas.';
    }

    final errorMap = {
      'Layanan pengenalan wajah sedang tidak tersedia':
          'Layanan sedang sibuk atau tidak tersedia. Silakan coba beberapa saat lagi.',
      'Face recognition service unavailable':
          'Layanan pengenalan wajah tidak tersedia. Coba lagi nanti.',
      'No face detected':
          'Wajah tidak terdeteksi. Pastikan wajah terlihat jelas.',
      'Face detection failed': 'Gagal mendeteksi wajah. Coba ambil foto ulang.',
      'Wajah tidak cocok': 'Wajah tidak cocok dengan data terdaftar.',
      'Image file is required': 'Silakan ambil foto terlebih dahulu.',
      'Invalid coordinates': 'Lokasi tidak valid. Aktifkan GPS.',
      'Anda belum terdaftar biometrik':
          'Anda belum terdaftar biometrik. Hubungi admin.',
      'Tidak ada sesi absensi': 'Tidak ada kelas yang sedang berlangsung.',
      'id_sesi_absensi wajib diisi':
          'Konteks sesi absensi tidak tersedia. Silakan pilih sesi absensi dari daftar absensi.',
      'Sesi absensi yang dipilih tidak valid':
          'Sesi absensi tidak valid, tidak sedang berlangsung, atau Anda tidak terdaftar.',
      'Anda sudah melakukan absensi':
          'Anda sudah melakukan absensi pada sesi ini.',
    };

    for (final entry in errorMap.entries) {
      if (messageLower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return message;
  }

  String get _missingSessionContextMessage =>
      'Konteks sesi absensi tidak tersedia. Silakan pilih sesi absensi dari daftar absensi.';

  int? _parsePositiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  int? _readIdSesiAbsensiFromArguments() {
    final arguments = Get.arguments;
    if (arguments is Map) {
      return _parsePositiveInt(
        arguments['idSesiAbsensi'] ??
            arguments['id_sesi_absensi'] ??
            arguments['id_sesi'],
      );
    }
    return _parsePositiveInt(arguments);
  }

  bool _ensureSessionContext() {
    if (_idSesiAbsensi != null) return true;
    setState(() {
      _isLoading = false;
      _errorMessage = _missingSessionContextMessage;
    });
    return false;
  }

  bool get _hasFreshLivenessToken {
    final fetchedAt = _livenessTokenFetchedAt;
    return _livenessToken != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _livenessTokenMaxAge;
  }

  void _prefetchLivenessToken() {
    if (_hasFreshLivenessToken || _livenessTokenFuture != null) return;

    _livenessTokenFuture = _biometrikService
        .requestLivenessToken()
        .then<String?>((token) {
          _livenessToken = token;
          _livenessTokenFetchedAt = DateTime.now();
          return token;
        })
        .catchError((_) {
          return null;
        })
        .whenComplete(() {
          _livenessTokenFuture = null;
        });
  }

  Future<String> _consumeLivenessToken() async {
    if (_hasFreshLivenessToken) {
      final token = _livenessToken!;
      _livenessToken = null;
      _livenessTokenFetchedAt = null;
      return token;
    }

    final pendingToken = _livenessTokenFuture;
    if (pendingToken != null) {
      final token = await pendingToken;
      if (token != null) {
        _livenessToken = null;
        _livenessTokenFetchedAt = null;
        return token;
      }
    }

    return _biometrikService.requestLivenessToken();
  }

  Future<List<CameraDescription>> _getAvailableCameras() async {
    try {
      return await (_camerasFuture ??= availableCameras());
    } catch (_) {
      _camerasFuture = null;
      rethrow;
    }
  }

  Future<Position?> _getCurrentLocation() async {
    if (_locationFuture != null) return _locationFuture!;

    setState(() => _isGettingLocation = true);
    _locationFuture = _resolveCurrentLocation();

    try {
      final position = await _locationFuture!;
      if (!mounted) return position;

      setState(() {
        _currentPosition = position;
        _isGettingLocation = false;
        if (_idSesiAbsensi != null) {
          _errorMessage = null;
        }
      });
      return position;
    } catch (e) {
      if (!mounted) return _currentPosition;

      if (_currentPosition != null) {
        setState(() => _isGettingLocation = false);
        return _currentPosition;
      }

      setState(() {
        _errorMessage = _idSesiAbsensi == null
            ? _missingSessionContextMessage
            : 'Gagal mendapatkan lokasi: ${e.toString()}';
        _isGettingLocation = false;
      });
      return null;
    } finally {
      _locationFuture = null;
    }
  }

  Future<Position?> _resolveCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Lokasi tidak aktif. Silakan aktifkan GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi diblokir. Aktifkan di pengaturan.');
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null && mounted) {
      setState(() {
        _currentPosition = lastKnown;
        if (_idSesiAbsensi != null) {
          _errorMessage = null;
        }
      });
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      if (_currentPosition != null) return _currentPosition;
      rethrow;
    }
  }

  math.Random _challengeRandom() {
    try {
      return math.Random.secure();
    } catch (_) {
      return math.Random();
    }
  }

  List<ChallengeType> _studentChallengeTypes() {
    final random = _challengeRandom();
    final secondaryChallenges = [
      ChallengeType.turnLeft,
      ChallengeType.turnRight,
      ChallengeType.smile,
      ChallengeType.nod,
    ]..shuffle(random);

    final activeChallenges = [ChallengeType.blink, secondaryChallenges.first]
      ..shuffle(random);

    return [...activeChallenges, ChallengeType.normal];
  }

  LivenessConfig _studentLivenessConfig() {
    return LivenessConfig.performance().copyWith(
      enableScreenGlareDetection: false,
      enablePerformanceMonitoring: false,
      sandwichNormalChallenge: false,
      challengeTypes: _studentChallengeTypes(),
      frameSkipInterval: 2,
      imageProcessingTimeout: const Duration(milliseconds: 800),
      memoryCleanupInterval: const Duration(seconds: 20),
    );
  }

  Future<void> _startLivenessCheck() async {
    if (!_ensureSessionContext()) return;

    setState(() {
      _errorMessage = null;
      _isSuccess = false;
      _result = null;
      _capturedImage = null;
    });

    _prefetchLivenessToken();
    if (_currentPosition == null && !_isGettingLocation) {
      unawaited(_getCurrentLocation());
    }

    try {
      final List<CameraDescription> cameras = await _getAvailableCameras();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'Tidak ada kamera tersedia untuk Liveness Check';
        });
        return;
      }

      await Get.to(
        () => LivenessDetectionScreen(
          cameras: cameras,
          config: _studentLivenessConfig(),
          showAppBar: false,
          captureFinalImage: true,
          customSuccessOverlay: const SizedBox.shrink(),
          onFinalImageCaptured:
              (
                String sessionId,
                XFile imageFile,
                Map<String, dynamic> metadata,
              ) {
                _capturedImage = File(imageFile.path);

                if (Get.currentRoute != '/BiometrikAbsenPage') {
                  Get.back();
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  unawaited(_submitAbsen());
                });
              },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat Liveness Check: ${e.toString()}';
      });
    }
  }

  Future<void> _submitAbsen() async {
    if (!_ensureSessionContext()) return;

    if (_capturedImage == null) {
      setState(
        () => _errorMessage = 'Silakan lakukan Liveness Check terlebih dahulu',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tokenFuture = _consumeLivenessToken();
      final locationFuture = _currentPosition == null
          ? _getCurrentLocation()
          : Future<Position?>.value(_currentPosition);

      final position = await locationFuture;
      if (position == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Tidak dapat mengambil lokasi';
        });
        return;
      }

      final String token = await tokenFuture;

      final result = await _biometrikService.biometrikAbsen(
        imageFile: _capturedImage!,
        idSesiAbsensi: _idSesiAbsensi!,
        latitude: position.latitude,
        longitude: position.longitude,
        livenessToken: token,
        isMockLocation: position.isMocked,
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
        _errorMessage = _mapErrorMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
      });
      _prefetchLivenessToken();
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 20.0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
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

                      // Action buttons area
                      if (!_isSuccess && !_isLoading) _buildCaptureButton(),

                      const SizedBox(height: 24),

                      // Error message
                      if (_errorMessage != null && !_isSuccess)
                        _buildErrorMessage(),

                      // Success result
                      if (_isSuccess && _result != null) _buildSuccessResult(),

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
                  color: _currentPosition != null
                      ? Colors.green
                      : Colors.orange,
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
              child: Icon(
                Icons.refresh,
                color: Colors.orange.shade700,
                size: 20,
              ),
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
    // Show captured image (loading or success state)
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
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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
                      'Mencatat absensi...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    // Default placeholder before liveness verification
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.face, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Tekan tombol di bawah untuk memulai verifikasi wajah dan absensi otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton() {
    // After an error, show retry button
    if (_errorMessage != null && _capturedImage != null) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _startLivenessCheck,
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text(
            'Coba Lagi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryRed,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    // Initial state — start the one-tap flow
    if (_capturedImage == null) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _startLivenessCheck,
          icon: const Icon(Icons.fingerprint, color: Colors.white),
          label: const Text(
            'Mulai Absen',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryRed,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    // Captured but no error (shouldn't normally be visible since auto-submit runs)
    return const SizedBox.shrink();
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
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
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
            _buildInfoRow(
              Icons.class_,
              'Kelas',
              data['kelas']?.toString() ?? '-',
            ),
            _buildInfoRow(
              Icons.room,
              'Ruangan',
              data['ruangan']?.toString() ?? '-',
            ),
            _buildInfoRow(
              Icons.access_time,
              'Waktu',
              _formatTime(data['waktu']?.toString()),
            ),
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
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
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
        final extractPath = metric.extractPath(distance, distance + dashLength);
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
