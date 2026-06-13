import 'package:mobile/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:mobile/pages/kendaraan/historyPengajuan/detailuserhistoripengajuan.dart';
import 'package:mobile/models/pengajuan_plat_model.dart';
import 'package:mobile/utils/ui_helpers.dart';
import 'package:mobile/services/kendaraan_service.dart';

class UserHistoriPengajuan extends StatefulWidget {
  const UserHistoriPengajuan({super.key});

  @override
  State<UserHistoriPengajuan> createState() => _UserHistoriPengajuanState();
}

class _UserHistoriPengajuanState extends State<UserHistoriPengajuan> {
  List<PengajuanPlatModel> _historiPengajuan = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filter states
  String? _filterQuery;
  DateTime? _filterDate;
  String? _filterType; // null, 'MENUNGGU', 'DISETUJUI', 'DITOLAK'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistoriPengajuan();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PengajuanPlatModel> get _filteredHistoriPengajuan {
    return _historiPengajuan.where((pengajuan) {
      bool matchSearch = true;
      if (_filterQuery != null && _filterQuery!.isNotEmpty) {
        final query = _filterQuery!.toLowerCase();
        final name = pengajuan.namaKendaraan.toLowerCase();
        final plat = pengajuan.platNomor.toLowerCase();
        matchSearch = name.contains(query) || plat.contains(query);
      }

      bool matchStatus = true;
      if (_filterType != null) {
        matchStatus = pengajuan.statusPengajuan == _filterType;
      }

      bool matchDate = true;
      if (_filterDate != null) {
        final date = pengajuan.createdAt;
        matchDate =
            date.year == _filterDate!.year &&
            date.month == _filterDate!.month &&
            date.day == _filterDate!.day;
      }

      return matchSearch && matchStatus && matchDate;
    }).toList();
  }

  Future<void> _loadHistoriPengajuan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final histori = await KendaraanService.getHistoriPengajuan();
      setState(() {
        _historiPengajuan = histori;
        _isLoading = false;
      });
    } catch (e) {
      debugLog('Error loading histori pengajuan: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE63946), // Warna header
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Anda
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 15, 25, 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const Text(
                    "Pengajuan Register Plat", // Judul disesuaikan
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Container yang di-expand
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                width: double.infinity,
                child: _buildContent(const Color(0xFFE63946)),
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
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: $_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHistoriPengajuan,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_historiPengajuan.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada pengajuan',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final filteredHistory = _filteredHistoriPengajuan;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(25, 20, 25, 0),
          child: _buildFilterBar(primaryColor),
        ),
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
                  onRefresh: _loadHistoriPengajuan,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(25, 0, 25, 20),
                    itemCount: filteredHistory.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final pengajuan = filteredHistory[index];
                      return VehicleStatusCard(
                        title: pengajuan.namaKendaraan,
                        licensePlate: pengajuan.platNomor,
                        status: pengajuan.getStatusText(),
                        statusColor: pengajuan.getStatusColor(),
                        onCheckPressed: pengajuan.canShowDetails()
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailPengajuanPlat(
                                      idKendaraan: pengajuan.idKendaraan,
                                      licensePlate: pengajuan.platNomor,
                                      status: pengajuan.getStatusText(),
                                      statusColor: pengajuan.getStatusColor(),
                                      feedback:
                                          pengajuan.feedback ??
                                          'Tidak ada feedback',
                                    ),
                                  ),
                                );
                              }
                            : null,
                      );
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
        // Cari Kendaraan
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari plat atau nama kendaraan...',
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
              // Filter Tanggal
              _buildModernChip(
                label: _filterDate == null
                    ? 'Tanggal'
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

              // Filter Status Pengajuan
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
                    value: 'MENUNGGU',
                    child: Text(
                      'Menunggu',
                      style: TextStyle(
                        color: _filterType == 'MENUNGGU'
                            ? primaryColor
                            : Colors.black87,
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'DISETUJUI',
                    child: Text(
                      'Selesai',
                      style: TextStyle(
                        color: _filterType == 'DISETUJUI'
                            ? primaryColor
                            : Colors.black87,
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'DITOLAK',
                    child: Text(
                      'Ditolak',
                      style: TextStyle(
                        color: _filterType == 'DITOLAK'
                            ? primaryColor
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
                child: _buildModernChip(
                  label: _filterType == null
                      ? 'Status'
                      : (_filterType == 'MENUNGGU'
                            ? 'Menunggu'
                            : (_filterType == 'DISETUJUI'
                                  ? 'Selesai'
                                  : 'Ditolak')),
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
}

/// MODIFIKASI:
/// Widget untuk menampilkan kartu status kendaraan.
/// Tombol "CEK" sekarang opsional (hanya tampil jika onCheckPressed diisi).
class VehicleStatusCard extends StatelessWidget {
  final String title;
  final String licensePlate;
  final String status;
  final Color statusColor;
  final VoidCallback? onCheckPressed;

  const VehicleStatusCard({
    super.key,
    required this.title,
    required this.licensePlate,
    required this.status,
    required this.statusColor,
    this.onCheckPressed,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF85E55);
    const Color borderColor = Color(0xFFF76F68);
    const Color subtitleColor = Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: borderColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Bagian kiri: Teks dan Status Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    licensePlate,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bagian kanan: Tombol "CEK" (KONDISIONAL)
            // Tombol hanya akan tampil jika onCheckPressed TIDAK null
            if (onCheckPressed != null)
              ElevatedButton(
                onPressed: onCheckPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28.0,
                    vertical: 14.0,
                  ),
                ),
                child: const Text(
                  "CEK",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
