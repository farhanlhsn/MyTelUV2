import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/dosen_service.dart';
import '../../utils/attendance_status.dart';
import '../../utils/date_helper.dart';
import '../../utils/error_helper.dart';
import '../common/error_retry_view.dart';
import 'widgets/override_status_sheet.dart';
import '../../utils/app_theme.dart';

/// Get Downloads directory path
Future<Directory> _getDownloadsDirectory() async {
  if (Platform.isAndroid) {
    // Android: Use external storage + Download folder
    final dir = await getExternalStorageDirectory();
    if (dir != null) {
      // Navigate from /storage/emulated/0/Android/data/.../files to /storage/emulated/0/Download
      final downloadPath = '${dir.path.split('Android')[0]}Download';
      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    }
  }
  // Fallback for iOS/Desktop or if external storage is not available
  return await getApplicationDocumentsDirectory();
}

class DosenSesiDetailPage extends StatefulWidget {
  final int idSesi;
  final String kelasName;

  /// For tests; the app uses the default one.
  final DosenService? dosenService;

  const DosenSesiDetailPage({
    super.key,
    required this.idSesi,
    required this.kelasName,
    this.dosenService,
  });

  @override
  State<DosenSesiDetailPage> createState() => _DosenSesiDetailPageState();
}

class _DosenSesiDetailPageState extends State<DosenSesiDetailPage> {
  late final DosenService _dosenService;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _sesiData;

  /// Numbers every request for the session data (the full load, the quiet refresh and each save):
  /// an answer is only applied while no newer request has started since, so a slow, older answer can
  /// never put back what a later change already replaced.
  int _requestSeq = 0;

  /// Saves of a status that are waiting for the server. Their rows are already changed on screen,
  /// so no refresh answer is applied while one is out.
  int _savesInFlight = 0;

  final Color primaryRed = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _dosenService = widget.dosenService ?? DosenService();
    _loadSesiDetail();
  }

  Future<void> _loadSesiDetail() async {
    // A quiet refresh that is still out is older than this load
    _requestSeq++;
    // Clear the previous error first, otherwise a successful retry would still show it
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _dosenService.getSesiDetail(widget.idSesi);
      if (!mounted) return;
      setState(() {
        _sesiData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorHelper.parseError(e);
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
        ErrorHelper.showSuccess('Sesi absensi berhasil ditutup');
        _loadSesiDetail();
      } catch (e) {
        ErrorHelper.showError(e, title: 'Gagal Menutup Sesi');
      }
    }
  }

  List<Map<String, dynamic>> get _peserta =>
      (_sesiData?['peserta'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();

  /// The session data with one peserta replaced and the header counts worked out again from the
  /// statuses (the server's rules, see [summarizeAttendance]).
  Map<String, dynamic> _withPeserta(int idUser, Map<String, dynamic> next) {
    final List<Map<String, dynamic>> peserta = <Map<String, dynamic>>[
      for (final Map<String, dynamic> item in _peserta)
        item['id_user'] == idUser ? next : item,
    ];
    final AttendanceSummary summary = summarizeAttendance(
      peserta.map(attendanceStatusOf),
    );

    return <String, dynamic>{
      ..._sesiData!,
      'peserta': peserta,
      'stats': <String, dynamic>{
        ...?(_sesiData!['stats'] as Map<String, dynamic>?),
        'total_peserta': summary.total,
        'total_hadir': summary.hadir,
        'total_telat': summary.telat,
        'total_izin': summary.izin,
        'total_sakit': summary.sakit,
        'total_tidak_hadir': summary.tidakHadir,
        'persentase': summary.persentaseLabel,
      },
    };
  }

  /// Sets the status of one student: the list shows it at once, and goes back to what it was when
  /// the server refuses. Returns the error text for the sheet, or null when it was saved.
  Future<String?> _overridePeserta(
    Map<String, dynamic> peserta,
    String status,
    String? keterangan,
  ) async {
    final int idUser = peserta['id_user'] as int;
    final Map<String, dynamic> before = _sesiData!;

    // What a refresh started before this change knows is already out of date
    _requestSeq++;
    setState(() {
      _sesiData = _withPeserta(idUser, <String, dynamic>{
        ...peserta,
        'status': status,
        'hadir': isPresentAttendance(status),
        'keterangan': keterangan,
        'waktu_absen': isPresentAttendance(status) ? peserta['waktu_absen'] : null,
      });
    });

    try {
      _savesInFlight++;
      final Map<String, dynamic> row = await _dosenService.overrideAbsensi(
        idSesi: widget.idSesi,
        idUser: idUser,
        status: status,
        keterangan: keterangan,
      );
      if (mounted && row['diubah_oleh'] != null) {
        // Keep what the server says about who set it
        final Map<String, dynamic> current = _peserta.firstWhere(
          (Map<String, dynamic> item) => item['id_user'] == idUser,
          orElse: () => peserta,
        );
        setState(() {
          _sesiData = _withPeserta(idUser, <String, dynamic>{
            ...current,
            'diubah_oleh': row['diubah_oleh'],
          });
        });
      }
      _refreshQuietly();
      return null;
    } catch (e) {
      if (mounted) setState(() => _sesiData = before);
      return ErrorHelper.parseError(e);
    } finally {
      _savesInFlight--;
    }
  }

  /// Fetches the session again without the spinner, to pick up what only the server works out
  /// (check-in time, the final percentage). A failure keeps what is on screen, and so does an
  /// answer that is no longer the latest word: another request or a save started after this one.
  Future<void> _refreshQuietly() async {
    final int seq = ++_requestSeq;
    try {
      final data = await _dosenService.getSesiDetail(widget.idSesi);
      if (!mounted || data.isEmpty) return;
      if (seq != _requestSeq || _savesInFlight > 0) {
        debugPrint('Pembaruan sesi yang sudah usang diabaikan');
        return;
      }
      setState(() => _sesiData = data);
    } catch (e) {
      debugPrint('Gagal memuat ulang sesi: $e');
    }
  }

  Future<void> _openOverrideSheet(Map<String, dynamic> peserta) async {
    final String nama = peserta['nama']?.toString() ?? '-';
    final bool? saved = await showOverrideStatusSheet(
      context,
      namaMahasiswa: nama,
      currentStatus: attendanceStatusOf(peserta),
      currentKeterangan: peserta['keterangan']?.toString(),
      onSave: (String status, String? keterangan) =>
          _overridePeserta(peserta, status, keterangan),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kehadiran $nama diperbarui'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _downloadLaporan() async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      final bytes = await _dosenService.downloadLaporanSesi(widget.idSesi);

      final dir = await _getDownloadsDirectory();
      final sanitized = widget.kelasName.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final file = File('${dir.path}/Sesi_${widget.idSesi}_$sanitized.pdf');

      await file.writeAsBytes(bytes);

      Get.back(); // close dialog
      
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
         ErrorHelper.showSuccess('File tersimpan di folder Download');
      }
    } catch (e) {
      Get.back();
      ErrorHelper.showError(e, title: 'Gagal Mengunduh');
    }
  }

  Future<void> _downloadLaporanExcel() async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      final bytes = await _dosenService.downloadLaporanSesiExcel(widget.idSesi);

      final dir = await _getDownloadsDirectory();
      final sanitized = widget.kelasName.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final file = File('${dir.path}/Sesi_${widget.idSesi}_$sanitized.xlsx');

      await file.writeAsBytes(bytes);

      Get.back();
      
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
         ErrorHelper.showSuccess('File tersimpan di folder Download');
      }
    } catch (e) {
      Get.back();
      ErrorHelper.showError(e, title: 'Gagal Mengunduh');
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Kembali',
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: () => Get.back(),
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
                        ? ErrorRetryView(
                            message: _errorMessage!,
                            onRetry: _loadSesiDetail,
                          )
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
                      'Izin/Sakit',
                      '${((stats?['total_izin'] as num?) ?? 0) + ((stats?['total_sakit'] as num?) ?? 0)}',
                      Icons.assignment_turned_in,
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
          
          // Download Buttons Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _downloadLaporan,
                  icon: Icon(Icons.picture_as_pdf, size: 16, color: primaryRed),
                  label: Text('PDF', style: TextStyle(color: primaryRed)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _downloadLaporanExcel,
                  icon: Icon(Icons.table_chart, size: 16, color: Colors.green.shade700),
                  label: Text('Excel', style: TextStyle(color: Colors.green.shade700)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.green.shade700),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
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
                return _buildPesertaTile(peserta, isOpen: isOpen);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// One student: the status chip (colour + icon + label) and, on a tap, the sheet to change it.
  Widget _buildPesertaTile(Map<String, dynamic> peserta, {required bool isOpen}) {
    final String? status = attendanceStatusOf(peserta);
    final Color color = attendanceStatusColor(status);
    final String label = attendanceStatusLabel(status, sessionOpen: isOpen);
    final String? waktuAbsen = peserta['waktu_absen']?.toString();
    final String keterangan = peserta['keterangan']?.toString().trim() ?? '';
    final bool diubahManual = peserta['diubah_oleh'] != null;

    final Widget tile = ListTile(
      key: Key('peserta-${peserta['id_user']}'),
      onTap: () => _openOverrideSheet(peserta),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(attendanceStatusIcon(status), color: color, size: 20),
      ),
      title: Text(
        peserta['nama']?.toString() ?? '-',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            peserta['username']?.toString() ?? '-',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (keterangan.isNotEmpty)
            Text(
              keterangan,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
            ),
          if (diubahManual)
            Text(
              'Diubah manual',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            key: Key('peserta-status-${peserta['id_user']}'),
            padding: const EdgeInsets.only(left: 8, right: 4, top: 2, bottom: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 16, color: color),
              ],
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

    // Own Material: the ink of the tap must not be hidden by the white sheet behind the list
    return Material(type: MaterialType.transparency, child: tile);
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    // Expanded: four counts have to fit a narrow phone
    return Expanded(
      child: Column(
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
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '-';
    try {
      return formatJam(DateTime.parse(isoTime));
    } catch (_) {
      return '-';
    }
  }
}
