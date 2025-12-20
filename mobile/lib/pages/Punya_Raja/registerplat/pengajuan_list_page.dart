import 'package:flutter/material.dart';
import '../../../models/pengajuan_plat_model.dart';

class PengajuanListPage extends StatefulWidget {
  const PengajuanListPage({super.key});

  @override
  State<PengajuanListPage> createState() => _PengajuanListPageState();
}

class _PengajuanListPageState extends State<PengajuanListPage> {
  // Dummy data untuk demo - using updated model
  List<PengajuanPlatModel> pengajuanList = [
    PengajuanPlatModel(
      idKendaraan: 1,
      platNomor: 'DD 0000 KE',
      namaKendaraan: 'HONDA VARIO',
      statusPengajuan: 'MENUNGGU',
      feedback: null,
      fotoKendaraan: [],
      fotoSTNK: '',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    PengajuanPlatModel(
      idKendaraan: 2,
      platNomor: 'DD 2222 KE',
      namaKendaraan: 'HONDA BEAT',
      statusPengajuan: 'DISETUJUI',
      feedback: null,
      fotoKendaraan: [],
      fotoSTNK: '',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    PengajuanPlatModel(
      idKendaraan: 3,
      platNomor: 'DD 1111 AB',
      namaKendaraan: 'YAMAHA NMAX',
      statusPengajuan: 'DITOLAK',
      feedback: 'Foto STNK tidak jelas',
      fotoKendaraan: [],
      fotoSTNK: '',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  void _updateStatus(int idKendaraan, String newStatus) {
    setState(() {
      final index = pengajuanList.indexWhere(
        (item) => item.idKendaraan == idKendaraan,
      );
      if (index != -1) {
        pengajuanList[index] = PengajuanPlatModel(
          idKendaraan: pengajuanList[index].idKendaraan,
          namaKendaraan: pengajuanList[index].namaKendaraan,
          platNomor: pengajuanList[index].platNomor,
          statusPengajuan: newStatus,
          feedback: pengajuanList[index].feedback,
          fotoKendaraan: pengajuanList[index].fotoKendaraan,
          fotoSTNK: pengajuanList[index].fotoSTNK,
          createdAt: pengajuanList[index].createdAt,
          updatedAt: DateTime.now(),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus == 'DISETUJUI'
              ? 'Pengajuan berhasil disetujui'
              : 'Pengajuan berhasil ditolak',
        ),
        backgroundColor: newStatus == 'DISETUJUI' ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showConfirmDialog(int idKendaraan, String action) {
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
                _updateStatus(idKendaraan, action);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'DISETUJUI'
                    ? Colors.green
                    : Colors.red,
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
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildPengajuanCard(PengajuanPlatModel pengajuan) {
    const Color primaryColor = Color(0xFFE63946);
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
                // Nama Kendaraan
                Text(
                  pengajuan.namaKendaraan,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),

                // Nomor Plat
                Text(
                  pengajuan.platNomor,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
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
                    color: isPending ? primaryColor : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: TextButton(
                  onPressed: isPending
                      ? () =>
                            _showConfirmDialog(pengajuan.idKendaraan, 'DITOLAK')
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

              // Tombol TERIMA
              Container(
                width: 90,
                height: 36,
                decoration: BoxDecoration(
                  color: isPending ? primaryColor : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextButton(
                  onPressed: isPending
                      ? () => _showConfirmDialog(
                          pengajuan.idKendaraan,
                          'DISETUJUI',
                        )
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
