import 'package:flutter/material.dart'; // <-- PENTING
import 'package:get/get.dart';
import '../../app/routes.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/error_helper.dart';

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
      ErrorHelper.showError('Terjadi kesalahan saat logout', title: 'Logout Gagal');
      return;
    }

    ErrorHelper.showSuccess('Anda telah keluar dari aplikasi');
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
              onTap: () {
                Get.toNamed(AppRoutes.account);
              },
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text("Histori Pengajuan Plat"),
              subtitle: const Text("Lihat status pengajuan kendaraan"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.toNamed(AppRoutes.userHistoriPengajuan);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text("Notifikasi"),
              subtitle: const Text("Atur preferensi notifikasi"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.toNamed(AppRoutes.notification);
              },
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
