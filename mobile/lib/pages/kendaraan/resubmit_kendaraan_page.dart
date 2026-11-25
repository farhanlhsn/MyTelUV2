import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/services/kendaraan_service.dart';
import 'package:mobile/utils/kendaraan_helper.dart';

import 'registerplat.dart' show RegisterPlatBerhasilPage;
import 'widgets/foto_upload_field.dart';
import 'package:mobile/utils/app_theme.dart';

class ResubmitKendaraanPage extends StatefulWidget {
  const ResubmitKendaraanPage({super.key});

  @override
  State<ResubmitKendaraanPage> createState() => _ResubmitKendaraanPageState();
}

class _ResubmitKendaraanPageState extends State<ResubmitKendaraanPage> {
  int? _idKendaraan;

  // Image paths - simplified, no longer need separate controllers
  String? _depanImagePath;
  String? _sampingImagePath;
  String? _belakangImagePath;
  String? _stnkImagePath;

  // Photos only show their "wajib" error once the user tried to submit
  bool _submitted = false;

  // Loading state
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final dynamic id = args?['id_kendaraan'];
      if (id is int) {
        _idKendaraan = id;
      } else {
        Get.back();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data kendaraan tidak ditemukan')),
        );
      }
    });
  }

  // Pick image from gallery or camera
  Future<void> _pickImage(String type) async {
    final ImageSource? source = await showFotoSourceSheet(context);
    if (source == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          if (type.contains('Depan')) {
            _depanImagePath = image.path;
          } else if (type.contains('Samping')) {
            _sampingImagePath = image.path;
          } else if (type.contains('Belakang')) {
            _belakangImagePath = image.path;
          } else if (type.contains('STNK')) {
            _stnkImagePath = image.path;
          }
        });
      }
    } catch (_) {
      _showSnackBar('Gagal memilih foto. Silakan coba lagi.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : null,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  String? _fotoError(String? path) {
    return _submitted && path == null ? 'Foto wajib dipilih' : null;
  }

  Future<void> _onSubmit() async {
    final int? idKendaraan = _idKendaraan;
    if (idKendaraan == null) {
      _showSnackBar('Data kendaraan tidak ditemukan', isError: true);
      return;
    }

    final bool photosValid =
        _depanImagePath != null &&
        _sampingImagePath != null &&
        _belakangImagePath != null &&
        _stnkImagePath != null;
    setState(() => _submitted = true);

    if (!photosValid) {
      _showSnackBar('Lengkapi semua foto yang ditandai terlebih dahulu.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call API untuk resubmit kendaraan
      await KendaraanService.resubmitKendaraan(
        idKendaraan: idKendaraan,
        fotoKendaraanPaths: [
          _depanImagePath!,
          _sampingImagePath!,
          _belakangImagePath!,
        ],
        fotoSTNKPath: _stnkImagePath!,
      );
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Navigate to the shared success page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const RegisterPlatBerhasilPage(
            appBarTitle: 'Ajukan Ulang',
            title: 'Pengajuan Ulang Berhasil!',
            message: 'Pengajuan ulang Anda sedang diproses',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnackBar(kendaraanErrorMessage(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = AppColors.primary;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // --- Bagian Atas Merah (AppBar/Header) ---
          Container(
            height: 150,
            decoration: const BoxDecoration(color: primaryColor),
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(top: 40, left: 10),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Kembali',
                  icon: const Icon(
                    appBackIcon,
                    color: Colors.white,
                    size: 20.0,
                  ),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                const Text(
                  'Ajukan Ulang',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // --- Bagian Konten Utama (putih) ---
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Ajukan Ulang Kendaraan',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Unggah ulang foto-foto kendaraan dan STNK Anda',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),

                    // Illustration
                    Center(
                      child: Image.asset('assets/images/Illustration.png'),
                    ),
                    const SizedBox(height: 15),

                    // Image upload fields with preview
                    FotoUploadField(
                      label: 'Foto Motor (Tampak Depan)',
                      imagePath: _depanImagePath,
                      errorText: _fotoError(_depanImagePath),
                      onTap: () => _pickImage('Depan'),
                    ),
                    const SizedBox(height: 15),
                    FotoUploadField(
                      label: 'Foto Motor (Tampak Samping)',
                      imagePath: _sampingImagePath,
                      errorText: _fotoError(_sampingImagePath),
                      onTap: () => _pickImage('Samping'),
                    ),
                    const SizedBox(height: 15),
                    FotoUploadField(
                      label: 'Foto Motor (Tampak Belakang)',
                      imagePath: _belakangImagePath,
                      errorText: _fotoError(_belakangImagePath),
                      onTap: () => _pickImage('Belakang'),
                    ),
                    const SizedBox(height: 15),
                    FotoUploadField(
                      label: 'Foto STNK',
                      imagePath: _stnkImagePath,
                      errorText: _fotoError(_stnkImagePath),
                      onTap: () => _pickImage('STNK'),
                    ),
                    const SizedBox(height: 40),

                    // --- Tombol Ajukan ---
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Ajukan Ulang',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
    );
  }
}
