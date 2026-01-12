import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/parkir_service.dart';
import '../../../models/parkir_model.dart';

class HistoriParkirPage extends StatefulWidget {
  const HistoriParkirPage({super.key});

  @override
  State<HistoriParkirPage> createState() => _HistoriParkirPageState();
}

class _HistoriParkirPageState extends State<HistoriParkirPage> {
  final ParkirService _parkirService = ParkirService();
  List<LogParkirModel> _logParkir = [];
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

      final data = await _parkirService.getHistoriParkir();
      setState(() {
        _logParkir = data;
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
    final Color primaryRed = const Color(0xFFE63946);

    return Scaffold(
      backgroundColor: primaryRed,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- HEADER ---
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
                    "Histori Parkir",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // --- BODY (Kertas Putih Melengkung) ---
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
            TextButton(
              onPressed: _loadData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_logParkir.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_parking, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Belum ada histori parkir',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Histori parkir akan muncul setelah Anda menggunakan fasilitas parkir',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        itemCount: _logParkir.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final log = _logParkir[index];
          return _buildHistoryCard(
            platNomor: log.kendaraan?.platNomor ?? 'Unknown',
            namaKendaraan: log.kendaraan?.namaKendaraan ?? '',
            lokasi: log.parkiran?.namaParkiran ?? 'Unknown',
            waktu: _formatDateTime(log.localTimestamp),
            type: log.type,
            imageUrl: log.imageUrl,
            faceImageUrl: log.faceImageUrl,
            faceDetected: log.faceDetected,
            primaryColor: primaryColor,
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 
                    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} | '
           '${dateTime.hour.toString().padLeft(2, '0')}.${dateTime.minute.toString().padLeft(2, '0')} WIB';
  }


  Widget _buildHistoryCard({
    required String platNomor,
    required String namaKendaraan,
    required String lokasi,
    required String waktu,
    String? type,
    String? imageUrl,
    String? faceImageUrl,
    bool faceDetected = false,
    required Color primaryColor,
  }) {
    // Colors for entry/exit badges
    final isMasuk = type == 'MASUK';
    final typeColor = isMasuk ? Colors.green : Colors.orange;
    final typeIcon = isMasuk ? Icons.login : Icons.logout;
    final typeText = isMasuk ? 'MASUK' : 'KELUAR';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Plat Nomor + Type Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Plat Nomor (Bold)
              Text(
                platNomor,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              // Type Badge
              if (type != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: typeColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 14, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        typeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (namaKendaraan.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              namaKendaraan,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          
          // Images Row: Plate image (left) + Face image (right)
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
             const SizedBox(height: 8),
             Row(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // Plate image (main, larger)
                 Expanded(
                   flex: 3,
                   child: GestureDetector(
                     onTap: () => _showImageDialog(imageUrl),
                     child: ClipRRect(
                       borderRadius: BorderRadius.circular(8),
                       child: Stack(
                         children: [
                           Image.network(
                             imageUrl,
                             height: 100,
                             width: double.infinity,
                             fit: BoxFit.cover,
                             loadingBuilder: (context, child, loadingProgress) {
                               if (loadingProgress == null) return child;
                               return Container(
                                 height: 100,
                                 color: Colors.grey.shade100,
                                 child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                               );
                             },
                             errorBuilder: (context, error, stackTrace) {
                               return Container(
                                 height: 100,
                                 color: Colors.grey.shade200,
                                 child: const Icon(Icons.broken_image, color: Colors.grey),
                               );
                             },
                           ),
                           Positioned(
                             bottom: 4,
                             left: 4,
                             child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                               decoration: BoxDecoration(
                                 color: Colors.black.withOpacity(0.6),
                                 borderRadius: BorderRadius.circular(4),
                               ),
                               child: const Text('Plat', style: TextStyle(color: Colors.white, fontSize: 10)),
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                 ),
                 const SizedBox(width: 8),
                 // Face image (smaller, square)
                 Expanded(
                   flex: 2,
                   child: _buildFaceImage(faceImageUrl, faceDetected),
                 ),
               ],
             ),
             const SizedBox(height: 12),
          ],

          // Waktu (Abu-abu)
          Text(
            waktu,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500
            ),
          ),
          const SizedBox(height: 12),
          
          // Chip Lokasi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              lokasi,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds face image thumbnail with fallback placeholder
  Widget _buildFaceImage(String? url, bool detected) {
    // No face image available at all
    if (url == null || url.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, color: Colors.grey.shade400, size: 32),
            const SizedBox(height: 4),
            Text('Tidak ada\nfoto',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Face image available (either cropped face or full frame fallback)
    return GestureDetector(
      onTap: () => _showImageDialog(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Image.network(
              url,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 100,
                  color: Colors.grey.shade100,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 100,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),
            // Label: "Wajah" or "Full Frame"
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: detected 
                      ? Colors.green.withOpacity(0.8)
                      : Colors.orange.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      detected ? Icons.face : Icons.photo_camera,
                      color: Colors.white,
                      size: 10,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      detected ? 'Wajah' : 'Full',
                      style: const TextStyle(color: Colors.white, fontSize: 9),
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

  void _showImageDialog(String imageUrl) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.9),
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Get.back(),
                ),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: true,
    );
  }
}