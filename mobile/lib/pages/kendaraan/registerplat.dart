import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile/services/kendaraan_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:mobile/app/routes.dart';

// Mengubah StatelessWidget menjadi StatefulWidget
class RegisterPlatPage extends StatefulWidget {
  const RegisterPlatPage({super.key});

  @override
  State<RegisterPlatPage> createState() => _RegisterPlatPageState();
}

class _RegisterPlatPageState extends State<RegisterPlatPage> {
  // Controllers
  final TextEditingController platController = TextEditingController();
  final TextEditingController namaKendaraanController = TextEditingController();

  // Image paths - simplified, no longer need separate controllers
  String? _depanImagePath;
  String? _sampingImagePath;
  String? _belakangImagePath;
  String? _stnkImagePath;

  // Loading state
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  // Show image source selection bottom sheet
  Future<void> _showImageSourceSheet(String type) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pilih Sumber Foto',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE63946).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt, color: Color(0xFFE63946)),
                  ),
                  title: const Text('Kamera'),
                  subtitle: const Text('Ambil foto langsung'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(type, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE63946).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library, color: Color(0xFFE63946)),
                  ),
                  title: const Text('Galeri'),
                  subtitle: const Text('Pilih dari galeri'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(type, ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Pick image from gallery or camera
  Future<void> _pickImage(String type, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
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
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error memilih gambar: $e')));
    }
  }

  void _showErrorSnackBar(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Center(
          child: Text(
            'Data Tidak Lengkap, Silahkan Melakukan Pengisian Ulang',
            style: TextStyle(
              backgroundColor: Color.fromARGB(255, 255, 17, 0),
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 0, 0),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: screenHeight * 0.85,
          right: 40,
          left: 40,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Submit form ke backend
  Future<void> _onSubmit(BuildContext context) async {
    // Validasi input
    if (platController.text.trim().isEmpty ||
        namaKendaraanController.text.trim().isEmpty ||
        _depanImagePath == null ||
        _sampingImagePath == null ||
        _belakangImagePath == null ||
        _stnkImagePath == null) {
      _showErrorSnackBar(context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call API untuk register kendaraan
      await KendaraanService.registerKendaraan(
        platNomor: platController.text.trim(),
        namaKendaraan: namaKendaraanController.text.trim(),
        fotoKendaraanPaths: [
          _depanImagePath!,
          _sampingImagePath!,
          _belakangImagePath!,
        ],
        fotoSTNKPath: _stnkImagePath!,
      );

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
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mendaftarkan kendaraan: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    platController.dispose();
    namaKendaraanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFE63946);
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
                  'Register Plat',
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
                      'Register Your Plat',
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
                    _buildTextField(
                      'Nama Kendaraan (e.g., HONDA VARIO)',
                      focusedBorderColor,
                      namaKendaraanController,
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      'Nomor Plat',
                      focusedBorderColor,
                      platController,
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 15),
                    
                    // Image upload fields with preview
                    _buildImageUploadField(
                      'Foto Motor (Tampak Depan)',
                      _depanImagePath,
                      'Depan',
                    ),
                    const SizedBox(height: 15),
                    _buildImageUploadField(
                      'Foto Motor (Tampak Samping)',
                      _sampingImagePath,
                      'Samping',
                    ),
                    const SizedBox(height: 15),
                    _buildImageUploadField(
                      'Foto Motor (Tampak Belakang)',
                      _belakangImagePath,
                      'Belakang',
                    ),
                    const SizedBox(height: 15),
                    _buildImageUploadField(
                      'Foto STNK',
                      _stnkImagePath,
                      'STNK',
                    ),
                    const SizedBox(height: 40),

                    // --- Tombol Daftar ---
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _onSubmit(context),
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
        ],
      ),
    );
  }

  Widget _buildTextField(
    String hintText,
    Color focusedColor,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 15,
        ),
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
      ),
    );
  }

  // Build image upload field with preview thumbnail
  Widget _buildImageUploadField(
    String label,
    String? imagePath,
    String type,
  ) {
    const Color primaryColor = Color(0xFFE63946);
    
    return GestureDetector(
      onTap: () => _showImageSourceSheet(type),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: imagePath != null ? primaryColor : Colors.grey,
            width: imagePath != null ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: imagePath != null ? primaryColor.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            // Thumbnail preview or icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                      ),
                    )
                  : Icon(
                      Icons.add_a_photo,
                      size: 28,
                      color: Colors.grey[500],
                    ),
            ),
            const SizedBox(width: 12),
            // Label and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: imagePath != null ? primaryColor : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    imagePath != null
                        ? '✓ Foto terpilih'
                        : 'Tap untuk memilih foto',
                    style: TextStyle(
                      fontSize: 12,
                      color: imagePath != null ? Colors.green : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            // Action icon
            Icon(
              imagePath != null ? Icons.check_circle : Icons.folder_open,
              color: imagePath != null ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

// --- SUCCESS PAGE ---
class RegisterPlatBerhasilPage extends StatefulWidget {
  const RegisterPlatBerhasilPage({super.key});

  @override
  State<RegisterPlatBerhasilPage> createState() =>
      _RegisterPlatBerhasilPageState();
}

class _RegisterPlatBerhasilPageState extends State<RegisterPlatBerhasilPage> {
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _countdown > 1) {
        setState(() {
          _countdown--;
        });
        _startCountdown();
      } else if (mounted && _countdown == 1) {
        Get.offAllNamed(AppRoutes.home);
        Future.delayed(const Duration(milliseconds: 500), () {
          Get.toNamed(AppRoutes.userHistoriPengajuan);
        });
      }
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
                const Icon(Icons.arrow_back, color: Colors.white),
                const SizedBox(width: 10),
                const Text(
                  'Register Plat',
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
                    const Text(
                      'Register Plat Berhasil!!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Pengajuan Anda sedang diproses',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 40),

                    // --- Countdown Indicator ---
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
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
                          Text(
                            'Menuju histori pengajuan dalam $_countdown detik...',
                            style: const TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Tombol Manual ke History ---
                    TextButton(
                      onPressed: () {
                        Get.offAllNamed(AppRoutes.home);
                        Future.delayed(const Duration(milliseconds: 300), () {
                          Get.toNamed(AppRoutes.userHistoriPengajuan);
                        });
                      },
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
