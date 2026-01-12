import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/utils/error_helper.dart';

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
        _error = ErrorHelper.parseError(e);
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
    final formKey = GlobalKey<FormState>();
    final namaController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'MAHASISWA';
    bool isSubmitting = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Daftar Akun Baru', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: namaController,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorMaxLines: 2,
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama lengkap tidak boleh kosong';
                      }
                      if (value.trim().length < 3) {
                        return 'Nama lengkap minimal 3 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username *',
                      hintText: 'Contoh: john.doe',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorMaxLines: 2,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username tidak boleh kosong';
                      }
                      if (value.trim().length < 3) {
                        return 'Username minimal 3 karakter';
                      }
                      if (value.contains(' ')) {
                        return 'Username tidak boleh mengandung spasi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      hintText: 'Minimal 6 karakter',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorMaxLines: 2,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setDialogState(() => obscurePassword = !obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password tidak boleh kosong';
                      }
                      if (value.length < 6) {
                        return 'Password minimal 6 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Role *',
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
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: Text(
                'BATAL',
                style: TextStyle(color: isSubmitting ? Colors.grey.shade300 : Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSubmitting = true);
                        final success = await _registerUser(
                          nama: namaController.text.trim(),
                          username: usernameController.text.trim(),
                          password: passwordController.text,
                          role: selectedRole,
                        );
                        if (success && context.mounted) {
                          Navigator.pop(context);
                        } else {
                          setDialogState(() => isSubmitting = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('DAFTAR', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _registerUser({
    required String nama,
    required String username,
    required String password,
    required String role,
  }) async {
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

      if (response.data['status'] == 'success') {
        ErrorHelper.showSuccess('Akun $nama berhasil dibuat');
        _loadUsers();
        return true;
      } else {
        throw Exception(response.data['message']);
      }
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Membuat Akun');
      return false;
    }
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final idUser = user['id_user'] as int;
    final nama = user['nama'] as String? ?? 'User';
    bool isSubmitting = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                nama,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password Baru *',
                hintText: 'Minimal 6 karakter',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                errorMaxLines: 2,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setDialogState(() => obscurePassword = !obscurePassword);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password tidak boleh kosong';
                }
                if (value.length < 6) {
                  return 'Password minimal 6 karakter';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: Text(
                'BATAL',
                style: TextStyle(color: isSubmitting ? Colors.grey.shade300 : Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSubmitting = true);
                        final success = await _resetPassword(idUser, passwordController.text, nama);
                        if (success && context.mounted) {
                          Navigator.pop(context);
                        } else {
                          setDialogState(() => isSubmitting = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('RESET', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _resetPassword(int idUser, String newPassword, String nama) async {
    try {
      final response = await _dio.put<dynamic>(
        '/api/auth/admin/reset-password',
        data: {
          'id_user': idUser,
          'new_password': newPassword,
        },
      );

      if (response.data['status'] == 'success') {
        ErrorHelper.showSuccess('Password $nama berhasil direset');
        return true;
      } else {
        throw Exception(response.data['message']);
      }
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Reset Password');
      return false;
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
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.error_outline,
                                            size: 48,
                                            color: Colors.red.shade400,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Gagal Memuat Data',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _error!,
                                          style: TextStyle(color: Colors.grey.shade600),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          onPressed: _loadUsers,
                                          icon: const Icon(Icons.refresh, color: Colors.white),
                                          label: const Text(
                                            'Coba Lagi',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFE63946),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : _filteredUsers.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.person_search,
                                            size: 64,
                                            color: Colors.grey.shade300,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? 'User tidak ditemukan'
                                                : 'Belum ada user',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 16,
                                            ),
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
