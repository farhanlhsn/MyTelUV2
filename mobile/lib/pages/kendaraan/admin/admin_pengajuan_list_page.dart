import 'dart:async';
import 'package:mobile/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile/models/pengajuan_plat_model.dart';
import 'package:mobile/services/kendaraan_service.dart';
import 'package:mobile/pages/kendaraan/admin/admin_pengajuan_detail_page.dart';



class AdminPengajuanListPage extends StatefulWidget {
  const AdminPengajuanListPage({super.key});

  @override
  State<AdminPengajuanListPage> createState() => _AdminPengajuanListPageState();
}

class _AdminPengajuanListPageState extends State<AdminPengajuanListPage> {
  List<PengajuanPlatModel> _pengajuanList = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  
  // Pagination variables
  int _currentPage = 1;
  int _totalPages = 1;
  final int _limit = 10;
  
  // Scroll controller for infinite scroll
  final ScrollController _scrollController = ScrollController();

  // Filter variables
  String? _filterQuery;
  String? _filterStatus; // null, 'MENUNGGU', 'DITOLAK'
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadPengajuan();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  List<PengajuanPlatModel> get _filteredPengajuanList {
    return _pengajuanList;
  }

  void _onScroll() {
    // Load more when reaching 80% of the scroll
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _currentPage < _totalPages) {
        _loadMorePengajuan();
      }
    }
  }

  Future<void> _loadPengajuan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final result = await KendaraanService.getAllUnverifiedKendaraan(
        page: 1,
        limit: _limit,
        search: _filterQuery,
        status: _filterStatus,
      );
      
      setState(() {
        _pengajuanList = result['items'] as List<PengajuanPlatModel>;
        _totalPages = result['totalPages'] as int;
        _currentPage = result['currentPage'] as int;
        _isLoading = false;
      });
    } catch (e) {
      debugLog('Error loading pengajuan: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePengajuan() async {
    if (_isLoadingMore || _currentPage >= _totalPages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await KendaraanService.getAllUnverifiedKendaraan(
        page: _currentPage + 1,
        limit: _limit,
        search: _filterQuery,
        status: _filterStatus,
      );
      
      setState(() {
        _pengajuanList.addAll(result['items'] as List<PengajuanPlatModel>);
        _currentPage = result['currentPage'] as int;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugLog('Error loading more pengajuan: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DISETUJUI':
        return const Color(0xFF00C853);
      case 'DITOLAK':
        return const Color(0xFFF85E55);
      case 'MENUNGGU':
      default:
        return const Color(0xFFFF9800);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'DISETUJUI':
        return 'Disetujui';
      case 'DITOLAK':
        return 'Ditolak';
      case 'MENUNGGU':
      default:
        return 'Menunggu';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE63946),
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                  const Expanded(
                    child: Text(
                      "Persetujuan Kendaraan",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        height: 1.3,
                      ),
                    ),
                  ),
                  // Badge count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_pengajuanList.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
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
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE63946),
                        ),
                      )
                    : _errorMessage != null
                        ? _buildErrorWidget()
                        : _pengajuanList.isEmpty
                            ? _buildEmptyWidget(isFiltered: false)
                            : Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                                    child: _buildFilterBar(const Color(0xFFE63946)),
                                  ),
                                  Expanded(
                                    child: _filteredPengajuanList.isEmpty
                                        ? _buildEmptyWidget(isFiltered: true)
                                        : _buildListWidget(),
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

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error: $_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPengajuan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
              ),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget({bool isFiltered = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.search_off : Icons.check_circle_outline,
              size: 80,
              color: isFiltered ? Colors.grey[400] : Colors.green[400],
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'Tidak ada hasil' : 'Tidak ada pengajuan',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered 
                  ? 'Tidak ada pengajuan yang sesuai dengan filter Anda'
                  : 'Semua pengajuan kendaraan sudah diproses',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListWidget() {
    final filteredList = _filteredPengajuanList;
    return RefreshIndicator(
      onRefresh: _loadPengajuan,
      color: const Color(0xFFE63946),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        itemCount: filteredList.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          // Show loading indicator at the bottom
          if (index == filteredList.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE63946),
                ),
              ),
            );
          }
          
          final pengajuan = filteredList[index];
          return _buildPengajuanCard(pengajuan);
        },
      ),
    );
  }

  Widget _buildPengajuanCard(PengajuanPlatModel pengajuan) {
    final isDeleteRequest = pengajuan.feedback != null && pengajuan.feedback!.startsWith('DELETE_REQUEST:');
    final deleteReason = isDeleteRequest ? pengajuan.feedback!.replaceFirst('DELETE_REQUEST:', '').trim() : '';

    final badgeColor = isDeleteRequest ? const Color(0xFFD32F2F) : _getStatusColor(pengajuan.statusPengajuan);
    final badgeText = isDeleteRequest ? 'Permintaan Hapus' : _getStatusText(pengajuan.statusPengajuan);

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminPengajuanDetailPage(
              pengajuan: pengajuan,
            ),
          ),
        );
        // Refresh list if action was taken
        if (result == true) {
          _loadPengajuan();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDeleteRequest ? const Color(0xFFD32F2F) : const Color(0xFFF76F68),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Vehicle Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: (isDeleteRequest ? const Color(0xFFD32F2F) : const Color(0xFFE63946)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDeleteRequest ? Icons.delete_forever : Icons.directions_car,
                  color: isDeleteRequest ? const Color(0xFFD32F2F) : const Color(0xFFE63946),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pengajuan.namaKendaraan,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pengajuan.platNomor,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (pengajuan.userName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${pengajuan.userName} (${pengajuan.userUsername ?? ''})',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isDeleteRequest) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD32F2F)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Alasan: $deleteReason',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFD32F2F),
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(Color primaryColor) {
    final bool hasFilter =
        _filterStatus != null ||
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
              hintText: 'Cari plat, nama kendaraan/user...',
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
                        _searchDebounce?.cancel();
                        _loadPengajuan();
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
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                _loadPengajuan();
              });
            },
          ),
        ),
        const SizedBox(height: 12),

        // Filter Chips Row
        Row(
          children: [
            // Filter Status Pengajuan
            PopupMenuButton<String>(
              initialValue: _filterStatus ?? 'Semua',
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (String value) {
                setState(() {
                  _filterStatus = value == 'Semua' ? null : value;
                });
                _loadPengajuan();
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'Semua',
                  child: Text(
                    'Semua Status',
                    style: TextStyle(
                      color: _filterStatus == null
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
                      color: _filterStatus == 'MENUNGGU'
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
                      color: _filterStatus == 'DITOLAK'
                          ? primaryColor
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
              child: _buildModernChip(
                label: _filterStatus == null
                    ? 'Status'
                    : (_filterStatus == 'MENUNGGU'
                          ? 'Menunggu'
                          : 'Ditolak'),
                icon: Icons.filter_list_rounded,
                isActive: _filterStatus != null,
                primaryColor: primaryColor,
                onTap: null,
                onClear: _filterStatus != null
                    ? () {
                        setState(() {
                          _filterStatus = null;
                        });
                        _loadPengajuan();
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
                    _filterStatus = null;
                    _filterQuery = null;
                  });
                  _searchDebounce?.cancel();
                  _loadPengajuan();
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
