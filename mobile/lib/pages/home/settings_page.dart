import 'package:flutter/material.dart'; // <-- PENTING
import 'package:get/get.dart';
import '../../app/routes.dart';
import '../../controllers/auth_controller.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});
  final AuthController _authController = Get.find<AuthController>();

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[700], size: 28),
              const SizedBox(width: 12),
              const Text(
                'Konfirmasi Logout',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari aplikasi?',
            style: TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
              child: const Text(
                'Batal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Ya, Keluar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _handleLogout();
    }
  }

  Future<void> _handleLogout() async {
    final bool success = await _authController.logout();
    if (!success) {
      Get.snackbar(
        'Logout Gagal',
        'Terjadi kesalahan saat logout',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        icon: const Icon(Icons.error_outline, color: Colors.red),
      );
      return;
    }

    Get.snackbar(
      'Logout Berhasil',
      'Anda telah keluar dari aplikasi',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green.shade100,
      colorText: Colors.green.shade900,
      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
      duration: const Duration(seconds: 2),
    );

    Get.offAllNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.white,
        // Gunakan ListView untuk halaman pengaturan
        child: ListView(
          // Padding bawah 100 tidak perlu lagi, ganti jadi 16
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0, top: 8.0),
              child: Text(
                "Pengaturan",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text("Akun"),
              subtitle: const Text("Edit profil, ganti password"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text("Notifikasi"),
              subtitle: const Text("Atur preferensi notifikasi"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text("Tampilan"),
              subtitle: const Text("Mode gelap, ukuran font"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.security_outlined),
              title: const Text("Privasi & Keamanan"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            const Divider(height: 32),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red[700]),
              title: Text("Keluar", style: TextStyle(color: Colors.red[700])),
              onTap: () => _showLogoutConfirmation(context),
            ),
          ],
        ),
      ),
    );
  }
}
