import 'package:flutter/material.dart';
import '../models/pengajuan_plat_model.dart';

/// Status colours: clearly distinct (amber / red / green) and never the only cue, each also has
/// an icon and a label.
const Color _menunggu = Color(0xFFF59E0B);
const Color _ditolak = Color(0xFFDC2626);
const Color _disetujui = Color(0xFF16A34A);

const String _deleteRequestPrefix = 'DELETE_REQUEST:';

/// One point on the status timeline of a vehicle submission.
class PengajuanTimelineStep {
  final String title;

  /// When it happened; null when the server did not record a time for this step.
  final DateTime? time;

  /// Admin feedback or the reason of a delete request.
  final String? note;
  final IconData icon;
  final Color color;

  /// The step that describes the submission right now.
  final bool isCurrent;

  const PengajuanTimelineStep({
    required this.title,
    required this.icon,
    required this.color,
    this.time,
    this.note,
    this.isCurrent = false,
  });
}

extension PengajuanStatusHelper on PengajuanPlatModel {
  // Helper untuk mendapatkan warna status
  Color getStatusColor() {
    switch (statusPengajuan) {
      case 'DISETUJUI':
        return _disetujui; // Hijau
      case 'DITOLAK':
        return _ditolak; // Merah
      case 'MENUNGGU':
      default:
        return _menunggu; // Amber
    }
  }

  // Helper untuk mendapatkan ikon status
  IconData getStatusIcon() {
    switch (statusPengajuan) {
      case 'DISETUJUI':
        return Icons.check_circle;
      case 'DITOLAK':
        return Icons.cancel;
      case 'MENUNGGU':
      default:
        return Icons.hourglass_top;
    }
  }

  // Helper untuk mendapatkan text status
  String getStatusText() {
    switch (statusPengajuan) {
      case 'DISETUJUI':
        return 'Disetujui';
      case 'DITOLAK':
        return 'Ditolak';
      case 'MENUNGGU':
      default:
        return 'Menunggu';
    }
  }

  /// Riwayat status: diajukan -> status sekarang (+ feedback admin). A delete request on an
  /// approved vehicle is stored as feedback `DELETE_REQUEST: <alasan>`; it is shown as its own
  /// step instead of leaking the raw prefix.
  List<PengajuanTimelineStep> getTimeline() {
    final String feedbackText = feedback?.trim() ?? '';
    final bool hasFeedback = feedbackText.isNotEmpty;
    final bool isDeleteRequest = feedbackText.startsWith(_deleteRequestPrefix);

    final PengajuanTimelineStep diajukan = PengajuanTimelineStep(
      title: 'Diajukan',
      icon: Icons.send,
      color: Colors.blueGrey,
      time: createdAt,
    );

    if (isDeleteRequest) {
      final String reason = feedbackText
          .substring(_deleteRequestPrefix.length)
          .trim();
      return <PengajuanTimelineStep>[
        diajukan,
        PengajuanTimelineStep(
          title: getStatusText(),
          icon: getStatusIcon(),
          color: getStatusColor(),
        ),
        PengajuanTimelineStep(
          title: 'Permintaan hapus diajukan',
          icon: Icons.delete_outline,
          color: _ditolak,
          time: updatedAt,
          note: reason.isEmpty ? null : 'Alasan: $reason',
          isCurrent: true,
        ),
      ];
    }

    return <PengajuanTimelineStep>[
      diajukan,
      PengajuanTimelineStep(
        title: getStatusText(),
        icon: getStatusIcon(),
        color: getStatusColor(),
        // A pending submission has not had a decision yet, so there is no decision time.
        time: statusPengajuan == 'DISETUJUI' || statusPengajuan == 'DITOLAK'
            ? updatedAt
            : null,
        note: hasFeedback ? feedbackText : null,
        isCurrent: true,
      ),
    ];
  }
}
