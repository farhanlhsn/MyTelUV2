import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile/models/kelas.dart';
import 'package:mobile/models/matakuliah.dart';
import 'package:mobile/services/akademik_service.dart';

class AdminKelasTab extends StatefulWidget {
  const AdminKelasTab({super.key});

  @override
  State<AdminKelasTab> createState() => _AdminKelasTabState();
}

class _AdminKelasTabState extends State<AdminKelasTab> {
  final AkademikService _akademikService = AkademikService();

  List<KelasModel> _kelasList = [];
  List<MatakuliahModel> _matakuliahList = [];
  List<Map<String, dynamic>> _dosenList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load kelas, matakuliah, and dosen in parallel
      final results = await Future.wait([
        _akademikService.getAllKelas(limit: 100),
        _akademikService.getAllMatakuliah(limit: 100),
      ]);

      final mkResponse = results[1] as Map<String, dynamic>;
      final mkData = mkResponse['data'] as List<dynamic>? ?? [];

      setState(() {
        _kelasList = results[0] as List<KelasModel>;
        _matakuliahList = mkData
            .map((e) => MatakuliahModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });

      // Load dosen list (can fail gracefully)
      try {
        final dosenData = await _akademikService.getAllDosen();
        setState(() {
          _dosenList = dosenData;
        });
      } catch (_) {
        // Fallback: extract dosen from kelas list
        final Set<int> seenIds = {};
        final List<Map<String, dynamic>> fallbackDosen = [];
        for (final kelas in _kelasList) {
          if (kelas.dosen != null && !seenIds.contains(kelas.dosen!.idUser)) {
            seenIds.add(kelas.dosen!.idUser);
            fallbackDosen.add({
              'id_user': kelas.dosen!.idUser,
              'nama': kelas.dosen!.nama,
            });
          }
        }
        setState(() {
          _dosenList = fallbackDosen;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showCreateDialog() {
    int? selectedMatakuliah;
    int? selectedDosen;
    final namaKelasController = TextEditingController();
    final ruanganController = TextEditingController();
    final jamMulaiController = TextEditingController(text: '08:00:00');
    final jamBerakhirController = TextEditingController(text: '10:00:00');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Kelas', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Matakuliah Dropdown
                DropdownButtonFormField<int>(
                  value: selectedMatakuliah,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Matakuliah',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _matakuliahList.map((mk) {
                    return DropdownMenuItem(
                      value: mk.idMatakuliah,
                      child: SizedBox(
                        width: 200,
                        child: Text(
                          '${mk.kodeMatakuliah} - ${mk.namaMatakuliah}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setDialogState(() => selectedMatakuliah = value),
                ),
                const SizedBox(height: 16),

                // Dosen Dropdown
                DropdownButtonFormField<int>(
                  value: selectedDosen,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Dosen',
                    hintText: _dosenList.isEmpty ? 'Tidak ada dosen' : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _dosenList.map((dosen) {
                    return DropdownMenuItem(
                      value: dosen['id_user'] as int,
                      child: Text(
                        dosen['nama'] as String,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _dosenList.isEmpty 
                      ? null 
                      : (value) => setDialogState(() => selectedDosen = value),
                ),
                const SizedBox(height: 16),

                // Nama Kelas
                TextField(
                  controller: namaKelasController,
                  decoration: InputDecoration(
                    labelText: 'Nama Kelas',
                    hintText: 'Contoh: Kelas A',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // Ruangan
                TextField(
                  controller: ruanganController,
                  decoration: InputDecoration(
                    labelText: 'Ruangan',
                    hintText: 'Contoh: Lab 1',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // Jadwal Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: jamMulaiController,
                        decoration: InputDecoration(
                          labelText: 'Jam Mulai',
                          hintText: '08:00:00',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: jamBerakhirController,
                        decoration: InputDecoration(
                          labelText: 'Jam Berakhir',
                          hintText: '10:00:00',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
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
                if (selectedMatakuliah == null ||
                    selectedDosen == null ||
                    namaKelasController.text.isEmpty ||
                    ruanganController.text.isEmpty) {
                  Get.snackbar('Error', 'Semua field harus diisi',
                      backgroundColor: Colors.red, colorText: Colors.white);
                  return;
                }
                Navigator.pop(context);
                await _createKelas(
                  idMatakuliah: selectedMatakuliah!,
                  idDosen: selectedDosen!,
                  namaKelas: namaKelasController.text,
                  ruangan: ruanganController.text,
                  jamMulai: jamMulaiController.text,
                  jamBerakhir: jamBerakhirController.text,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('SIMPAN', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createKelas({
    required int idMatakuliah,
    required int idDosen,
    required String namaKelas,
    required String ruangan,
    required String jamMulai,
    required String jamBerakhir,
  }) async {
    try {
      await _akademikService.createKelas(
        idMatakuliah: idMatakuliah,
        idDosen: idDosen,
        namaKelas: namaKelas,
        ruangan: ruangan,
        jamMulai: jamMulai,
        jamBerakhir: jamBerakhir,
      );
      Get.snackbar('Berhasil', 'Kelas berhasil ditambahkan',
          backgroundColor: Colors.green, colorText: Colors.white);
      _loadData();
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _deleteKelas(KelasModel kelas) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kelas'),
        content: Text('Apakah Anda yakin ingin menghapus ${kelas.namaKelas}?'),
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
      await _akademikService.deleteKelas(kelas.idKelas);
      Get.snackbar('Berhasil', 'Kelas berhasil dihapus',
          backgroundColor: Colors.green, colorText: Colors.white);
      _loadData();
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                            onPressed: _loadData,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    )
                  : _kelasList.isEmpty
                      ? const Center(
                          child: Text('Belum ada kelas', style: TextStyle(color: Colors.grey)),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _kelasList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildKelasCard(_kelasList[index]);
                            },
                          ),
                        ),
        ),

        // Add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Tambah Kelas',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKelasCard(KelasModel kelas) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.class_, color: Color(0xFFE63946)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kelas.namaKelas,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (kelas.matakuliah != null)
                      Text(
                        '${kelas.matakuliah!.kodeMatakuliah} - ${kelas.matakuliah!.namaMatakuliah}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () => _deleteKelas(kelas),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                kelas.dosen?.nama ?? '-',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              Icon(Icons.room, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                kelas.ruangan ?? '-',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          if (kelas.jadwal != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  kelas.jadwal!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
