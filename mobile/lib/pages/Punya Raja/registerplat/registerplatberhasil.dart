import 'package:flutter/material.dart';

// Hapus main() dan MyApp() jika file ini di-import ke file lain.
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RegisterPlatBerhasilPage(),
    );
  }
}

class RegisterPlatBerhasilPage extends StatelessWidget {
  const RegisterPlatBerhasilPage({super.key});

  @override
  Widget build(BuildContext context) {
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
              children: [
                // Tombol kembali yang sudah diperbaiki
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new, // Ikon '<'
                    color: Colors.white,
                    size: 20.0, // Ukuran sama dengan font judul
                  ),
                  onPressed: () {
                    // Fungsi untuk kembali
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
                    horizontal: 20.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: 40),

                    // --- Ilustrasi ---
                    // Menggunakan Ikon sebagai placeholder
                    // agar kode ini langsung bisa dijalankan
                    // tanpa error 'asset not found'.
                    const Center(
                      child: Icon(
                        Icons.check_circle_outline,
                        color: primaryColor,
                        size: 150,
                      ),
                    ),
                    // Jika Anda sudah punya gambarnya, ganti dengan:
                    // Center(child: Image.asset('assets/images/Done-rafiki_1.png')),

                    const SizedBox(height: 15),

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