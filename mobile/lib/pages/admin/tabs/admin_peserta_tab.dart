import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile/models/kelas.dart';
import 'package:mobile/services/akademik_service.dart';

class AdminPesertaTab extends StatefulWidget {
  const AdminPesertaTab({super.key});

  @override
  State<AdminPesertaTab> createState() => _AdminPesertaTabState();
}

class _AdminPesertaTabState extends State<AdminPesertaTab> {
  final AkademikService _akademikService = AkademikService();

  List<KelasModel> _kelasList = [];
  List<Map<String, dynamic>> _pesertaList = [];
  List<Map<String, dynamic>> _mahasiswaList = [];
  KelasModel? _selectedKelas;
  bool _isLoadingKelas = true;
  bool _isLoadingPeserta = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadKelas();
    _loadMahasiswa();
  }

  Future<void> _loadKelas() async {
    setState(() {
      _isLoadingKelas = true;
      _error = null;
    });

    try {
      final kelasList = await _akademikService.getAllKelas(limit: 100);
      setState(() {
        _kelasList = kelasList;
        _isLoadingKelas = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingKelas = false;
      });
    }
  }

  Future<void> _loadMahasiswa() async {
    try {
      final mahasiswaList = await _akademikService.getAllMahasiswa();
      setState(() {
        _mahasiswaList = mahasiswaList;
      });
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _loadPeserta(int idKelas) async {
    setState(() {
      _isLoadingPeserta = true;
    });

    try {
      final peserta = await _akademikService.getPesertaKelas(idKelas);
      setState(() {
        _pesertaList = peserta;
        _isLoadingPeserta = false;
      });
    } catch (e) {
      setState(() {
        _pesertaList = [];
        _isLoadingPeserta = false;
      });
    }
  }

  void _showAddPesertaDialog() {
    if (_selectedKelas == null) {
      Get.snackbar('Error', 'Pilih kelas terlebih dahulu',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    // Filter mahasiswa yang belum terdaftar di kelas ini
    final existingIds = _pesertaList
        .map((p) => (p['mahasiswa'] as Map<String, dynamic>?)?['id_user'] as int?)
        .whereType<int>()
        .toSet();
    final availableMahasiswa = _mahasiswaList
        .where((m) => !existingIds.contains(m['id_user'] as int))
        .toList();

    if (availableMahasiswa.isEmpty) {
      Get.snackbar('Info', 'Semua mahasiswa sudah terdaftar di kelas ini',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    int? selectedMahasiswa;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Peserta', style: TextStyle(fontWeight: FontWeight.bold)),
          content: DropdownButtonFormField<int>(
            value: selectedMahasiswa,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Pilih Mahasiswa',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: availableMahasiswa.map((m) {
              return DropdownMenuItem(
                value: m['id_user'] as int,
                child: Text(
                  '${m['nama']} (${m['username']})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) => setDialogState(() => selectedMahasiswa = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: selectedMahasiswa == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _addPeserta(selectedMahasiswa!);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('TAMBAH', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPeserta(int idMahasiswa) async {
    try {
      await _akademikService.adminAddPeserta(
        idKelas: _selectedKelas!.idKelas,
        idMahasiswa: idMahasiswa,
      );
      Get.snackbar('Berhasil', 'Peserta berhasil ditambahkan',
          backgroundColor: Colors.green, colorText: Colors.white);
      _loadPeserta(_selectedKelas!.idKelas);
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Kelas Dropdown
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: _isLoadingKelas
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<KelasModel>(
                      isExpanded: true,
                      value: _selectedKelas,
                      hint: const Text('Pilih Kelas'),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: _kelasList.map((kelas) {
                        final mkCode = kelas.matakuliah?.kodeMatakuliah ?? '';
                        return DropdownMenuItem(
                          value: kelas,
                          child: Text(
                            '$mkCode - ${kelas.namaKelas}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (kelas) {
                        setState(() {
                          _selectedKelas = kelas;
                          _pesertaList = [];
                        });
                        if (kelas != null) {
                          _loadPeserta(kelas.idKelas);
                        }
                      },
                    ),
                  ),
          ),
        ),

        // Peserta count
        if (_selectedKelas != null && !_isLoadingPeserta)
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
                    'Total Peserta: ${_pesertaList.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE63946),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.person_add, color: Color(0xFFE63946)),
                    onPressed: _showAddPesertaDialog,
                    tooltip: 'Tambah Peserta',
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Peserta List
        Expanded(
          child: _selectedKelas == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.class_, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Pilih kelas untuk melihat peserta',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : _isLoadingPeserta
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFE63946)),
                    )
                  : _pesertaList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_off, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'Belum ada peserta di kelas ini',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showAddPesertaDialog,
                                icon: const Icon(Icons.person_add, color: Colors.white),
                                label: const Text('Tambah Peserta',
                                    style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE63946),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadPeserta(_selectedKelas!.idKelas),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _pesertaList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final peserta = _pesertaList[index];
                              final mahasiswa = peserta['mahasiswa'] as Map<String, dynamic>?;
                              return _buildPesertaCard(mahasiswa, index + 1);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildPesertaCard(Map<String, dynamic>? mahasiswa, int number) {
    final nama = mahasiswa?['nama'] ?? 'Unknown';
    final username = mahasiswa?['username'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE63946).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE63946),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  username,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.person, color: Colors.grey),
        ],
      ),
    );
  }
}
