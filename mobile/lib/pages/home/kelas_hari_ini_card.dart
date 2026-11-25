import 'package:flutter/material.dart';

import '../../models/kelas_hari_ini.dart';
import '../../utils/attendance_helper.dart';
import '../../utils/kelas_helper.dart';
import '../../utils/app_theme.dart';

/// Card of one class in the "kelas hari ini" carousel of the home page. Tapping it (only while the
/// class has an active attendance session) calls [onTap].
class KelasHariIniCard extends StatelessWidget {
  final KelasHariIniModel kelas;
  final VoidCallback? onTap;

  const KelasHariIniCard({super.key, required this.kelas, this.onTap});

  static const Color _primaryRed = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final bool hasActiveAbsensi = kelas.hasActiveAbsensi;
    final bool requireFace = kelas.activeSesiAbsensi?.requireFace ?? false;

    final String title = kelasHariIniTitle(kelas);
    final String dosenName = kelas.dosen?.nama ?? '-';
    final String location = kelas.ruangan ?? 'Ruangan belum ditentukan';

    return GestureDetector(
      onTap: hasActiveAbsensi ? onTap : null,
      child: Card(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              bottom: -80,
              right: -80,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: _primaryRed.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Active absensi badge
            if (hasActiveAbsensi)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        requireFace ? Icons.face : Icons.location_on,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        attendanceBadgeLabel(requireFace),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Tap untuk absen →',
                          style: TextStyle(
                            color: _primaryRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.schedule, color: _primaryRed, size: 28),
              ),
            ),
            Padding(
              // keep the text clear of the schedule icon (the badge row already sits below it)
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                hasActiveAbsensi ? 20 : 72,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasActiveAbsensi) const SizedBox(height: 50),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: hasActiveAbsensi ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dosen: $dosenName',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          kelas.jadwal,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
