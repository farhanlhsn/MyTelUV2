import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mobile/pages/PUNYA%20DANI/PAKETTT/Registrasi/RegisterPage.dart';
import 'package:mobile/pages/PUNYA%20DANI/PAKETTT/Registrasi/berhasil.dart';


class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  // --- Variabel State ---
  bool _isPasswordObscured = true;
  String? _selectedRole;
  final String _fotoWajahText = 'Upload foto wajah...';
  final bool _isChecked = false;

  // --- TAMBAHAN: Controller untuk memantau TextField ---
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // --- TAMBAHAN: Membersihkan controller saat widget dibuang ---
  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- TAMBAHAN: Getter untuk mengecek validitas form ---
  bool get _isFormValid {
    // Cek apakah semua kondisi terpenuhi
    return _namaController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _fotoWajahText != 'Upload foto wajah...' &&
        _selectedRole != null &&
        _isChecked;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFC5F57),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Anda
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  Text(
                    ("Sign in"),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Container yang di-expand
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome Back",
                          style: TextStyle(
                            color: Color(0xFFFC5F57),
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        Text(
                          "Hello there, sign in to continue",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 20),
                        Center(
                          child: Image.asset('assets/images/Illustration 3.png'),
                        ),
                        // Field "Nama"
                        SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: TextField(
                            controller: _namaController, // <-- TAMBAHAN
                            onChanged: (text) {
                              // <-- TAMBAHAN: Panggil setState agar UI update
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              labelText: 'Username',
                              labelStyle: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        
                        // Field Password
                        SizedBox(
                          width: double.infinity,
                          child: TextField(
                            controller: _passwordController, // <-- TAMBAHAN
                            onChanged: (text) {
                              // <-- TAMBAHAN
                              setState(() {});
                            },
                            obscureText: _isPasswordObscured,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              labelText: 'Password',
                              labelStyle: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordObscured
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordObscured = !_isPasswordObscured;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 50),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _isFormValid
                                ? () {
                                    // Semua field valid, jalankan logika sign up
                                    // print('Tombol Sign Up Ditekan!');
                                    // print('Nama: ${_namaController.text}');
                                    // print('Email: ${_emailController.text}');
                                    // print('Password: [HIDDEN]');
                                    // print('Foto: $_fotoWajahText');
                                    // print('Role: $_selectedRole');

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            RegisterBerhasil(),
                                      ),
                                    );
                                  }
                                : null, // <-- Set ke null untuk disable
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFFC5F57),

                              disabledBackgroundColor: Color(0xFFFAA0A0),
                            ),
                            child: const Text(
                              'Sign in',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 30),

                        Center(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                              children: <TextSpan>[
                                TextSpan(text: 'Dont have an account? '),
                                TextSpan(
                                  text: 'Sign Up',
                                  style: TextStyle(
                                    color: Color(0xFFFC5F57),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      print('Sign Up di-tap!');
                                       Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TestPage(),
                                      ),
                                    );
                                    },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
