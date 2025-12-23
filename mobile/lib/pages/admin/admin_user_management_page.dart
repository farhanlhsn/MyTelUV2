import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:mobile/services/api_client.dart';

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  State<AdminUserManagementPage> createState() => _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  final Dio _dio = ApiClient.dio;

  List<Map<String, dynamic>> _userList = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _filterRole = 'ALL';

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
      final Map<String, dynamic> queryParams = {'limit': 100};
      if (_filterRole != 'ALL') {
        queryParams['role'] = _filterRole;
      }

      final response = await _dio.get<dynamic>(
        '/api/auth/users',
        queryParameters: queryParams,
      );

      if (response.data is Map<String, dynamic>) {
        final dataMap = response.data['data'] as Map<String, dynamic>?;
        if (dataMap != null && dataMap['users'] is List) {
          setState(() {
            _userList = (dataMap['users'] as List).cast<Map<String, dynamic>>();
            _isLoading = false;
          });
          return;
        }
      }
      setState(() {
        _userList = [];
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

  void _showRegisterDialog() {
    final namaController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'MAHASISWA';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Daftar Akun Baru', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'MAHASISWA', child: Text('Mahasiswa')),
                    DropdownMenuItem(value: 'DOSEN', child: Text('Dosen')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                  ],
                  onChanged: (value) => setDialogState(() => selectedRole = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (namaController.text.isEmpty ||
                    usernameController.text.isEmpty ||
                    passwordController.text.isEmpty) {
                  Get.snackbar('Error', 'Semua field harus diisi',
                      backgroundColor: Colors.red, colorText: Colors.white);
                  return;
                }
                Navigator.pop(context);
                await _registerUser(
                  nama: namaController.text,
                  username: usernameController.text,
                  password: passwordController.text,
                  role: selectedRole,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('DAFTAR', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerUser({
    required String nama,
    required String username,
    required String password,
    required String role,
  }) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator(color: Colors.white)),
      barrierDismissible: false,
    );

    try {
      final response = await _dio.post<dynamic>(
        '/api/auth/register',
        data: {
          'nama': nama,
          'username': username,
          'password': password,
          'role': role,
        },
      );

      Get.back();

      if (response.data['status'] == 'success') {
        Get.snackbar('Berhasil', 'Akun $nama berhasil dibuat',
            backgroundColor: Colors.green, colorText: Colors.white);
        _loadUsers();
      } else {
        throw Exception(response.data['message']);
      }
    } on DioException catch (e) {
      Get.back();
      Get.snackbar('Error', e.response?.data['message'] ?? e.message,
          backgroundColor: Colors.red, colorText: Colors.white);
    } catch (e) {
      Get.back();
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final passwordController = TextEditingController();
    final idUser = user['id_user'] as int;
    final nama = user['nama'] as String? ?? 'User';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Password\n$nama', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password Baru',
            hintText: 'Min. 6 karakter',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.length < 6) {
                Get.snackbar('Error', 'Password minimal 6 karakter',
                    backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }
              Navigator.pop(context);
              await _resetPassword(idUser, passwordController.text, nama);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('RESET', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(int idUser, String newPassword, String nama) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator(color: Colors.white)),
      barrierDismissible: false,
    );

    try {
      final response = await _dio.put<dynamic>(
        '/api/auth/admin/reset-password',
        data: {
          'id_user': idUser,
          'new_password': newPassword,
        },
      );

      Get.back();

      if (response.data['status'] == 'success') {
        Get.snackbar('Berhasil', 'Password $nama berhasil direset',
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        throw Exception(response.data['message']);
      }
    } catch (e) {
      Get.back();
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
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
                      "Manajemen User",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    onPressed: _showRegisterDialog,
                    tooltip: 'Daftar Akun Baru',
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
                    // Search and Filter
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Cari user...',
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              onChanged: (value) => setState(() => _searchQuery = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade50,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _filterRole,
                                items: const [
                                  DropdownMenuItem(value: 'ALL', child: Text('All')),
                                  DropdownMenuItem(value: 'MAHASISWA', child: Text('MHS')),
                                  DropdownMenuItem(value: 'DOSEN', child: Text('DSN')),
                                  DropdownMenuItem(value: 'ADMIN', child: Text('ADM')),
                                ],
                                onChanged: (value) {
                                  setState(() => _filterRole = value!);
                                  _loadUsers();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // User count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE63946).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people, color: Color(0xFFE63946)),
                            const SizedBox(width: 12),
                            Text(
                              'Total User: ${_filteredUsers.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE63946),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

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

    Color roleColor;
    switch (role) {
      case 'ADMIN':
        roleColor = Colors.purple;
        break;
      case 'DOSEN':
        roleColor = Colors.blue;
        break;
      default:
        roleColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
          // Avatar
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              role == 'ADMIN' ? Icons.admin_panel_settings 
                  : role == 'DOSEN' ? Icons.school 
                  : Icons.person,
              color: roleColor,
            ),
          ),
          const SizedBox(width: 12),

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
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (hasBiometric) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.face, size: 16, color: Colors.green),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  username,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),

          // Reset password button
          IconButton(
            icon: const Icon(Icons.lock_reset, color: Color(0xFFE63946)),
            tooltip: 'Reset Password',
            onPressed: () => _showResetPasswordDialog(user),
          ),
        ],
      ),
    );
  }
}
