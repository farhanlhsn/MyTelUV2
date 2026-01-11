import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/services/akademik_service.dart';
import 'package:mobile/services/biometrik_service.dart';
import 'package:mobile/utils/error_helper.dart';

class AdminBiometrikPage extends StatefulWidget {
  const AdminBiometrikPage({super.key});

  @override
  State<AdminBiometrikPage> createState() => _AdminBiometrikPageState();
}

class _AdminBiometrikPageState extends State<AdminBiometrikPage> {
  final AkademikService _akademikService = AkademikService();
  final BiometrikService _biometrikService = BiometrikService();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _userList = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get all users (MAHASISWA + DOSEN)
      final mahasiswa = await _akademikService.getAllMahasiswa();
      final dosen = await _akademikService.getAllDosen();
      
      setState(() {
        _userList = [...mahasiswa, ...dosen];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _userList;
    return _userList.where((user) {
      final nama = (user['nama'] as String? ?? '').toLowerCase();
      final username = (user['username'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return nama.contains(query) || username.contains(query);
    }).toList();
  }

  Future<void> _addBiometrik(Map<String, dynamic> user) async {
    final idUser = user['id_user'] as int;
    final nama = user['nama'] as String? ?? 'Unknown';
    final hasBiometric = user['has_biometric'] as bool? ?? false;

    // Pick image
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );

    if (image == null) return;

    // Show loading
    Get.dialog(
      const Center(child: CircularProgressIndicator(color: Colors.white)),
      barrierDismissible: false,
    );

    try {
      Map<String, dynamic> result;
      
      // Use edit endpoint if biometric already exists, otherwise add
      if (hasBiometric) {
        result = await _biometrikService.editBiometrik(
          idUser: idUser,
          imageFile: File(image.path),
        );
      } else {
        result = await _biometrikService.addBiometrik(
          idUser: idUser,
          imageFile: File(image.path),
        );
      }

      Get.back(); // Close loading

      if (result['status'] == 'success') {
        ErrorHelper.showSuccess(
          hasBiometric ? 'Biometrik $nama berhasil diupdate' : 'Biometrik $nama berhasil ditambahkan',
        );
        _loadUsers();
      } else {
        throw Exception(result['message'] ?? 'Unknown error');
      }
    } catch (e) {
      Get.back(); // Close loading
      ErrorHelper.showError(e, title: 'Gagal Menyimpan Biometrik');
    }
  }

  Future<void> _deleteBiometrik(Map<String, dynamic> user) async {
    final idUser = user['id_user'] as int;
    final nama = user['nama'] as String? ?? 'Unknown';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Biometrik'),
        content: Text('Hapus data biometrik $nama?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('HAPUS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _biometrikService.deleteBiometrik(idUser);
      ErrorHelper.showSuccess('Biometrik $nama berhasil dihapus');
      _loadUsers();
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Menghapus Biometrik');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE63946),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      "Manajemen Biometrik",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari user...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE63946)),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),

                    // User list
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: Color(0xFFE63946)),
                            )
                          : _error != null
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(_error!, style: const TextStyle(color: Colors.red)),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: _loadUsers,
                                        child: const Text('Coba Lagi'),
                                      ),
                                    ],
                                  ),
                                )
                              : _filteredUsers.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Tidak ada user ditemukan',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  : RefreshIndicator(
                                      onRefresh: _loadUsers,
                                      child: ListView.separated(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        itemCount: _filteredUsers.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          return _buildUserCard(_filteredUsers[index]);
                                        },
                                      ),
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

  Widget _buildUserCard(Map<String, dynamic> user) {
    final nama = user['nama'] as String? ?? 'Unknown';
    final username = user['username'] as String? ?? '-';
    final role = user['role'] as String? ?? 'MAHASISWA';
    final hasBiometric = user['has_biometric'] as bool? ?? false;
    final biometricPhoto = user['biometric_photo'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasBiometric ? Colors.green.shade200 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with biometric photo or icon
          GestureDetector(
            onTap: biometricPhoto != null ? () => _showPhotoDialog(biometricPhoto, nama) : null,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: hasBiometric
                    ? Colors.green.withOpacity(0.1)
                    : role == 'DOSEN'
                        ? Colors.blue.withOpacity(0.1)
                        : const Color(0xFFE63946).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: hasBiometric ? Border.all(color: Colors.green, width: 2) : null,
              ),
              child: biometricPhoto != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        biometricPhoto,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.face,
                          color: Colors.green,
                        ),
                      ),
                    )
                  : Icon(
                      role == 'DOSEN' ? Icons.school : Icons.person,
                      color: role == 'DOSEN' ? Colors.blue : const Color(0xFFE63946),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nama,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasBiometric)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '✓ Bio',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$username • $role',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          IconButton(
            icon: Icon(
              hasBiometric ? Icons.refresh : Icons.face_retouching_natural,
              color: const Color(0xFFE63946),
            ),
            tooltip: hasBiometric ? 'Update Biometrik' : 'Tambah Biometrik',
            onPressed: () => _addBiometrik(user),
          ),
          if (hasBiometric)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Hapus Biometrik',
              onPressed: () => _deleteBiometrik(user),
            ),
        ],
      ),
    );
  }

  void _showPhotoDialog(String photoUrl, String nama) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                photoUrl,
                width: 300,
                height: 300,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 300,
                  height: 300,
                  child: Center(child: Icon(Icons.error, size: 64)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                nama,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
