import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
// import 'package:mobile/pages/PUNYA%20DANI/PAKETTT/Registrasi/berhasil.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  // --- Variabel State ---
  bool _isPasswordObscured = true;
  String? _selectedRole;
  final List<String> _roles = ['Dosen', 'Mahasiswa'];
  String _fotoWajahText = 'Upload foto wajah...';
  bool _isChecked = false;

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
                    ("Register"),
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
                          "Welcome to us,",
                          style: TextStyle(
                            color: Color(0xFFFC5F57),
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        Text(
                          "Hello there, create New account",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 20),
                        Center(
                          child: Image.asset('assets/images/Illustration.png'),
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
                              labelText: 'Nama',
                              labelStyle: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        // Field "Email"
                        SizedBox(
                          width: double.infinity,
                          child: TextField(
                            controller: _emailController, // <-- TAMBAHAN
                            onChanged: (text) {
                              // <-- TAMBAHAN
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              labelText: 'Email',
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
                        SizedBox(height: 20),

                        InkWell(
                          onTap: () {
                            setState(() {
                              // Simulasi file ter-upload
                              _fotoWajahText = 'wajah_saya.jpg';
                            });
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Foto Wajah',
                              labelStyle: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _fotoWajahText,
                                  style: TextStyle(
                                    color:
                                        _fotoWajahText == 'Upload foto wajah...'
                                        ? Colors.grey[600]
                                        : Colors.black,
                                  ),
                                ),
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),

                        // Field Role/Peran
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            labelText: 'Role/Peran',
                            labelStyle: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          initialValue: _selectedRole,
                          hint: Text('Pilih role Anda...'),
                          isExpanded: true,
                          items: _roles.map((String role) {
                            return DropdownMenuItem<String>(
                              value: role,
                              child: Text(role),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedRole = newValue;
                            });
                          },
                        ),
                        SizedBox(height: 20),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _isChecked,
                              onChanged: (bool? newValue) {
                                setState(() {
                                  _isChecked = newValue!;
                                });
                              },
                            ),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  children: <TextSpan>[
                                    TextSpan(
                                      text:
                                          'By creating an account you agree to our ',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                    TextSpan(
                                      text: 'Term and Conditions',
                                      style: TextStyle(
                                        color: Color(0xFFFC5F57),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      recognizer: TapGestureRecognizer(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        // SizedBox(height: 10),
                        // SizedBox(
                        //   width: double.infinity,
                        //   height: 44,
                        //   child: ElevatedButton(
                        //     onPressed: _isFormValid
                        //         ? () {
                        //             Navigator.push(
                        //               context,
                        //               MaterialPageRoute(
                        //                 builder: (context) =>
                        //                     RegisterBerhasil(),
                        //               ),
                        //             );
                        //           }
                        //         : null,
                        //     style: ElevatedButton.styleFrom(
                        //       backgroundColor: Color(0xFFFC5F57),

                        //       disabledBackgroundColor: Color(0xFFFAA0A0),
                        //     ),
                        //     child: const Text(
                        //       'Sign Up',
                        //       style: TextStyle(
                        //         color: Colors.white,
                        //         fontWeight: FontWeight.bold,
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        SizedBox(height: 30),

                        Center(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                              children: <TextSpan>[
                                TextSpan(text: 'Have an account? '),
                                TextSpan(
                                  text: 'Sign In',
                                  style: TextStyle(
                                    color: Color(0xFFFC5F57),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  recognizer: TapGestureRecognizer(),
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
