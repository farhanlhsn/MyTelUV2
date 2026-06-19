import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/anomali_controller.dart';

class AdminAnomalyConfigPage extends StatefulWidget {
  const AdminAnomalyConfigPage({super.key});

  @override
  State<AdminAnomalyConfigPage> createState() => _AdminAnomalyConfigPageState();
}

class _AdminAnomalyConfigPageState extends State<AdminAnomalyConfigPage> {
  final AnomaliController _controller = Get.put(AnomaliController());
  
  static const Color primaryRed = Color(0xFFE63946);
  static const Color darkBlue = Color(0xFF1D3557);
  static const Color accentGreen = Color(0xFF2A9D8F);

  double _localJarangHadir = 50.0;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isInitializing = true);
    await _controller.getAnomalySettings();
    setState(() {
      _localJarangHadir = _controller.thresholdJarangHadir.value.toDouble();
      _isInitializing = false;
    });
  }

  Future<void> _saveSettings() async {
    final bool success = await _controller.updateAnomalySettings(
      _localJarangHadir.round(),
      _controller.thresholdKehadiranGanda.value,
    );
    if (success) {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryRed,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: () => Get.back(),
                  ),
                  const Text(
                    "Pengaturan Anomali",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content Card
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
                child: _isInitializing
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryRed),
                      )
                    : Obx(() {
                        final bool isLoading = _controller.isLoading.value;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Info Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: darkBlue.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: darkBlue.withOpacity(0.1)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      color: darkBlue,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Konfigurasi batas threshold (persentase) ini digunakan oleh sistem untuk mendeteksi anomali presensi mahasiswa secara otomatis.",
                                        style: TextStyle(
                                          color: darkBlue.withOpacity(0.8),
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Card 1: Jarang Hadir
                              _buildSettingCard(
                                title: "Batas Kehadiran Rendah (Jarang Hadir)",
                                subtitle: "Tandai mahasiswa sebagai 'Jarang Hadir' jika kehadiran mereka di bawah batas persentase ini.",
                                value: _localJarangHadir,
                                min: 10.0,
                                max: 90.0,
                                icon: Icons.warning_amber_rounded,
                                iconColor: primaryRed,
                                onChanged: (val) {
                                  setState(() => _localJarangHadir = val);
                                },
                              ),


                              const SizedBox(height: 40),

                              // Save Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _saveSettings,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryRed,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          "Simpan Konfigurasi",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required IconData icon,
    required Color iconColor,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Batas Threshold:",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                "${value.round()}%",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: iconColor,
              inactiveTrackColor: iconColor.withOpacity(0.15),
              thumbColor: iconColor,
              overlayColor: iconColor.withOpacity(0.1),
              valueIndicatorColor: iconColor,
              valueIndicatorTextStyle: const TextStyle(color: Colors.white),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).round(),
              label: "${value.round()}%",
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
