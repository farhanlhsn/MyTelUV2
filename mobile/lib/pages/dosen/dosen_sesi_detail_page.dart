import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/dosen_service.dart';

class DosenSesiDetailPage extends StatefulWidget {
  final int idSesi;
  final String kelasName;

  const DosenSesiDetailPage({
    super.key,
    required this.idSesi,
    required this.kelasName,
  });

  @override
  State<DosenSesiDetailPage> createState() => _DosenSesiDetailPageState();
}

class _DosenSesiDetailPageState extends State<DosenSesiDetailPage> {
  final DosenService _dosenService = DosenService();

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _sesiData;

  final Color primaryRed = const Color(0xFFE63946);

  @override
  void initState() {
    super.initState();
    _loadSesiDetail();
  }

  Future<void> _loadSesiDetail() async {
    setState(() => _isLoading = true);

    try {
      final data = await _dosenService.getSesiDetail(widget.idSesi);
      setState(() {
        _sesiData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _closeSesi() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tutup Sesi Absensi?'),
        content: const Text('Sesi yang ditutup tidak dapat dibuka kembali.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
            child: const Text('Tutup', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dosenService.closeSesiAbsensi(widget.idSesi);
        Get.snackbar(
          'Berhasil',
          'Sesi absensi berhasil ditutup',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        _loadSesiDetail();
      } catch (e) {
        Get.snackbar(
          'Gagal',
          e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _downloadLaporan() async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      final bytes = await _dosenService.downloadLaporanSesi(widget.idSesi);

      final dir = await getApplicationDocumentsDirectory();
      final sanitized = widget.kelasName.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final file = File('${dir.path}/Sesi_${widget.idSesi}_$sanitized.pdf');

      await file.writeAsBytes(bytes);

      Get.back(); // close dialog
      
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
         Get.snackbar('Info', 'File tersimpan di ${file.path}.', 
            backgroundColor: Colors.orange, colorText: Colors.white);
      }
    } catch (e) {
      Get.back();
      Get.snackbar('Error', 'Gagal download: $e', backgroundColor: Colors.red, colorText: Colors.white);
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
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.kelasName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Body
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
                        : _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_sesiData == null) return const Center(child: Text('Data tidak tersedia'));

    final sesi = _sesiData!['sesi'] as Map<String, dynamic>?;
    final pesertaList = _sesiData!['peserta'] as List<dynamic>? ?? [];
    final stats = _sesiData!['stats'] as Map<String, dynamic>?;

    final bool isOpen = sesi?['status'] == true;

    return RefreshIndicator(
      onRefresh: _loadSesiDetail,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Stats Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryRed, primaryRed.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      'Total',
                      '${stats?['total_peserta'] ?? 0}',
                      Icons.people,
                    ),
                    _buildStatItem(
                      'Hadir',
                      '${stats?['total_hadir'] ?? 0}',
                      Icons.check_circle,
                    ),
                    _buildStatItem(
                      'Tidak Hadir',
                      '${stats?['total_tidak_hadir'] ?? 0}',
                      Icons.cancel,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${stats?['persentase'] ?? 0}% Kehadiran',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Session Status & Close Button
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOpen ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOpen ? Colors.green.shade200 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOpen ? Icons.lock_open : Icons.lock,
                        size: 16,
                        color: isOpen ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOpen ? 'Sesi Terbuka' : 'Sesi Tertutup',
                        style: TextStyle(
                          fontSize: 13,
                          color: isOpen ? Colors.green.shade700 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isOpen) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _closeSesi,
                  icon: const Icon(Icons.lock, size: 16, color: Colors.white),
                  label: const Text('Tutup Sesi', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _downloadLaporan,
              icon: Icon(Icons.picture_as_pdf, size: 18, color: primaryRed),
              label: Text('Download Laporan Sesi', style: TextStyle(color: primaryRed)),
               style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryRed),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
            ),
          ),

          const SizedBox(height: 20),

          // Peserta List
          Text(
            'Daftar Peserta',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              border: Border.all(color: primaryRed.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pesertaList.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final peserta = pesertaList[index] as Map<String, dynamic>;
                final bool hadir = peserta['hadir'] == true;
                final String? waktuAbsen = peserta['waktu_absen']?.toString();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: hadir ? Colors.green.shade100 : Colors.red.shade100,
                    child: Icon(
                      hadir ? Icons.check : Icons.close,
                      color: hadir ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    peserta['nama']?.toString() ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    peserta['username']?.toString() ?? '-',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: hadir ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hadir ? 'Hadir' : 'Tidak Hadir',
                          style: TextStyle(
                            fontSize: 11,
                            color: hadir ? Colors.green.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (waktuAbsen != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _formatTime(waktuAbsen),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '-';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }
}
