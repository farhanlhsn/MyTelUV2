import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile/models/pengajuan_plat_model.dart';
import 'package:mobile/services/kendaraan_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/utils/error_helper.dart';

class AdminPengajuanDetailPage extends StatefulWidget {
  final PengajuanPlatModel pengajuan;

  const AdminPengajuanDetailPage({
    super.key,
    required this.pengajuan,
  });

  @override
  State<AdminPengajuanDetailPage> createState() =>
      _AdminPengajuanDetailPageState();
}

class _AdminPengajuanDetailPageState extends State<AdminPengajuanDetailPage> {
  bool _isLoading = false;
  int _currentImageIndex = 0;
  final PageController _imagePageController = PageController();

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _handleApprove() async {
    final confirmed = await _showConfirmDialog(
      title: 'Setujui Pengajuan',
      message:
          'Apakah Anda yakin ingin menyetujui pengajuan kendaraan ${widget.pengajuan.platNomor}?',
      confirmText: 'SETUJUI',
      confirmColor: Colors.green,
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final success = await KendaraanService.verifyKendaraan(
        idKendaraan: widget.pengajuan.idKendaraan,
        idUser: widget.pengajuan.idUser ?? 0,
      );

      if (success) {
        ErrorHelper.showSuccess('Kendaraan berhasil disetujui');
        Navigator.pop(context, true);
      }
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Menyetujui');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReject() async {
    final feedback = await _showFeedbackDialog();
    if (feedback == null || feedback.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final success = await KendaraanService.rejectKendaraan(
        idKendaraan: widget.pengajuan.idKendaraan,
        idUser: widget.pengajuan.idUser ?? 0,
        feedback: feedback,
      );

      if (success) {
        ErrorHelper.showSuccess('Pengajuan kendaraan ditolak');
        Navigator.pop(context, true);
      }
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Menolak');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'BATAL',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              confirmText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showFeedbackDialog() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Tolak Pengajuan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Berikan alasan penolakan:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Contoh: Foto STNK tidak jelas, silakan upload ulang',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE63946)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE63946), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text(
              'BATAL',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              } else {
                ErrorHelper.showError('Feedback tidak boleh kosong');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'TOLAK',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
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
                      "Detail Pengajuan",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        height: 1.3,
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
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Vehicle Info Card
                            _buildInfoCard(),
                            const SizedBox(height: 24),

                            // Foto Kendaraan
                            _buildSectionTitle('Foto Kendaraan'),
                            const SizedBox(height: 12),
                            _buildImageCarousel(),
                            const SizedBox(height: 24),

                            // Foto STNK
                            _buildSectionTitle('Foto STNK'),
                            const SizedBox(height: 12),
                            _buildSTNKImage(),
                            const SizedBox(height: 32),

                            // Action Buttons
                            _buildActionButtons(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          // Plat Nomor
          Text(
            widget.pengajuan.platNomor,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),

          // Nama Kendaraan
          Text(
            widget.pengajuan.namaKendaraan,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // User Info Section
          if (widget.pengajuan.userName != null || widget.pengajuan.userUsername != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, size: 18, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Diajukan oleh: ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      widget.pengajuan.userName ?? widget.pengajuan.userUsername ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: widget.pengajuan.getStatusColor(),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.pengajuan.getStatusText(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    final images = widget.pengajuan.fotoKendaraan;
    if (images.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Tidak ada foto kendaraan'),
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: PageView.builder(
            controller: _imagePageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: images[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE63946),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Page Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            images.length,
            (index) => Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentImageIndex == index
                    ? const Color(0xFFE63946)
                    : Colors.grey[300],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSTNKImage() {
    final stnkUrl = widget.pengajuan.fotoSTNK;
    if (stnkUrl.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Tidak ada foto STNK'),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: stnkUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 200,
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE63946),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: 200,
          color: Colors.grey[200],
          child: const Icon(Icons.error, color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    // Don't show action buttons if already processed
    if (widget.pengajuan.statusPengajuan != 'MENUNGGU') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              widget.pengajuan.statusPengajuan == 'DISETUJUI'
                  ? Icons.check_circle
                  : Icons.cancel,
              color: widget.pengajuan.getStatusColor(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.pengajuan.statusPengajuan == 'DISETUJUI'
                    ? 'Pengajuan sudah disetujui'
                    : 'Pengajuan sudah ditolak',
                style: TextStyle(
                  color: widget.pengajuan.getStatusColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Reject Button
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleReject,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFE63946),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(
                  color: Color(0xFFE63946),
                  width: 2,
                ),
              ),
              elevation: 0,
            ),
            child: const Text(
              'TOLAK',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Approve Button
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'SETUJUI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
