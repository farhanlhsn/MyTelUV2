import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/dosen_service.dart';
import '../../utils/error_helper.dart';
import '../common/geofence_picker_page.dart';
import 'dosen_sesi_detail_page.dart';

/// Get Downloads directory path
Future<Directory> _getDownloadsDirectory() async {
  if (Platform.isAndroid) {
    final dir = await getExternalStorageDirectory();
    if (dir != null) {
      final downloadPath = '${dir.path.split('Android')[0]}Download';
      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    }
  }
  return await getApplicationDocumentsDirectory();
}

class DosenManageAbsensiPage extends StatefulWidget {
  const DosenManageAbsensiPage({super.key});

  @override
  State<DosenManageAbsensiPage> createState() => _DosenManageAbsensiPageState();
}

class _DosenManageAbsensiPageState extends State<DosenManageAbsensiPage> {
  final DosenService _dosenService = DosenService();

  List<Map<String, dynamic>> _kelasList = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Track expanded state for each kelas
  Map<int, bool> _expandedKelas = {};
  Map<int, List<Map<String, dynamic>>> _sesiMap = {};
  Map<int, bool> _loadingSesi = {};

  final Color primaryRed = const Color(0xFFE63946);

  @override
  void initState() {
    super.initState();
    _loadKelas();
  }

  Future<void> _loadKelas() async {
    setState(() => _isLoading = true);

    try {
      final kelas = await _dosenService.getKelasDiampu();
      setState(() {
        _kelasList = kelas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSesiForKelas(int idKelas) async {
    setState(() => _loadingSesi[idKelas] = true);

    try {
      final sesiList = await _dosenService.getSesiAbsensi(idKelas);
      setState(() {
        _sesiMap[idKelas] = sesiList;
        _loadingSesi[idKelas] = false;
      });
    } catch (e) {
      setState(() {
        _loadingSesi[idKelas] = false;
      });
      ErrorHelper.showError('Gagal memuat sesi: $e');
    }
  }

  void _toggleExpand(int idKelas) {
    final isExpanded = _expandedKelas[idKelas] ?? false;
    setState(() {
      _expandedKelas[idKelas] = !isExpanded;
    });

    // Load sesi if expanding and not loaded yet
    if (!isExpanded && !_sesiMap.containsKey(idKelas)) {
      _loadSesiForKelas(idKelas);
    }
  }

  void _showOpenAbsensiDialog(Map<String, dynamic> kelas) {
    final idKelas = kelas['id_kelas'] as int;
    final namaKelas = kelas['nama_kelas'] ?? 'Kelas';
    final matakuliah = kelas['matakuliah'] as Map<String, dynamic>?;
    final namaMk = matakuliah?['nama_matakuliah'] ?? '';

    int durasiMenit = 30;
    bool requireFace = false;
    double? selectedLat;
    double? selectedLng;
    int selectedRadius = 100;
    String? locationName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Buka Absensi\n$namaMk ($namaKelas)', style: const TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Durasi
                TextFormField(
                  initialValue: durasiMenit.toString(),
                  decoration: const InputDecoration(labelText: 'Durasi (menit)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => durasiMenit = int.tryParse(v) ?? 30,
                ),
                const SizedBox(height: 16),

                // Pilih Lokasi Button
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Get.to<GeofenceData>(
                      () => GeofencePickerPage(
                        initialLatitude: selectedLat,
                        initialLongitude: selectedLng,
                        initialRadius: selectedRadius,
                      ),
                    );
                    if (result != null) {
                      setDialogState(() {
                        selectedLat = result.latitude;
                        selectedLng = result.longitude;
                        selectedRadius = result.radiusMeter;
                        locationName = result.locationName;
                      });
                    }
                  },
                  icon: Icon(
                    selectedLat != null ? Icons.check_circle : Icons.map,
                    color: selectedLat != null ? Colors.green : primaryRed,
                  ),
                  label: Text(
                    selectedLat != null
                        ? 'Lokasi: ${locationName ?? 'Dipilih'} (${selectedRadius}m)'
                        : 'Pilih Lokasi Geofence',
                    style: TextStyle(
                      color: selectedLat != null ? Colors.green : primaryRed,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: selectedLat != null ? Colors.green : primaryRed,
                    ),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 16),

                // Require Face Checkbox
                CheckboxListTile(
                  value: requireFace,
                  onChanged: (v) => setDialogState(() => requireFace = v ?? false),
                  title: const Text('Perlu Verifikasi Wajah'),
                  subtitle: const Text(
                    'Mahasiswa harus selfie untuk absen',
                    style: TextStyle(fontSize: 12),
                  ),
                  activeColor: primaryRed,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: selectedLat == null
                  ? null
                  : () => _openAbsensi(
                        idKelas: idKelas,
                        durasiMenit: durasiMenit,
                        latitude: selectedLat!,
                        longitude: selectedLng!,
                        radiusMeter: selectedRadius,
                        requireFace: requireFace,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                disabledBackgroundColor: Colors.grey,
              ),
              child: const Text('Buka Absensi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAbsensi({
    required int idKelas,
    required int durasiMenit,
    required double latitude,
    required double longitude,
    required int radiusMeter,
    required bool requireFace,
  }) async {
    Navigator.pop(context);

    final now = DateTime.now();
    final selesai = now.add(Duration(minutes: durasiMenit));

    try {
      final result = await _dosenService.openAbsensi(
        idKelas: idKelas,
        mulai: now,
        selesai: selesai,
        latitude: latitude,
        longitude: longitude,
        radiusMeter: radiusMeter,
        requireFace: requireFace,
      );

      if (result['status'] == 'success') {
        ErrorHelper.showSuccess(
          'Sesi absensi dibuka sampai ${selesai.hour}:${selesai.minute.toString().padLeft(2, '0')}',
        );
        // Refresh sesi list
        _loadSesiForKelas(idKelas);
      } else {
        ErrorHelper.showError(result['message'] ?? 'Gagal membuka sesi');
      }
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Membuka Sesi');
    }
  }

  Future<void> _downloadRekap(int idKelas, String fileName) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      final bytes = await _dosenService.downloadLaporanKelas(idKelas);

      final dir = await _getDownloadsDirectory();
      final sanitized = fileName.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final file = File('${dir.path}/Rekap_$sanitized.pdf');

      await file.writeAsBytes(bytes);

      Get.back();
      
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
         ErrorHelper.showSuccess('File tersimpan di folder Download');
      }

    } catch (e) {
      Get.back();
      ErrorHelper.showError('Gagal download: $e');
    }
  }

  Future<void> _downloadRekapExcel(int idKelas, String fileName) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      final bytes = await _dosenService.downloadLaporanKelasExcel(idKelas);

      final dir = await _getDownloadsDirectory();
      final sanitized = fileName.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final file = File('${dir.path}/Rekap_$sanitized.xlsx');

      await file.writeAsBytes(bytes);

      Get.back();
      
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
         ErrorHelper.showSuccess('File tersimpan di folder Download');
      }

    } catch (e) {
      Get.back();
      ErrorHelper.showError('Gagal download: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryRed,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Kelola Absensi",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(child: Text(_errorMessage!))
                        : _kelasList.isEmpty
                            ? _buildEmptyState()
                            : _buildKelasList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.class_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Tidak ada kelas', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildKelasList() {
    return RefreshIndicator(
      onRefresh: _loadKelas,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _kelasList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final kelas = _kelasList[index];
          return _buildKelasCard(kelas);
        },
      ),
    );
  }

  Widget _buildKelasCard(Map<String, dynamic> kelas) {
    final idKelas = kelas['id_kelas'] as int;
    final namaKelas = kelas['nama_kelas'] ?? 'Kelas';
    final ruangan = kelas['ruangan'] ?? '-';
    final matakuliah = kelas['matakuliah'] as Map<String, dynamic>?;
    final namaMk = matakuliah?['nama_matakuliah'] ?? '';
    final kodeMk = matakuliah?['kode_matakuliah'] ?? '';

    final isExpanded = _expandedKelas[idKelas] ?? false;
    final sesiList = _sesiMap[idKelas] ?? [];
    final isLoadingSesi = _loadingSesi[idKelas] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryRed.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Kelas Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$namaMk ($kodeMk)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$namaKelas • $ruangan',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showOpenAbsensiDialog(kelas),
                        icon: const Icon(Icons.play_arrow, size: 18, color: Colors.white),
                        label: const Text(
                          'Buka Sesi',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleExpand(idKelas),
                        icon: Icon(
                          isExpanded ? Icons.expand_less : Icons.history,
                          size: 18,
                          color: primaryRed,
                        ),
                        label: Text(
                          isExpanded ? 'Tutup' : 'History',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryRed),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primaryRed),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Download Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _downloadRekap(idKelas, '$namaMk - $namaKelas'),
                        icon: Icon(Icons.picture_as_pdf, size: 16, color: primaryRed),
                        label: Text(
                          'PDF',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryRed),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primaryRed),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _downloadRekapExcel(idKelas, '$namaMk - $namaKelas'),
                        icon: Icon(Icons.table_chart, size: 16, color: Colors.green.shade700),
                        label: Text(
                          'Excel',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.green.shade700),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sesi List (Expandable)
          if (isExpanded)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: isLoadingSesi
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : sesiList.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Belum ada sesi absensi',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: sesiList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final sesi = sesiList[index];
                            return _buildSesiItem(sesi, '$namaMk ($namaKelas)');
                          },
                        ),
            ),
        ],
      ),
    );
  }

  Widget _buildSesiItem(Map<String, dynamic> sesi, String kelasName) {
    final idSesi = sesi['id_sesi_absensi'] as int;
    final bool isOpen = sesi['status'] == true;
    final jumlahHadir = sesi['jumlah_hadir'] ?? sesi['_count']?['absensi'] ?? 0;
    final totalPeserta = sesi['total_peserta'] ?? 0;

    DateTime? mulai;
    try {
      mulai = DateTime.parse(sesi['mulai'].toString()).toLocal();
    } catch (_) {}

    return GestureDetector(
      onTap: () {
        Get.to(() => DosenSesiDetailPage(idSesi: idSesi, kelasName: kelasName));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOpen ? Colors.green.shade200 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOpen ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mulai != null
                        ? '${mulai.day}/${mulai.month}/${mulai.year} ${mulai.hour.toString().padLeft(2, '0')}:${mulai.minute.toString().padLeft(2, '0')}'
                        : '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOpen ? 'Sedang Berlangsung' : 'Selesai',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOpen ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$jumlahHadir/$totalPeserta',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
