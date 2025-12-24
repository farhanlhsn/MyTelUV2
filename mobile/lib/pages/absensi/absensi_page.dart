import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/akademik_service.dart';
import '../biometrik/biometrik_verification_page.dart';

class AbsensiPage extends StatefulWidget {
  const AbsensiPage({super.key});

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  final AkademikService _akademikService = AkademikService();

  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;
  String? _errorMessage;

  final Color primaryRed = const Color(0xFFE63946);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final data = await _akademikService.getAbsensiKuHistory();
      setState(() {
        _historyData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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
                  const Text(
                    "Histori Kehadiran",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                padding: const EdgeInsets.all(20),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(child: Text(_errorMessage!))
                        : _historyData.isEmpty
                            ? _buildEmptyState()
                            : _buildHistoryList(),
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
          Icon(Icons.class_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Belum ada kelas terdaftar',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Daftar kelas terlebih dahulu',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        itemCount: _historyData.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final item = _historyData[index];
          return _buildKelasCard(item);
        },
      ),
    );
  }

  Widget _buildKelasCard(Map<String, dynamic> item) {
    final kelas = item['kelas'] as Map<String, dynamic>?;
    final stats = item['stats'] as Map<String, dynamic>?;
    final sessions = item['sessions'] as List<dynamic>? ?? [];

    final matakuliah = kelas?['matakuliah'] as Map<String, dynamic>?;
    final dosen = kelas?['dosen'] as Map<String, dynamic>?;

    final String title = matakuliah != null
        ? '${matakuliah['nama_matakuliah']} (${matakuliah['kode_matakuliah']})'
        : 'Kelas';

    final String kelasInfo = kelas != null
        ? '${kelas['nama_kelas']} • ${kelas['ruangan'] ?? "-"}'
        : '';

    final String dosenInfo = dosen != null ? 'Dosen: ${dosen['nama']}' : '';

    final double persentase = double.tryParse(stats?['persentase']?.toString() ?? '0') ?? 0;
    final Color statusColor = persentase >= 75 ? Colors.green : Colors.orange;

    final int idKelas = kelas?['id_kelas'] as int? ?? 0;

    return GestureDetector(
      onTap: () {
        Get.to(() => AbsensiDetailPage(
          kelasName: title,
          idKelas: idKelas,
          sessions: sessions,
          stats: stats,
        ));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryRed.withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kelasInfo,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (dosenInfo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      dosenInfo,
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryRed.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${stats?['total_hadir'] ?? 0}/${stats?['total_sesi'] ?? 0} sesi hadir',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${persentase.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AbsensiDetailPage extends StatelessWidget {
  final String kelasName;
  final int idKelas;
  final List<dynamic> sessions;
  final Map<String, dynamic>? stats;

  const AbsensiDetailPage({
    super.key,
    required this.kelasName,
    required this.idKelas,
    required this.sessions,
    this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFFE63946);

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
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Daftar Absensi",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // Judul Mata Kuliah
                    Text(
                      kelasName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Stats summary
                    if (stats != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                            const SizedBox(width: 6),
                            Text(
                              'Hadir: ${stats!['total_hadir']}',
                              style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.cancel, size: 16, color: Colors.red.shade400),
                            const SizedBox(width: 6),
                            Text(
                              'Tidak Hadir: ${stats!['total_tidak_hadir']}',
                              style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Tombol Verifikasi Wajah
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Get.to(() => const BiometrikAbsenPage());
                        },
                        icon: const Icon(Icons.face_retouching_natural, size: 20),
                        label: const Text(
                          'Absen Biometrik',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Sessions List
                    Expanded(
                      child: sessions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy, size: 60, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum ada sesi absensi',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: primaryRed.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: sessions.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: Colors.grey.shade300,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                itemBuilder: (context, index) {
                                  final session = sessions[index] as Map<String, dynamic>;
                                  return _buildSessionItem(session);
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

  Widget _buildSessionItem(Map<String, dynamic> session) {
    final bool hadir = session['hadir'] == true;
    final Color statusColor = hadir ? Colors.green : Colors.red;
    final String statusText = hadir ? 'Hadir' : 'Tidak Hadir';

    DateTime? tanggal;
    try {
      tanggal = DateTime.parse(session['tanggal'].toString()).toLocal();
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(
            hadir ? Icons.check_circle : Icons.cancel,
            color: statusColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tanggal != null ? _formatDate(tanggal) : '-',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                if (hadir && session['waktu_absen'] != null)
                  Text(
                    'Absen: ${_formatTime(session['waktu_absen'].toString())}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }
}