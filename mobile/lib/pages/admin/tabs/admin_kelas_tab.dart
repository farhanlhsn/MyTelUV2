import 'package:flutter/material.dart';
import 'package:mobile/models/kelas.dart';
import 'package:mobile/models/matakuliah.dart';
import 'package:mobile/services/akademik_service.dart';
import 'package:mobile/utils/error_helper.dart';

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

  final List<String> _days = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
  ];

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
        _error = ErrorHelper.parseError(e);
        _isLoading = false;
      });
    }
  }

  void _showFormDialog({KelasModel? kelas}) {
    final isEdit = kelas != null;
    final formKey = GlobalKey<FormState>();
    int? selectedMatakuliah = kelas?.matakuliah?.idMatakuliah;
    int? selectedDosen = kelas?.dosen?.idUser;
    int? selectedHari = kelas?.hari;
    
    final namaKelasController = TextEditingController(text: kelas?.namaKelas);
    final ruanganController = TextEditingController(text: kelas?.ruangan);
    
    String initialMul = kelas?.jadwal?.split('-')[0].trim() ?? '08:00:00';
    String initialSel = kelas?.jadwal?.split('-')[1].trim() ?? '10:00:00';
    
    if (initialMul.isEmpty) initialMul = '08:00:00';
    if (initialSel.isEmpty) initialSel = '10:00:00';

    final jamMulaiController = TextEditingController(text: initialMul);
    final jamBerakhirController = TextEditingController(text: initialSel);
    
    bool isSubmitting = false;
    String? matakuliahError;
    String? dosenError;
    String? hariError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'Edit Kelas' : 'Tambah Kelas', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Matakuliah Dropdown with validation
                  DropdownButtonFormField<int>(
                    value: selectedMatakuliah,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Matakuliah *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorText: matakuliahError,
                      errorMaxLines: 2,
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
                    onChanged: (value) {
                      setDialogState(() {
                        selectedMatakuliah = value;
                        matakuliahError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Dosen Dropdown with validation
                  DropdownButtonFormField<int>(
                    value: selectedDosen,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Dosen *',
                      hintText: _dosenList.isEmpty ? 'Tidak ada dosen' : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorText: dosenError,
                      errorMaxLines: 2,
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
                        : (value) {
                            setDialogState(() {
                              selectedDosen = value;
                              dosenError = null;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  
                  // Hari Dropdown with validation
                  DropdownButtonFormField<int>(
                    value: selectedHari,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Hari *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorText: hariError,
                      errorMaxLines: 2,
                    ),
                    items: List.generate(7, (index) {
                       return DropdownMenuItem(
                         value: index + 1,
                         child: Text(_days[index]),
                       );
                    }),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedHari = value;
                        hariError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Nama Kelas with validation
                  TextFormField(
                    controller: namaKelasController,
                    decoration: InputDecoration(
                      labelText: 'Nama Kelas *',
                      hintText: 'Contoh: Kelas A',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorMaxLines: 2,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama kelas tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Ruangan with validation
                  TextFormField(
                    controller: ruanganController,
                    decoration: InputDecoration(
                      labelText: 'Ruangan *',
                      hintText: 'Contoh: Lab 1',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorMaxLines: 2,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ruangan tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Jadwal Row with validation
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: jamMulaiController,
                          decoration: InputDecoration(
                            labelText: 'Jam Mulai *',
                            hintText: '08:00:00',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            errorMaxLines: 2,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Wajib diisi';
                            }
                            // Validate time format
                            final timeRegex = RegExp(r'^\d{2}:\d{2}(:\d{2})?$');
                            if (!timeRegex.hasMatch(value)) {
                              return 'Format: HH:MM';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: jamBerakhirController,
                          decoration: InputDecoration(
                            labelText: 'Jam Berakhir *',
                            hintText: '10:00:00',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            errorMaxLines: 2,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Wajib diisi';
                            }
                            final timeRegex = RegExp(r'^\d{2}:\d{2}(:\d{2})?$');
                            if (!timeRegex.hasMatch(value)) {
                              return 'Format: HH:MM';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
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
                      // Manual validation for dropdowns
                      bool hasDropdownError = false;
                      
                      if (selectedMatakuliah == null) {
                        matakuliahError = 'Pilih matakuliah';
                        hasDropdownError = true;
                      }
                      if (selectedDosen == null) {
                        dosenError = 'Pilih dosen';
                        hasDropdownError = true;
                      }
                      if (selectedHari == null) {
                        hariError = 'Pilih hari';
                        hasDropdownError = true;
                      }
                      
                      if (hasDropdownError) {
                        setDialogState(() {});
                      }

                      if (formKey.currentState!.validate() && !hasDropdownError) {
                        setDialogState(() => isSubmitting = true);
                        
                        bool success;
                        if (isEdit) {
                          success = await _updateKelas(
                            idKelas: kelas.idKelas,
                            idMatakuliah: selectedMatakuliah!,
                            idDosen: selectedDosen!,
                            namaKelas: namaKelasController.text.trim(),
                            ruangan: ruanganController.text.trim(),
                            jamMulai: jamMulaiController.text.trim(),
                            jamBerakhir: jamBerakhirController.text.trim(),
                            hari: selectedHari,
                          );
                        } else {
                          success = await _createKelas(
                            idMatakuliah: selectedMatakuliah!,
                            idDosen: selectedDosen!,
                            namaKelas: namaKelasController.text.trim(),
                            ruangan: ruanganController.text.trim(),
                            jamMulai: jamMulaiController.text.trim(),
                            jamBerakhir: jamBerakhirController.text.trim(),
                            hari: selectedHari,
                          );
                        }
                        
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
                  : const Text('SIMPAN', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _createKelas({
    required int idMatakuliah,
    required int idDosen,
    required String namaKelas,
    required String ruangan,
    required String jamMulai,
    required String jamBerakhir,
    int? hari,
  }) async {
    try {
      await _akademikService.createKelas(
        idMatakuliah: idMatakuliah,
        idDosen: idDosen,
        namaKelas: namaKelas,
        ruangan: ruangan,
        jamMulai: jamMulai,
        jamBerakhir: jamBerakhir,
        hari: hari,
      );
      ErrorHelper.showSuccess('Kelas berhasil ditambahkan');
      _loadData();
      return true;
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Menambah Kelas');
      return false;
    }
  }

  Future<bool> _updateKelas({
    required int idKelas,
    required int idMatakuliah,
    required int idDosen,
    required String namaKelas,
    required String ruangan,
    required String jamMulai,
    required String jamBerakhir,
    int? hari,
  }) async {
    try {
      await _akademikService.updateKelas(
        idKelas: idKelas,
        idMatakuliah: idMatakuliah,
        idDosen: idDosen,
        namaKelas: namaKelas,
        ruangan: ruangan,
        jamMulai: jamMulai,
        jamBerakhir: jamBerakhir,
        hari: hari,
      );
      ErrorHelper.showSuccess('Kelas berhasil diperbarui');
      _loadData();
      return true;
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Memperbarui Kelas');
      return false;
    }
  }

  Future<void> _deleteKelas(KelasModel kelas) async {
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
            const Expanded(child: Text('Hapus Kelas')),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus "${kelas.namaKelas}"?'),
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
      await _akademikService.deleteKelas(kelas.idKelas);
      ErrorHelper.showSuccess('Kelas berhasil dihapus');
      _loadData();
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Menghapus Kelas');
    }
  }

  Future<void> _deleteAllKelas() async {
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
              child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Hapus SEMUA Kelas')),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin menghapus SEMUA kelas?\n\nTindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('HAPUS SEMUA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _akademikService.deleteAllKelas();
      ErrorHelper.showSuccess('Semua kelas berhasil dihapus');
      _loadData();
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Menghapus Kelas');
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
                              onPressed: _loadData,
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
                  : _kelasList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.class_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada kelas',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
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

        // Buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showFormDialog(),
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
              if (_kelasList.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _deleteAllKelas,
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text(
                      'Hapus Semua Kelas',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKelasCard(KelasModel kelas) {
    String hariStr = '';
    if (kelas.hari != null && kelas.hari! >= 1 && kelas.hari! <= 7) {
      hariStr = _days[kelas.hari! - 1];
    }

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                    onPressed: () => _showFormDialog(kelas: kelas),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteKelas(kelas),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  kelas.dosen?.nama ?? '-',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
           const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.room, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                kelas.ruangan ?? '-',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              if (hariStr.isNotEmpty) ...[
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  hariStr,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
              ],
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
