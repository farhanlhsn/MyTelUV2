import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'biometrik_status_widget.dart';

/// What the student's "Biometrik" menu item opens: the biometric status. Face attendance itself
/// starts from a class with an open session (home card or absensi list), so there is nothing to
/// verify from here.
class BiometrikStatusPage extends StatelessWidget {
  const BiometrikStatusPage({super.key});

  static const Color _primaryRed = Color(0xFFE63946);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryRed,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
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
                  const Text(
                    'Biometrik',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
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
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const BiometrikStatusWidget(showAction: false),
                    const SizedBox(height: 16),
                    Text(
                      'Data wajah didaftarkan oleh admin kampus. Absensi wajah dimulai '
                      'dari kartu kelas di beranda atau dari daftar absensi saat sesi '
                      'absensi dibuka. Jika absen ditolak karena data wajah belum '
                      'terdaftar, hubungi admin.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
