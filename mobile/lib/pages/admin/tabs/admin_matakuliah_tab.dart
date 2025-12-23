import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile/models/matakuliah.dart';
import 'package:mobile/services/akademik_service.dart';

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
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showCreateDialog() {
    final namaController = TextEditingController();
    final kodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Tambah Matakuliah',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: kodeController,
                decoration: InputDecoration(
                  labelText: 'Kode Matakuliah',
                  hintText: 'Contoh: IF101',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: namaController,
                decoration: InputDecoration(
                  labelText: 'Nama Matakuliah',
                  hintText: 'Contoh: Pemrograman Dasar',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
              if (namaController.text.isEmpty || kodeController.text.isEmpty) {
                Get.snackbar('Error', 'Semua field harus diisi',
                    backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }
              Navigator.pop(context);
              await _createMatakuliah(
                namaController.text,
                kodeController.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('SIMPAN', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(MatakuliahModel mk) {
    final namaController = TextEditingController(text: mk.namaMatakuliah);
    final kodeController = TextEditingController(text: mk.kodeMatakuliah);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Matakuliah',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: kodeController,
                decoration: InputDecoration(
                  labelText: 'Kode Matakuliah',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: namaController,
                decoration: InputDecoration(
                  labelText: 'Nama Matakuliah',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
              Navigator.pop(context);
              await _updateMatakuliah(
                mk.idMatakuliah,
                namaController.text,
                kodeController.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('UPDATE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createMatakuliah(String nama, String kode) async {
    try {
      await _akademikService.createMatakuliah(
        namaMatakuliah: nama,
        kodeMatakuliah: kode,
      );
      Get.snackbar('Berhasil', 'Matakuliah berhasil ditambahkan',
          backgroundColor: Colors.green, colorText: Colors.white);
      _loadMatakuliah();
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _updateMatakuliah(int id, String nama, String kode) async {
    try {
      await _akademikService.updateMatakuliah(
        idMatakuliah: id,
        namaMatakuliah: nama,
        kodeMatakuliah: kode,
      );
      Get.snackbar('Berhasil', 'Matakuliah berhasil diupdate',
          backgroundColor: Colors.green, colorText: Colors.white);
      _loadMatakuliah();
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _deleteMatakuliah(MatakuliahModel mk) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Matakuliah'),
        content: Text('Apakah Anda yakin ingin menghapus ${mk.namaMatakuliah}?'),
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
      await _akademikService.deleteMatakuliah(mk.idMatakuliah);
      Get.snackbar('Berhasil', 'Matakuliah berhasil dihapus',
          backgroundColor: Colors.green, colorText: Colors.white);
      _loadMatakuliah();
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadMatakuliah,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    )
                  : _matakuliahList.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada matakuliah',
                            style: TextStyle(color: Colors.grey),
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
