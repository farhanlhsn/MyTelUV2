import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_liveliness_detection/smart_liveliness_detection.dart';
import '../../models/kelas_hari_ini.dart';
import '../../services/akademik_service.dart';
import '../../services/biometrik_service.dart';
import '../../utils/attendance_error_mapper.dart';
import '../../utils/attendance_helper.dart';
import '../../utils/error_helper.dart';
import '../../utils/kelas_helper.dart';

/// Attendance page of one session. A session that requires a face goes through the liveness check
/// and POST /biometrik/absen; a GPS-only session (`requireFace: false`) skips the selfie and posts
/// to POST /akademik/absensi. Both show the location, the distance to the geofence centre (when the
/// session has coordinates) and keep the start button disabled until a position is known.
class BiometrikAbsenPage extends StatefulWidget {
  final int? idSesiAbsensi;

  /// Needed by the GPS-only endpoint.
  final int? idKelas;
  final bool requireFace;

  /// Geofence of the session; the distance is only shown when all three are known.
  final double? sesiLatitude;
  final double? sesiLongitude;
  final int? radiusMeter;
  final String? kelasTitle;

  const BiometrikAbsenPage({
    super.key,
    this.idSesiAbsensi,
    this.idKelas,
    this.requireFace = true,
    this.sesiLatitude,
    this.sesiLongitude,
    this.radiusMeter,
    this.kelasTitle,
  });

  /// The page for the active attendance session of a "kelas hari ini" item.
  factory BiometrikAbsenPage.forKelas(KelasHariIniModel kelas, {Key? key}) {
    final sesi = kelas.activeSesiAbsensi;
    return BiometrikAbsenPage(
      key: key,
      idSesiAbsensi: sesi?.idSesiAbsensi,
      idKelas: kelas.idKelas,
      requireFace: sesi?.requireFace ?? true,
      sesiLatitude: sesi?.latitude,
      sesiLongitude: sesi?.longitude,
      radiusMeter: sesi?.radiusMeter,
      kelasTitle: kelasHariIniTitle(kelas),
    );
  }

  @override
  State<BiometrikAbsenPage> createState() => _BiometrikAbsenPageState();
}

class _BiometrikAbsenPageState extends State<BiometrikAbsenPage>
    with WidgetsBindingObserver {
  final BiometrikService _biometrikService = BiometrikService();
  final AkademikService _akademikService = AkademikService();

  File? _capturedImage;
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;
  Map<String, dynamic>? _result;
  Position? _currentPosition;
  bool _isGettingLocation = false;
  LocationIssue? _locationIssue;
  String? _locationError;
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
    WidgetsBinding.instance.addObserver(this);
    _idSesiAbsensi =
        widget.idSesiAbsensi ?? _readIdSesiAbsensiFromArguments();
    if (_idSesiAbsensi == null) {
      _errorMessage = _missingSessionContextMessage;
    }
    if (widget.requireFace) {
      _camerasFuture = availableCameras();
      if (_idSesiAbsensi != null) {
        _prefetchLivenessToken();
      }
    }
    unawaited(_getCurrentLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings: try again. Only for the issues that are fixed there; a plain
    // "denied" would show the permission prompt again on every resume.
    if (state == AppLifecycleState.resumed &&
        _currentPosition == null &&
        !_isGettingLocation &&
        (_locationIssue == LocationIssue.serviceDisabled ||
            _locationIssue == LocationIssue.deniedForever)) {
      unawaited(_getCurrentLocation());
    }
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

    setState(() {
      _isGettingLocation = true;
      _locationIssue = null;
      _locationError = null;
    });
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
        if (e is LocationIssueException) {
          _locationIssue = e.issue;
          _locationError = locationIssueMessage(e.issue);
        } else {
          _locationError =
              'Gagal mendapatkan lokasi: ${ErrorHelper.parseError(e)}';
        }
        _isGettingLocation = false;
      });
      return null;
    } finally {
      _locationFuture = null;
    }
  }

  Future<Position?> _resolveCurrentLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationIssueException(LocationIssue.serviceDisabled);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final issue = locationIssueFor(
      serviceEnabled: serviceEnabled,
      permission: permission,
    );
    if (issue != null) {
      throw LocationIssueException(issue);
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
          timeLimit: Duration(seconds: 20),
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
    final availableChallenges = [
      ChallengeType.blink,
      ChallengeType.smile,
      ChallengeType.turnRight,
      ChallengeType.turnLeft,
    ]..shuffle(random);

    // Hanya menggunakan 1 challenge acak ditambah normal (total 2 langkah)
    return [availableChallenges.first, ChallengeType.normal];
  }

  LivenessConfig _studentLivenessConfig() {
    return LivenessConfig.performance().copyWith(
      enableScreenGlareDetection: false,
      enablePerformanceMonitoring: false,
      sandwichNormalChallenge: false,
      challengeTypes: _studentChallengeTypes(),
      frameSkipInterval: 1, // Set ke 1 agar memproses setiap frame tanpa error bagi nol
      imageProcessingTimeout: const Duration(milliseconds: 5000), // Beri waktu lebih lama
      memoryCleanupInterval: const Duration(seconds: 20),
      
      // Hapus threshold yang terbalik/ekstrem agar menggunakan nilai standar ML Kit
      eyeBlinkThresholdOpen: 0.8, // Probabilitas mata terbuka (default ML Kit)
      eyeBlinkThresholdClosed: 0.2, // Probabilitas mata tertutup (default ML Kit)
      enableContourAnalysisOnCentering: false,
      minFaceSize: 0.2, // Pastikan wajah cukup besar di layar
      enableMotionCorrelationCheck: false,
      enableGyroscopeCheck: false,
      challengeInstructions: {
        ChallengeType.blink: 'Silakan berkedip',
        ChallengeType.smile: 'Silakan tersenyum',
        ChallengeType.turnRight: 'Tengok ke kanan',
        ChallengeType.turnLeft: 'Tengok ke kiri',
        ChallengeType.normal: 'Posisikan wajah lurus ke depan',
      },
      messages: const LivenessMessages(
        moveFartherAway: 'Jauhkan wajah dari kamera',
        moveCloser: 'Dekatkan wajah ke kamera',
        moveRight: 'Geser wajah ke kanan',
        moveLeft: 'Geser wajah ke kiri',
        moveUp: 'Geser wajah ke atas',
        moveDown: 'Geser wajah ke bawah',
        perfectHoldStill: 'Sempurna! Tahan posisi Anda',
        noFaceDetected: 'Wajah tidak terdeteksi',
        errorCheckingFacePosition: 'Gagal mendeteksi posisi wajah',
        initializing: 'Menyiapkan...',
        initializingCamera: 'Menghubungkan kamera...',
        errorInitializingCamera: 'Kamera gagal dimulai. Silakan mulai ulang aplikasi.',
        initialInstruction: 'Posisikan wajah Anda di dalam oval',
        poorLighting: 'Pindah ke area yang lebih terang',
        processingVerification: 'Memproses verifikasi...',
        verificationComplete: 'Verifikasi wajah selesai!',
        spoofingDetected: 'Terdeteksi potensi manipulasi (spoofing).',
        errorProcessing: 'Terjadi kesalahan pemrosesan',
      ),
    );
  }

  Future<void> _startLivenessCheck() async {
    if (!_ensureSessionContext()) return;
    if (_currentPosition == null) return;

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
        _errorMessage =
            'Gagal memuat Liveness Check: ${ErrorHelper.parseError(e)}';
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
          _errorMessage = mapAttendanceErrorMessage(
            result['message']?.toString(),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = mapAttendanceErrorMessage(ErrorHelper.parseError(e));
      });
      _prefetchLivenessToken();
    }
  }

  /// GPS-only session: no selfie, no liveness token; straight to POST /akademik/absensi.
  Future<void> _submitGpsAbsen() async {
    if (!_ensureSessionContext()) return;

    final position = _currentPosition;
    if (position == null) {
      setState(() => _errorMessage = 'Tidak dapat mengambil lokasi');
      return;
    }

    final idKelas = widget.idKelas;
    if (idKelas == null) {
      setState(() => _errorMessage = _missingSessionContextMessage);
      return;
    }

    setState(() {
      _isLoading = true;
      _isSuccess = false;
      _result = null;
      _errorMessage = null;
    });

    try {
      final body = await _akademikService.createAbsensi(
        idKelas: idKelas,
        idSesiAbsensi: _idSesiAbsensi!,
        latitude: position.latitude,
        longitude: position.longitude,
        isMockLocation: position.isMocked,
      );
      if (!mounted) return;

      final result = normalizeGpsAbsensiResult(body);
      final bool success = result['status'] == 'success';
      setState(() {
        _result = result;
        _isSuccess = success;
        _isLoading = false;
        if (!success) {
          _errorMessage = mapAttendanceErrorMessage(
            result['message']?.toString(),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = mapAttendanceErrorMessage(ErrorHelper.parseError(e));
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
                  Text(
                    widget.requireFace ? "Absen Biometrik" : "Absen GPS",
                    style: const TextStyle(
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
                      if (widget.kelasTitle != null &&
                          widget.kelasTitle!.isNotEmpty) ...[
                        Text(
                          widget.kelasTitle!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Location status
                      _buildLocationStatus(),

                      const SizedBox(height: 20),

                      // Camera preview or captured image (face sessions) / GPS panel (GPS-only)
                      if (widget.requireFace)
                        _buildCameraPreview()
                      else
                        _buildGpsPanel(),

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
    final position = _currentPosition;
    final bool hasPosition = position != null;
    final geofence = _isGettingLocation
        ? null
        : geofenceStatusFor(
            userLat: position?.latitude,
            userLng: position?.longitude,
            sesiLat: widget.sesiLatitude,
            sesiLng: widget.sesiLongitude,
            radiusMeter: widget.radiusMeter,
          );

    final MaterialColor tone = !hasPosition
        ? Colors.orange
        : (geofence != null && !geofence.inRange)
        ? Colors.red
        : Colors.green;

    final String text = _isGettingLocation
        ? 'Mendapatkan lokasi…'
        : position != null
        ? 'Lokasi: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'
        : (_locationError ?? 'Lokasi tidak tersedia');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _isGettingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      hasPosition ? Icons.location_on : Icons.location_off,
                      color: tone,
                      size: 20,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 12, color: tone.shade700),
                ),
              ),
              if (!_isGettingLocation)
                GestureDetector(
                  onTap: _getCurrentLocation,
                  child: Tooltip(
                    message: 'Perbarui lokasi',
                    child: Icon(Icons.refresh, color: tone.shade700, size: 20),
                  ),
                ),
            ],
          ),
          if (geofence != null) ...[
            const SizedBox(height: 6),
            Text(
              geofence.summary,
              style: TextStyle(fontSize: 12, color: tone.shade700),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  geofence.inRange ? Icons.check_circle : Icons.warning_amber,
                  size: 14,
                  color: tone.shade700,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    geofence.inRange
                        ? 'Dalam jangkauan absensi'
                        : 'Di luar jangkauan absensi. Dekati lokasi kelas.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tone.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          ..._buildLocationIssueAction(),
        ],
      ),
    );
  }

  /// Button that fixes the location problem: the system settings for a switched-off GPS or a
  /// permanently denied permission, a new permission request for a plain denial.
  List<Widget> _buildLocationIssueAction() {
    if (_currentPosition != null || _isGettingLocation) return const [];

    final String label;
    final VoidCallback onPressed;
    switch (_locationIssue) {
      case LocationIssue.serviceDisabled:
        label = 'Buka Pengaturan Lokasi';
        onPressed = () => Geolocator.openLocationSettings();
      case LocationIssue.deniedForever:
        label = 'Buka Pengaturan';
        onPressed = () => Geolocator.openAppSettings();
      case LocationIssue.denied:
        label = 'Izinkan Lokasi';
        onPressed = () => _getCurrentLocation();
      case null:
        return const [];
    }

    return [
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.settings, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade800,
            side: BorderSide(color: Colors.orange.shade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    ];
  }

  /// Stand-in for the camera preview of a GPS-only session.
  Widget _buildGpsPanel() {
    final bool done = _isSuccess;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done ? Colors.green : primaryRed.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          if (_isLoading)
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          else
            Icon(
              done ? Icons.check_circle : Icons.location_on,
              size: 64,
              color: done ? Colors.green : Colors.grey.shade400,
            ),
          const SizedBox(height: 12),
          Text(
            _isLoading
                ? 'Mencatat absensi…'
                : done
                ? 'Absensi Berhasil'
                : 'Sesi ini cukup memakai lokasi GPS, tanpa verifikasi wajah.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: done ? Colors.green.shade700 : Colors.grey,
              fontSize: 13,
              fontWeight: done ? FontWeight.bold : FontWeight.normal,
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
    final bool canStart = canStartAttendance(
      hasLocation: _currentPosition != null,
      isGettingLocation: _isGettingLocation,
      isBusy: _isLoading,
    );

    // GPS-only session: one tap records the attendance, also the retry after an error
    if (!widget.requireFace) {
      return _buildPrimaryButton(
        icon: Icons.location_on,
        label: attendanceStartLabel(
          hasLocation: _currentPosition != null,
          isGettingLocation: _isGettingLocation,
          readyLabel: 'Absen Sekarang',
        ),
        onPressed: canStart ? _submitGpsAbsen : null,
      );
    }

    // After an error, show retry button
    if (_errorMessage != null && _capturedImage != null) {
      return _buildPrimaryButton(
        icon: Icons.refresh,
        label: 'Coba Lagi',
        onPressed: canStart ? _startLivenessCheck : null,
      );
    }

    // Initial state — start the one-tap flow
    if (_capturedImage == null) {
      return _buildPrimaryButton(
        icon: Icons.fingerprint,
        label: attendanceStartLabel(
          hasLocation: _currentPosition != null,
          isGettingLocation: _isGettingLocation,
          readyLabel: 'Mulai Absen',
        ),
        onPressed: canStart ? _startLivenessCheck : null,
      );
    }

    // Captured but no error (shouldn't normally be visible since auto-submit runs)
    return const SizedBox.shrink();
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
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
            _buildInfoRow(
              Icons.how_to_reg,
              'Status',
              kehadiranStatusLabel(data['status']?.toString()),
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
