import 'package:flutter/material.dart'; // <-- PENTING

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}