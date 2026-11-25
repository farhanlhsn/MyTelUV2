import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/app_theme.dart';
import '../../utils/error_helper.dart';
import '../common/confirm_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthController _authController = Get.find<AuthController>();
  bool _isLoggingOut = false;

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      final bool confirmed = await showAppConfirmDialog(
        context,
        title: 'Konfirmasi Keluar',
        message: 'Apakah Anda yakin ingin keluar dari aplikasi?',
        confirmLabel: 'Ya, Keluar',
        icon: Icons.logout,
      );

      if (mounted && confirmed) {
        await _handleLogout();
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _handleLogout() async {
    final bool success = await _authController.logout();
    if (!mounted) return;
    if (!success) {
      ErrorHelper.showError('Terjadi kesalahan saat keluar', title: 'Gagal Keluar');
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0, top: 8.0),
              child: Text(
                "Pengaturan",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text("Akun"),
              subtitle: const Text("Ubah profil dan password"),
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
              enabled: !_isLoggingOut,
              onTap: () => _showLogoutConfirmation(context),
            ),
          ],
        ),
      ),
    );
  }
}
