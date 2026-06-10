import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../models/pengajuan_plat_model.dart';
import '../services/kendaraan_service.dart';
import '../utils/error_helper.dart';

class PengajuanListController extends GetxController {
  final PagingController<int, PengajuanPlatModel> pagingController =
      PagingController(firstPageKey: 1);

  static const int _pageSize = 10;

  @override
  void onInit() {
    super.onInit();
    pagingController.addPageRequestListener((pageKey) {
      fetchPage(pageKey);
    });
  }

  Future<void> fetchPage(int pageKey) async {
    try {
      final response = await KendaraanService.getAllUnverifiedKendaraan(
        page: pageKey,
        limit: _pageSize,
      );

      final List<dynamic> rawItems = response['items'] as List<dynamic>? ?? [];
      final List<PengajuanPlatModel> newItems = rawItems
          .map((e) => e as PengajuanPlatModel)
          .toList();

      final int totalPages = response['totalPages'] as int? ?? 1;
      
      final isLastPage = pageKey >= totalPages || newItems.length < _pageSize;

      if (isLastPage) {
        pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      pagingController.error = error;
    }
  }

  Future<void> updateStatus(PengajuanPlatModel pengajuan, String action) async {
    try {
      bool success = false;
      
      if (action == 'DISETUJUI') {
        success = await KendaraanService.verifyKendaraan(
          idKendaraan: pengajuan.idKendaraan,
          idUser: pengajuan.idUser ?? 0,
        );
      } else {
        // Show feedback dialog for rejection
        final feedback = await showFeedbackDialog();
        if (feedback == null || feedback.isEmpty) return;
        
        success = await KendaraanService.rejectKendaraan(
          idKendaraan: pengajuan.idKendaraan,
          idUser: pengajuan.idUser ?? 0,
          feedback: feedback,
        );
      }

      if (success) {
        ErrorHelper.showSuccess(
          action == 'DISETUJUI'
              ? 'Pengajuan berhasil disetujui'
              : 'Pengajuan berhasil ditolak',
        );
        refreshData(); // Refresh list
      }
    } catch (e) {
      ErrorHelper.showError(e, title: 'Gagal Update Status');
    }
  }

  void refreshData() {
    pagingController.refresh();
  }

  Future<String?> showFeedbackDialog() async {
    final TextEditingController feedbackController = TextEditingController();
    
    return Get.dialog<String>(
      AlertDialog(
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
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (feedbackController.text.trim().isNotEmpty) {
                Get.back(result: feedbackController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  void showConfirmDialog(PengajuanPlatModel pengajuan, String action) {
    Get.dialog(
      AlertDialog(
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
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              updateStatus(pengajuan, action);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'DISETUJUI' ? Colors.green : const Color(0xFFE63946),
              foregroundColor: Colors.white,
            ),
            child: Text(action == 'DISETUJUI' ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    pagingController.dispose();
    super.onClose();
  }
}
