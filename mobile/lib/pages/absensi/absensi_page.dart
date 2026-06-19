import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/akademik_service.dart';
import '../biometrik/biometrik_verification_page.dart';
import '../../controllers/anomali_controller.dart';

class AbsensiPage extends StatefulWidget {
  const AbsensiPage({super.key});

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  final AkademikService _akademikService = AkademikService();
  final AnomaliController _anomaliController = Get.put(AnomaliController());

  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _threshold = 75; // Default fallback

  // Filter states
  String? _filterQuery;
  DateTime? _filterDate;
  String? _filterType; // null, 'AMAN', 'KRITIS'
  final TextEditingController _searchController = TextEditingController();

  final Color primaryRed = const Color(0xFFE63946);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredHistoryData {
    return _historyData.where((item) {
      final kelas = item['kelas'] as Map<String, dynamic>?;
      final stats = item['stats'] as Map<String, dynamic>?;
      final sessions = item['sessions'] as List<dynamic>? ?? [];
      final matakuliah = kelas?['matakuliah'] as Map<String, dynamic>?;
      final dosen = kelas?['dosen'] as Map<String, dynamic>?;

      bool matchSearch = true;
      if (_filterQuery != null && _filterQuery!.isNotEmpty) {
        final query = _filterQuery!.toLowerCase();
        final subjectName = matakuliah?['nama_matakuliah']?.toString().toLowerCase() ?? '';
        final subjectCode = matakuliah?['kode_matakuliah']?.toString().toLowerCase() ?? '';
        final className = kelas?['nama_kelas']?.toString().toLowerCase() ?? '';
        final lecturerName = dosen?['nama']?.toString().toLowerCase() ?? '';
        matchSearch = subjectName.contains(query) ||
            subjectCode.contains(query) ||
            className.contains(query) ||
            lecturerName.contains(query);
      }

      bool matchStatus = true;
      if (_filterType != null) {
        final double persentase = double.tryParse(stats?['persentase']?.toString() ?? '0') ?? 0;
        if (_filterType == 'AMAN') {
          matchStatus = persentase >= _threshold;
        } else if (_filterType == 'KRITIS') {
          matchStatus = persentase < _threshold;
        }
      }

      bool matchDate = true;
      if (_filterDate != null) {
        matchDate = sessions.any((session) {
          try {
            final sessionDate = DateTime.parse(session['tanggal'].toString()).toLocal();
            return sessionDate.year == _filterDate!.year &&
                sessionDate.month == _filterDate!.month &&
                sessionDate.day == _filterDate!.day;
          } catch (_) {
            return false;
          }
        });
      }

      return matchSearch && matchStatus && matchDate;
    }).toList();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final data = await _akademikService.getAbsensiKuHistory();
      try {
        await _anomaliController.getAnomalySettings();
      } catch (e) {
        debugPrint('Gagal memuat setting anomali: $e');
      }
      setState(() {
        _historyData = data;
        _threshold = _anomaliController.thresholdJarangHadir.value;
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
                child: _buildContent(primaryRed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Color primaryColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadHistory, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_historyData.isEmpty) {
      return _buildEmptyState();
    }

    final filteredHistory = _filteredHistoryData;

    return Column(
      children: [
        _buildFilterBar(primaryColor),
        const SizedBox(height: 16),
        Expanded(
          child: filteredHistory.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada histori yang sesuai filter',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.separated(
                    itemCount: filteredHistory.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = filteredHistory[index];
                      return _buildKelasCard(item);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(Color primaryColor) {
    final bool hasFilter =
        _filterDate != null ||
        _filterType != null ||
        (_filterQuery != null && _filterQuery!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cari Kelas / Mata Kuliah
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari mata kuliah, kelas, atau dosen...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
              suffixIcon: _filterQuery != null && _filterQuery!.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: Colors.grey.shade500,
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _filterQuery = null;
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: primaryColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _filterQuery = value;
              });
            },
          ),
        ),
        const SizedBox(height: 16),

        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Filter Tanggal Sesi
              _buildModernChip(
                label: _filterDate == null
                    ? 'Tanggal Sesi'
                    : '${_filterDate!.day.toString().padLeft(2, '0')}/${_filterDate!.month.toString().padLeft(2, '0')}/${_filterDate!.year}',
                icon: Icons.calendar_today_outlined,
                isActive: _filterDate != null,
                primaryColor: primaryColor,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _filterDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(primary: primaryColor),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _filterDate = picked;
                    });
                  }
                },
                onClear: _filterDate != null
                    ? () {
                        setState(() {
                          _filterDate = null;
                        });
                      }
                    : null,
              ),
              const SizedBox(width: 8),

              // Filter Status Kehadiran
              PopupMenuButton<String>(
                initialValue: _filterType ?? 'Semua',
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (String value) {
                  setState(() {
                    _filterType = value == 'Semua' ? null : value;
                  });
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'Semua',
                    child: Text(
                      'Semua Status',
                      style: TextStyle(
                        color: _filterType == null
                            ? primaryColor
                            : Colors.black87,
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'AMAN',
                    child: Text(
                      'Kehadiran Aman (>= $_threshold%)',
                      style: TextStyle(
                        color: _filterType == 'AMAN'
                            ? primaryColor
                            : Colors.black87,
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'KRITIS',
                    child: Text(
                      'Kehadiran Kritis (< $_threshold%)',
                      style: TextStyle(
                        color: _filterType == 'KRITIS'
                            ? primaryColor
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
                child: _buildModernChip(
                  label: _filterType == null
                      ? 'Status'
                      : (_filterType == 'AMAN' ? 'Aman' : 'Kritis'),
                  icon: Icons.filter_list_rounded,
                  isActive: _filterType != null,
                  primaryColor: primaryColor,
                  onTap: null, // Handled by PopupMenuButton
                  onClear: _filterType != null
                      ? () {
                          setState(() {
                            _filterType = null;
                          });
                        }
                      : null,
                ),
              ),

              if (hasFilter) ...[
                const SizedBox(width: 12),
                Container(height: 24, width: 1, color: Colors.grey.shade300),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchController.clear();
                      _filterDate = null;
                      _filterType = null;
                      _filterQuery = null;
                    });
                  },
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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

  Widget _buildModernChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color primaryColor,
    VoidCallback? onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? primaryColor.withOpacity(0.5)
                : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? primaryColor : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? primaryColor : Colors.grey.shade700,
              ),
            ),
            if (isActive && onClear != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 14, color: primaryColor),
              ),
            ],
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
    final Color statusColor = persentase >= _threshold ? Colors.green : Colors.orange;

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
    final int? idSesiAbsensi = _readSessionId(session);
    final bool isActiveSession = session['is_active'] == true;

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
          _buildSessionAction(
            hadir: hadir,
            isActiveSession: isActiveSession,
            statusColor: statusColor,
            statusText: statusText,
            idSesiAbsensi: idSesiAbsensi,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionAction({
    required bool hadir,
    required bool isActiveSession,
    required Color statusColor,
    required String statusText,
    required int? idSesiAbsensi,
  }) {
    final Color primaryRed = const Color(0xFFE63946);
    final statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
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
    );

    if (hadir || !isActiveSession || idSesiAbsensi == null) {
      return statusBadge;
    }

    final selectedSesiId = idSesiAbsensi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        statusBadge,
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: OutlinedButton.icon(
            onPressed: () {
              Get.to(
                () => BiometrikAbsenPage(idSesiAbsensi: selectedSesiId),
                arguments: {'id_sesi_absensi': selectedSesiId},
              );
            },
            icon: const Icon(Icons.face_retouching_natural, size: 16),
            label: const Text('Absen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryRed,
              side: BorderSide(color: primaryRed.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  int? _readSessionId(Map<String, dynamic> session) {
    final value = session['id_sesi_absensi'] ?? session['id_sesi'];
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
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
