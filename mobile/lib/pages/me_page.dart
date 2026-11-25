import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/app_theme.dart';
import '../utils/error_helper.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  late final Future<Map<String, String?>> _userData = _loadUserData();

  Future<Map<String, String?>> _loadUserData() async {
    const FlutterSecureStorage storage = FlutterSecureStorage();
    final String? username = await storage.read(key: 'username');
    final String? nama = await storage.read(key: 'nama');
    final String? role = await storage.read(key: 'role');

    return {'username': username, 'nama': nama, 'role': role};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(appBackIcon),
          tooltip: 'Kembali ke Beranda',
        ),
      ),
      body: FutureBuilder<Map<String, String?>>(
        future: _userData,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Map<String, String?>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Terjadi kesalahan: ${ErrorHelper.parseError(snapshot.error)}'),
                );
              }

              final Map<String, String?> data = snapshot.data ?? {};
              final String username = data['username'] ?? '-';
              final String nama = data['nama'] ?? '-';
              final String role = data['role'] ?? '-';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 20),
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          nama.isNotEmpty ? nama[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 40,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Informasi Pengguna',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 10),
                            _buildInfoRow('Username', username),
                            const SizedBox(height: 10),
                            _buildInfoRow('Nama Lengkap', nama),
                            const SizedBox(height: 10),
                            _buildInfoRow('Role', role),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
