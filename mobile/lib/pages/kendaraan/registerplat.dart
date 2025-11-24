import 'package:flutter/material.dart';
import 'package:mobile/services/kendaraan_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:mobile/app/routes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RegisterPlatPage(),
    );
  }
}

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
  final TextEditingController depanController = TextEditingController();
  final TextEditingController sampingController = TextEditingController();
  final TextEditingController belakangController = TextEditingController();
  final TextEditingController stnkController = TextEditingController();

  // Image paths
  String? _depanImagePath;
  String? _sampingImagePath;
  String? _belakangImagePath;
  String? _stnkImagePath;

  // Loading state
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  // Pick image from gallery or camera
  Future<void> _pickImage(TextEditingController controller, String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          controller.text = image.name;
          // Store the actual path
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
      print('Error picking image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error memilih gambar: $e')));
    }
  }

  // ... (Fungsi _showErrorSnackBar Anda tetap sama)
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
      // id_user akan diambil dari token di backend
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
    depanController.dispose();
    sampingController.dispose();
    belakangController.dispose();
    stnkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFC5F57);
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
                // --- PERUBAHAN 2: Icon 'kembali' dibuat bisa diklik ---
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20.0,
                  ),
                  onPressed: () {
                    // Cek apakah bisa kembali, jika bisa, 'pop' (kembali)
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
                      'Hello there, create New account',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                    const SizedBox(height: 20),

                    // Pastikan path aset ini benar di pubspec.yaml Anda
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
                    _buildUploadField(
                      'Foto Motor (Tampak Depan)',
                      focusedBorderColor,
                      depanController,
                    ),
                    const SizedBox(height: 15),
                    _buildUploadField(
                      'Foto Motor (Tampak Samping)',
                      focusedBorderColor,
                      sampingController,
                    ),
                    const SizedBox(height: 15),
                    _buildUploadField(
                      'Foto Motor (Tampak Belakang)',
                      focusedBorderColor,
                      belakangController,
                    ),
                    const SizedBox(height: 15),
                    _buildUploadField(
                      'Foto STNK',
                      focusedBorderColor,
                      stnkController,
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

  // ... (Fungsi _buildTextField Anda tetap sama)
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

  // Build upload field with actual image picker
  Widget _buildUploadField(
    String hintText,
    Color focusedColor,
    TextEditingController controller,
  ) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () {
        _pickImage(controller, hintText);
      },
      decoration: InputDecoration(
        hintText: controller.text.isEmpty ? hintText : controller.text,
        hintStyle: controller.text.isEmpty
            ? const TextStyle(color: Colors.grey)
            : const TextStyle(color: Colors.black),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 15,
        ),
        suffixIcon: const Padding(
          padding: EdgeInsets.only(right: 15.0),
          child: Icon(Icons.folder_open, color: Colors.grey),
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
}

// --- PERUBAHAN 3: KELAS BARU UNTUK HALAMAN SUKSES (di file yang sama) ---

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
    // Update countdown setiap detik
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _countdown > 1) {
        setState(() {
          _countdown--;
        });
        _startCountdown();
      } else if (mounted && _countdown == 1) {
        // Redirect ke history pengajuan
        Get.offAllNamed(AppRoutes.home);
        Future.delayed(const Duration(milliseconds: 500), () {
          Get.toNamed(AppRoutes.userHistoriPengajuan);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Warna dasar yang kita gunakan (Coral Cerah)
    const Color primaryColor = Color(0xFFFC5F57);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // --- Bagian Atas Merah (AppBar/Header) ---
          Container(
            height: 150, // Tinggi header
            decoration: const BoxDecoration(color: primaryColor),
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(top: 40, left: 10),
            child: Row(
              children: const [
                Icon(Icons.arrow_back, color: Colors.white),
                SizedBox(width: 10),
                Text(
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
            padding: const EdgeInsets.only(
              top: 100,
            ), // Mulai konten putih dari bawah header
            child: Container(
              height: double.infinity, // Memenuhi sisa layar
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

                    // --- Tombol Manual ke History (opsional) ---
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
