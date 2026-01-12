import 'package:flutter/material.dart';
import 'package:mobile/models/matakuliah.dart';
import 'package:mobile/services/akademik_service.dart';
import 'package:mobile/utils/error_helper.dart';

class AdminMatakuliahTab extends StatefulWidget {
  const AdminMatakuliahTab({super.key});

  @override
  State<AdminMatakuliahTab> createState() => _AdminMatakuliahTabState();
}

class _AdminMatakuliahTabState extends State<AdminMatakuliahTab> {
  final AkademikService _akademikService = AkademikService();
  final TextEditingController _searchController = TextEditingController();

  List<MatakuliahModel> _matakuliahList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMatakuliah();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMatakuliah({String? search}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _akademikService.getAllMatakuliah(
        search: search,
        limit: 100,
      );
      final List<dynamic> data = response['data'] ?? [];
      setState(() {
        _matakuliahList = data
            .map((e) => MatakuliahModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorHelper.parseError(e);
        _isLoading = false;
      });
    }
  }

  void _showCreateDialog() {
    final formKey = GlobalKey<FormState>();
    final namaController = TextEditingController();
    final kodeController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Tambah Matakuliah',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: kodeController,
                    decoration: InputDecoration(
                      labelText: 'Kode Matakuliah',
                      hintText: 'Contoh: IF101',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorMaxLines: 2,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Kode matakuliah tidak boleh kosong';
                      }
                      if (value.trim().length < 2) {
                        return 'Kode matakuliah minimal 2 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: namaController,
                    decoration: InputDecoration(
                      labelText: 'Nama Matakuliah',
                      hintText: 'Contoh: Pemrograman Dasar',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorMaxLines: 2,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama matakuliah tidak boleh kosong';
                      }
                      if (value.trim().length < 3) {
                        return 'Nama matakuliah minimal 3 karakter';
                      }
                      return null;
                    },
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
                        final success = await _createMatakuliah(
                          namaController.text.trim(),
                          kodeController.text.trim(),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                  : const Text('SIMPAN', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(MatakuliahModel mk) {
    final formKey = GlobalKey<FormState>();
    final namaController = TextEditingController(text: mk.namaMatakuliah);
    final kodeController = TextEditingController(text: mk.kodeMatakuliah);
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Edit Matakuliah',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: kodeController,
                    decoration: InputDecoration(
                      labelText: 'Kode Matakuliah',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorMaxLines: 2,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Kode matakuliah tidak boleh kosong';
                      }
                      if (value.trim().length < 2) {
                        return 'Kode matakuliah minimal 2 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: namaController,
                    decoration: InputDecoration(
                      labelText: 'Nama Matakuliah',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorMaxLines: 2,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama matakuliah tidak boleh kosong';
                      }
                      if (value.trim().length < 3) {
                        return 'Nama matakuliah minimal 3 karakter';
                      }
                      return null;
                    },
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
                        final success = await _updateMatakuliah(
                          mk.idMatakuliah,
                          namaController.text.trim(),
                          kodeController.text.trim(),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                  : const Text('UPDATE', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _createMatakuliah(String nama, String kode) async {
    try {
      await _akademikService.createMatakuliah(
        namaMatakuliah: nama,
        kodeMatakuliah: kode,
      );
      ErrorHelper.showSuccess('Matakuliah berhasil ditambahkan');
      _loadMatakuliah();
      return true;
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Menambah Matakuliah');
      return false;
    }
  }

  Future<bool> _updateMatakuliah(int id, String nama, String kode) async {
    try {
      await _akademikService.updateMatakuliah(
        idMatakuliah: id,
        namaMatakuliah: nama,
        kodeMatakuliah: kode,
      );
      ErrorHelper.showSuccess('Matakuliah berhasil diupdate');
      _loadMatakuliah();
      return true;
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Mengupdate Matakuliah');
      return false;
    }
  }

  Future<void> _deleteMatakuliah(MatakuliahModel mk) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade400),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Hapus Matakuliah')),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus "${mk.namaMatakuliah}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
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
      await _akademikService.deleteMatakuliah(mk.idMatakuliah);
      ErrorHelper.showSuccess('Matakuliah berhasil dihapus');
      _loadMatakuliah();
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Menghapus Matakuliah');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari matakuliah...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadMatakuliah();
                      },
                    )
                  : null,
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
            onSubmitted: (value) => _loadMatakuliah(search: value),
          ),
        ),

        // Content
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
                              onPressed: _loadMatakuliah,
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
                  : _matakuliahList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.book_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada matakuliah',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadMatakuliah,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _matakuliahList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final mk = _matakuliahList[index];
                              return _buildMatakuliahCard(mk);
                            },
                          ),
                        ),
        ),

        // FAB at bottom
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Tambah Matakuliah',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatakuliahCard(MatakuliahModel mk) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFE63946).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.book, color: Color(0xFFE63946)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mk.kodeMatakuliah,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE63946),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mk.namaMatakuliah,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
            onPressed: () => _showEditDialog(mk),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => _deleteMatakuliah(mk),
          ),
        ],
      ),
    );
  }
}
