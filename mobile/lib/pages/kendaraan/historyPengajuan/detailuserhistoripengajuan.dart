import 'package:flutter/material.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/models/pengajuan_plat_model.dart';
import 'package:mobile/utils/date_helper.dart';
import 'package:mobile/utils/ui_helpers.dart';
import 'package:mobile/utils/app_theme.dart';

/// Detail of one vehicle submission: plate, status badge, the status timeline
/// (diajukan -> status sekarang, with the admin feedback) and, for a rejected one, the way to
/// resubmit it. Every submission opens this page, whatever its status.
class DetailPengajuanPlat extends StatelessWidget {
  final PengajuanPlatModel pengajuan;

  const DetailPengajuanPlat({super.key, required this.pengajuan});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = pengajuan.getStatusColor();
    final List<PengajuanTimelineStep> timeline = pengajuan.getTimeline();

    return Scaffold(
      backgroundColor: const Color(0xFFFC5F57), // Warna header
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Anda
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Kembali',
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Pengajuan Pendaftaran Plat',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // Plat Nomor
                      Center(
                        child: Text(
                          pengajuan.platNomor,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (pengajuan.namaKendaraan.isNotEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              pengajuan.namaKendaraan,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Status Badge
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 8.0,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                pengajuan.getStatusIcon(),
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                pengajuan.getStatusText(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Riwayat status
                      const Text(
                        'Riwayat Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (int i = 0; i < timeline.length; i++)
                        _TimelineTile(
                          step: timeline[i],
                          isLast: i == timeline.length - 1,
                        ),
                      const SizedBox(height: 20),

                      if (pengajuan.statusPengajuan == 'DITOLAK')
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              // Navigate to resubmit page
                              Navigator.pushNamed(
                                context,
                                AppRoutes.resubmitKendaraan,
                                arguments: {'id_kendaraan': pengajuan.idKendaraan},
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              'AJUKAN ULANG',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
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
}

/// One row of the vertical status timeline: a dot (with the status icon) joined to the next
/// one by a line, the step title, its WIB time and the note (feedback).
class _TimelineTile extends StatelessWidget {
  final PengajuanTimelineStep step;
  final bool isLast;

  const _TimelineTile({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final DateTime? time = step.time;
    final String? note = step.note;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: step.color,
                  child: Icon(step.icon, size: 16, color: Colors.white),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: Colors.grey.shade300),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontWeight: step.isCurrent
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 15,
                      color: step.isCurrent ? step.color : Colors.black87,
                    ),
                  ),
                  if (time != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        formatWibDateTime(time),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  if (note != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: step.color, width: 1.5),
                      ),
                      child: Text(
                        note,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
