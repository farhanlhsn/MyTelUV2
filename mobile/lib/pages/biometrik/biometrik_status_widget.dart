import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'biometrik_verification_page.dart';

class BiometrikStatusWidget extends StatelessWidget {
  /// Whether biometric is registered for current user
  final bool isRegistered;
  
  /// Whether to show action button
  final bool showAction;

  const BiometrikStatusWidget({
    super.key,
    this.isRegistered = false,
    this.showAction = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFFE63946);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryRed.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isRegistered
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isRegistered ? Icons.face_retouching_natural : Icons.face_retouching_off,
              color: isRegistered ? Colors.green : Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Biometrik',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isRegistered
                      ? 'Wajah sudah terdaftar'
                      : 'Wajah belum terdaftar',
                  style: TextStyle(
                    fontSize: 12,
                    color: isRegistered ? Colors.green.shade600 : Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Action button
          if (showAction)
            GestureDetector(
              onTap: () {
                Get.to(() => const BiometrikVerificationPage());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isRegistered ? 'Verifikasi' : 'Daftar',
                  style: TextStyle(
                    color: primaryRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Card for absensi with biometric verification button
class AbsensiBiometrikCard extends StatelessWidget {
  final String kelasName;
  final String jadwal;
  final bool isVerified;
  final VoidCallback onVerifyTap;
  final VoidCallback? onCardTap;

  const AbsensiBiometrikCard({
    super.key,
    required this.kelasName,
    required this.jadwal,
    this.isVerified = false,
    required this.onVerifyTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFFE63946);

    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryRed.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kelasName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        jadwal,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Verification status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVerified ? Icons.check_circle : Icons.pending,
                        size: 14,
                        color: isVerified ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVerified ? 'Hadir' : 'Pending',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isVerified ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Verify button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isVerified ? null : onVerifyTap,
                icon: Icon(
                  Icons.face_retouching_natural,
                  size: 18,
                  color: isVerified ? Colors.grey : Colors.white,
                ),
                label: Text(
                  isVerified ? 'Sudah Verifikasi' : 'Verifikasi Wajah',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isVerified ? Colors.grey : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isVerified ? Colors.grey.shade200 : primaryRed,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
