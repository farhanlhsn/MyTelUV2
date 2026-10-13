import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/services/kendaraan_service.dart';
import 'package:mobile/utils/input_formatters.dart';
import 'package:mobile/utils/kendaraan_helper.dart';
import 'package:mobile/utils/validators.dart';

import 'widgets/foto_upload_field.dart';
import 'package:mobile/utils/app_theme.dart';

// Mengubah StatelessWidget menjadi StatefulWidget
class RegisterPlatPage extends StatefulWidget {
  const RegisterPlatPage({super.key});

  @override
  State<RegisterPlatPage> createState() => _RegisterPlatPageState();
}

class _RegisterPlatPageState extends State<RegisterPlatPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController platController = TextEditingController();
  final TextEditingController namaKendaraanController = TextEditingController();

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
          backgroundColor: isError ? Colors.red : null,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  String? _fotoError(String? path) {
    return _submitted && path == null ? 'Foto wajib dipilih' : null;
  }

  // Submit form ke backend
  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();

    final bool formValid = _formKey.currentState?.validate() ?? false;
    final bool photosValid =
        _depanImagePath != null &&
        _sampingImagePath != null &&
        _belakangImagePath != null &&
        _stnkImagePath != null;
    setState(() => _submitted = true);

    if (!formValid || !photosValid) {
      _showSnackBar('Lengkapi data yang ditandai terlebih dahulu.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call API untuk register kendaraan
      await KendaraanService.registerKendaraan(
        platNomor: Validators.normalizePlat(platController.text),
        namaKendaraan: namaKendaraanController.text.trim(),
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

      // Navigate to success page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const RegisterPlatBerhasilPage(),
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
  void dispose() {
    platController.dispose();
    namaKendaraanController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required Color focusedColor,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorMaxLines: 2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: focusedColor, width: 2.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = AppColors.primary;
    const Color focusedBorderColor = Color(0xFFFF6B6B);

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
                    Icons.arrow_back_ios_new,
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
                  'Daftarkan Plat',
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
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Daftarkan Plat Anda',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Lengkapi data kendaraan Anda',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 20),

                      // Illustration
                      Center(
                        child: Image.asset('assets/images/Illustration.png'),
                      ),
                      const SizedBox(height: 15),

                      // Form Fields
                      TextFormField(
                        controller: namaKendaraanController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration(
                          label: 'Nama Kendaraan',
                          hint: 'Contoh: Honda Vario',
                          focusedColor: focusedBorderColor,
                        ),
                        validator: Validators.namaKendaraan,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: platController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9 ]'),
                          ),
                          const UpperCaseTextFormatter(),
                          LengthLimitingTextInputFormatter(12),
                        ],
                        decoration: _fieldDecoration(
                          label: 'Nomor Plat',
                          hint: 'Contoh: D 1234 ABC',
                          focusedColor: focusedBorderColor,
                        ),
                        validator: Validators.platNomor,
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

                      // --- Tombol Daftar ---
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
                                  'Daftarkan',
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
          ),
        ],
      ),
    );
  }
}

// --- SUCCESS PAGE ---
// Shared by registering a plate and by resubmitting a rejected one (the copy is configurable).
class RegisterPlatBerhasilPage extends StatefulWidget {
  final String appBarTitle;
  final String title;
  final String message;

  const RegisterPlatBerhasilPage({
    super.key,
    this.appBarTitle = 'Daftarkan Plat',
    this.title = 'Pendaftaran Plat Berhasil!',
    this.message = 'Pengajuan Anda sedang diproses',
  });

  @override
  State<RegisterPlatBerhasilPage> createState() =>
      _RegisterPlatBerhasilPageState();
}

class _RegisterPlatBerhasilPageState extends State<RegisterPlatBerhasilPage> {
  int _countdown = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        _goToHistory(delay: const Duration(milliseconds: 500));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goToHistory({required Duration delay}) {
    _timer?.cancel();
    Get.offAllNamed(AppRoutes.home);
    Future.delayed(delay, () {
      Get.toNamed(AppRoutes.userHistoriPengajuan);
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFC5F57);

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
                  tooltip: 'Kembali ke beranda',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    _timer?.cancel();
                    Get.offAllNamed(AppRoutes.home);
                  },
                ),
                Text(
                  widget.appBarTitle,
                  style: const TextStyle(
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
              height: double.infinity,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 40.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: 40),

                    // --- Icon Success ---
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 80,
                        color: Colors.green.shade400,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Teks Berhasil ---
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 40),

                    // --- Countdown Indicator ---
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history,
                            color: primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Menuju histori pengajuan dalam $_countdown detik...',
                              style: const TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Tombol Manual ke History ---
                    TextButton(
                      onPressed: () =>
                          _goToHistory(delay: const Duration(milliseconds: 300)),
                      child: const Text(
                        'Lihat Sekarang →',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
