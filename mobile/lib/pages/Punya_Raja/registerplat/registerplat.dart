import 'package:flutter/material.dart';

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
  // ... (Semua controller Anda tetap sama)
  final TextEditingController platController = TextEditingController();
  final TextEditingController depanController = TextEditingController();
  final TextEditingController sampingController = TextEditingController();
  final TextEditingController belakangController = TextEditingController();
  final TextEditingController stnkController = TextEditingController();

  // ... (Fungsi _pickFile Anda tetap sama)
  void _pickFile(TextEditingController controller, String type) {
    Future.delayed(const Duration(milliseconds: 300), () {
      controller.text = 'Foto_${type.replaceAll(' ', '_')}_${DateTime.now().millisecond}.jpg';
      setState(() {
        // Memaksa rebuild untuk memastikan UI diperbarui jika diperlukan
      });
    });
  }

  // ... (Fungsi _showErrorSnackBar Anda tetap sama)
  void _showErrorSnackBar(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Center(
          child: Text(
            'Data Tidak Lengkap, Silahkan Melakukan Pengisian Ulang',
            style: TextStyle(backgroundColor: Color.fromARGB(255, 255, 17, 0), color: Colors.white, fontWeight: FontWeight.bold),
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

  // --- PERUBAHAN 1: FUNGSI _onSubmit diubah untuk NAVIGASI ---
  void _onSubmit(BuildContext context) {
    final fields = [
      platController.text,
      depanController.text,
      sampingController.text,
      belakangController.text,
      stnkController.text,
    ];

    final isDataIncomplete = fields.any((text) => text.trim().isEmpty);

    if (isDataIncomplete) {
      _showErrorSnackBar(context);
    } else {
      // JIKA SUKSES: Pindah ke halaman baru (RegisterPlatBerhasilPage)
      // Kita gunakan 'pushReplacement' agar pengguna tidak bisa "kembali"
      // ke halaman form ini setelah berhasil mendaftar.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RegisterPlatBerhasilPage()),
      );
    }
  }

  @override
  void dispose() {
    platController.dispose();
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
            decoration: const BoxDecoration(
              color: primaryColor,
            ),
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
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                  
                  // Pastikan path aset ini benar di pubspec.yaml Anda
                    Center(child: Image.asset('assets/images/Illustration.png')),
                    const SizedBox(height: 15),

                    // ... (Semua Form Fields Anda tetap sama)
                    _buildTextField('Nomor Plat', focusedBorderColor, platController, keyboardType: TextInputType.text),
                    const SizedBox(height: 15),
                    _buildUploadField('Foto Motor (Tampak Depan)', focusedBorderColor, depanController),
                    const SizedBox(height: 15),
                    _buildUploadField('Foto Motor (Tampak Samping)', focusedBorderColor, sampingController),
                    const SizedBox(height: 15),
                    _buildUploadField('Foto Motor (Tampak Belakang)', focusedBorderColor, belakangController),
                    const SizedBox(height: 15),
                    _buildUploadField('Foto STNK', focusedBorderColor, stnkController),
                    const SizedBox(height: 40),

                    // --- Tombol Daftar ---
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                      // onPressed memanggil fungsi _onSubmit yang sudah diubah
                        onPressed: () => _onSubmit(context), 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Daftarkan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white
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
  Widget _buildTextField(String hintText, Color focusedColor, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
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
      ),
    );
  }

  // ... (Fungsi _buildUploadField Anda tetap sama)
  Widget _buildUploadField(String hintText, Color focusedColor, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () {
        _pickFile(controller, hintText);
      },
      decoration: InputDecoration(
        hintText: controller.text.isEmpty ? hintText : controller.text,
        hintStyle: controller.text.isEmpty 
            ? const TextStyle(color: Colors.grey) 
            : const TextStyle(color: Colors.black), 
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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

  // ... (Fungsi _buildDot Anda tetap sama)
  Widget _buildDot(Color color, {double size = 8.0}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}


// --- PERUBAHAN 3: KELAS BARU UNTUK HALAMAN SUKSES (di file yang sama) ---

class RegisterPlatBerhasilPage extends StatelessWidget {
 const RegisterPlatBerhasilPage({super.key});

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
      decoration: const BoxDecoration(
       color: primaryColor,
      ),
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
      padding: const EdgeInsets.only(top: 100), // Mulai konten putih dari bawah header
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
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
        child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         crossAxisAlignment: CrossAxisAlignment.center,
         children: <Widget>[
          const SizedBox(height: 40),

          // --- Placeholder untuk Ilustrasi ---
          // Menggunakan placeholder karena gambar eksternal/aset tidak bisa dimuat
          Center(child: Image.asset('assets/images/Done-rafiki_1.png')),
          SizedBox(height: 15),

          // --- Teks Berhasil ---
          const Text(
           'Register Plat Berhasil!!',
           textAlign: TextAlign.center,
           style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: primaryColor, // Menggunakan warna #FC5F57
           ),
          ),
          const SizedBox(height: 10),

          // --- Teks Subjudul ---
          const Text(
           'Welcome To Our Campus!',
           textAlign: TextAlign.center,
           style: TextStyle(
            fontSize: 16,
            color: Colors.black,
           ),
          ),
          const SizedBox(height: 40),
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

