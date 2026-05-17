import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../models/pengajuan_plat_model.dart';
import '../../../services/kendaraan_service.dart';

class PengajuanListPage extends StatefulWidget {
  const PengajuanListPage({super.key});

  @override
  State<PengajuanListPage> createState() => _PengajuanListPageState();
}

class _PengajuanListPageState extends State<PengajuanListPage> {
  List<PengajuanPlatModel> pengajuanList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final data = await KendaraanService.getAllUnverifiedKendaraan();
      setState(() {
        pengajuanList = data['items'] as List<PengajuanPlatModel>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(PengajuanPlatModel pengajuan, String action) async {
    try {
      bool success = false;
      
      if (action == 'DISETUJUI') {
        success = await KendaraanService.verifyKendaraan(
          idKendaraan: pengajuan.idKendaraan,
          idUser: pengajuan.idUser ?? 0,
        );
      } else {
        // Show feedback dialog for rejection
        final feedback = await _showFeedbackDialog();
        if (feedback == null || feedback.isEmpty) return;
        
        success = await KendaraanService.rejectKendaraan(
          idKendaraan: pengajuan.idKendaraan,
          idUser: pengajuan.idUser ?? 0,
          feedback: feedback,
        );
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'DISETUJUI'
                  ? 'Pengajuan berhasil disetujui'
                  : 'Pengajuan berhasil ditolak',
            ),
            backgroundColor: action == 'DISETUJUI' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData(); // Refresh list
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _showFeedbackDialog() async {
    final TextEditingController feedbackController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Alasan Penolakan'),
          content: TextField(
            controller: feedbackController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Masukkan alasan penolakan...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (feedbackController.text.trim().isNotEmpty) {
                  Navigator.pop(context, feedbackController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Tolak'),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmDialog(PengajuanPlatModel pengajuan, String action) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            action == 'DISETUJUI' ? 'Setujui Pengajuan?' : 'Tolak Pengajuan?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            action == 'DISETUJUI'
                ? 'Apakah Anda yakin ingin menyetujui pengajuan ini?'
                : 'Apakah Anda yakin ingin menolak pengajuan ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus(pengajuan, action);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'DISETUJUI' ? Colors.green : Colors.red,
              ),
              child: Text(action == 'DISETUJUI' ? 'Setujui' : 'Tolak'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFE63946);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          // Header
          Container(
            height: 150,
            decoration: const BoxDecoration(color: primaryColor),
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(top: 40, left: 10),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20.0,
                  ),
                  onPressed: () => Get.back(),
                ),
                const Text(
                  'Pengajuan Register Plat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: _buildContent(primaryColor),
            ),
          ),
        ],
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
            TextButton(
              onPressed: _loadData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (pengajuanList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Belum ada pengajuan',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pengajuanList.length,
        itemBuilder: (context, index) {
          return _buildPengajuanCard(pengajuanList[index], primaryColor);
        },
      ),
    );
  }

  Widget _buildPengajuanCard(PengajuanPlatModel pengajuan, Color primaryColor) {
    final bool isPending = pengajuan.statusPengajuan == 'MENUNGGU';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor, width: 2),
      ),
      child: Row(
        children: [
          // Kolom Kiri: Nama, Plat, dan Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pengajuan.namaKendaraan,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pengajuan.platNomor,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: pengajuan.getStatusColor(),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pengajuan.getStatusText(),
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

          const SizedBox(width: 16),

          // Kolom Kanan: Tombol TOLAK dan TERIMA
          Column(
            children: [
              Container(
                width: 90,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPending ? primaryColor : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: TextButton(
                  onPressed: isPending
                      ? () => _showConfirmDialog(pengajuan, 'DITOLAK')
                      : null,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'TOLAK',
                    style: TextStyle(
                      color: isPending ? primaryColor : Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 90,
                height: 36,
                decoration: BoxDecoration(
                  color: isPending ? primaryColor : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextButton(
                  onPressed: isPending
                      ? () => _showConfirmDialog(pengajuan, 'DISETUJUI')
                      : null,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'TERIMA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
