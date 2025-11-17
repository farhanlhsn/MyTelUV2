import 'package:flutter/material.dart';
import 'models/pengajuan_plat_model.dart';

class PengajuanListPage extends StatefulWidget {
  const PengajuanListPage({super.key});

  @override
  State<PengajuanListPage> createState() => _PengajuanListPageState();
}

class _PengajuanListPageState extends State<PengajuanListPage> {
  // Dummy data untuk demo
  List<PengajuanPlatModel> pengajuanList = [
    PengajuanPlatModel(
      id: '1',
      namaPengaju: 'Fikri',
      nomorPlat: 'DD 0000 KE',
      status: 'pending',
      tanggalPengajuan: DateTime.now().subtract(const Duration(days: 1)),
    ),
    PengajuanPlatModel(
      id: '2',
      namaPengaju: 'Farhan',
      nomorPlat: 'DD 2222 KE',
      status: 'approved',
      tanggalPengajuan: DateTime.now().subtract(const Duration(days: 3)),
    ),
    PengajuanPlatModel(
      id: '3',
      namaPengaju: 'Mas amba',
      nomorPlat: 'DD 1111 AB',
      status: 'rejected',
      tanggalPengajuan: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  void _updateStatus(String id, String newStatus) {
    setState(() {
      final index = pengajuanList.indexWhere((item) => item.id == id);
      if (index != -1) {
        pengajuanList[index] = PengajuanPlatModel(
          id: pengajuanList[index].id,
          namaPengaju: pengajuanList[index].namaPengaju,
          nomorPlat: pengajuanList[index].nomorPlat,
          status: newStatus,
          tanggalPengajuan: pengajuanList[index].tanggalPengajuan,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus == 'approved'
              ? 'Pengajuan berhasil disetujui'
              : 'Pengajuan berhasil ditolak',
        ),
        backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showConfirmDialog(String id, String action) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            action == 'approved' ? 'Setujui Pengajuan?' : 'Tolak Pengajuan?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            action == 'approved'
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
                _updateStatus(id, action);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    action == 'approved' ? Colors.green : Colors.red,
              ),
              child: Text(action == 'approved' ? 'Setujui' : 'Tolak'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFC5F57);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          // Header
          Container(
            height: 150,
            decoration: const BoxDecoration(
              color: primaryColor,
            ),
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
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
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
              child: pengajuanList.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pengajuanList.length,
                      itemBuilder: (context, index) {
                        return _buildPengajuanCard(pengajuanList[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Belum ada pengajuan',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildPengajuanCard(PengajuanPlatModel pengajuan) {
  const Color primaryColor = Color(0xFFFC5F57);

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: primaryColor,
        width: 2,
      ),
    ),
    child: Row(
      children: [
        // Kolom Kiri: Nama, Plat, dan Status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama
              Text(
                pengajuan.namaPengaju,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),

              // Nomor Plat
              Text(
                pengajuan.nomorPlat,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              // Status Badge
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

        // Kolom Kanan: Tombol TOLAK dan TERIMA (Vertikal)
        Column(
          children: [
            // Tombol TOLAK
            Container(
              width: 90,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: pengajuan.status == 'pending'
                      ? primaryColor
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: TextButton(
                onPressed: pengajuan.status == 'pending'
                    ? () => _showConfirmDialog(pengajuan.id, 'rejected')
                    : null,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'TOLAK',
                  style: TextStyle(
                    color: pengajuan.status == 'pending'
                        ? primaryColor
                        : Colors.grey.shade400,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Tombol TERIMA
            Container(
              width: 90,
              height: 36,
              decoration: BoxDecoration(
                color: pengajuan.status == 'pending'
                    ? primaryColor
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextButton(
                onPressed: pengajuan.status == 'pending'
                    ? () => _showConfirmDialog(pengajuan.id, 'approved')
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