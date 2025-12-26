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

  @override
  void initState() {
    super.initState();
    _loadPengajuan();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
      );
      
      setState(() {
        _pengajuanList = result['items'] as List<PengajuanPlatModel>;
        _totalPages = result['totalPages'] as int;
        _currentPage = result['currentPage'] as int;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading pengajuan: $e');
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
      );
      
      setState(() {
        _pengajuanList.addAll(result['items'] as List<PengajuanPlatModel>);
        _currentPage = result['currentPage'] as int;
        _isLoadingMore = false;
      });
    } catch (e) {
      print('Error loading more pengajuan: $e');
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
                            ? _buildEmptyWidget()
                            : _buildListWidget(),
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

  Widget _buildEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada pengajuan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Semua pengajuan kendaraan sudah diproses',
              textAlign: TextAlign.center,
              style: TextStyle(
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
    return RefreshIndicator(
      onRefresh: _loadPengajuan,
      color: const Color(0xFFE63946),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        itemCount: _pengajuanList.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          // Show loading indicator at the bottom
          if (index == _pengajuanList.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE63946),
                ),
              ),
            );
          }
          
          final pengajuan = _pengajuanList[index];
          return _buildPengajuanCard(pengajuan);
        },
      ),
    );
  }

  Widget _buildPengajuanCard(PengajuanPlatModel pengajuan) {
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
            color: const Color(0xFFF76F68),
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
                  color: const Color(0xFFE63946).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Color(0xFFE63946),
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
                    const SizedBox(height: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(pengajuan.statusPengajuan),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(pengajuan.statusPengajuan),
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
}
