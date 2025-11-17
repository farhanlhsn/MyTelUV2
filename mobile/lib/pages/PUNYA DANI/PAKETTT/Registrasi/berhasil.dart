

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:mobile/pages/PUNYA%20DANI/PAKETTT/Signin/signinpage.dart'; // <-- Import untuk timer

// Sesuaikan path import ini dengan lokasi file SignInPage Anda


class RegisterBerhasil extends StatefulWidget {
  const RegisterBerhasil({super.key});

  @override
  State<RegisterBerhasil> createState() => _RegisterBerhasilState();
}

class _RegisterBerhasilState extends State<RegisterBerhasil> {
  @override
  void initState() {
    super.initState();
    // Panggil fungsi navigasi saat halaman ini pertama kali dibuka
    _navigateToSignIn();
  }

  void _navigateToSignIn() {
    // Tunggu selama 3 detik
    Future.delayed(const Duration(seconds: 3), () {
      // Pastikan widget masih ada di tree sebelum navigasi
      if (mounted) {
        // Gunakan pushAndRemoveUntil untuk:
        // 1. Mendorong (push) halaman SignInPage
        // 2. Menghapus (remove) semua halaman sebelumnya (TestPage & RegisterBerhasil)
        //    dari tumpukan (stack) navigasi.
        // Ini mencegah pengguna menekan "kembali" ke halaman registrasi
        // setelah berhasil.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const SignInPage(),
          ),
          (Route<dynamic> route) => false, // Hapus semua rute sebelumnya
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ini adalah UI yang akan dilihat pengguna selama 3 detik
    return Scaffold(
      backgroundColor: Color(0xFFFC5F57),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/illustration 2.png'),
            SizedBox(height: 20),
            Text(
              'Registrasi Berhasil!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Anda akan diarahkan ke halaman Sign In...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}