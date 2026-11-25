import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/biometrik_status.dart';
import '../../services/biometrik_service.dart';
import '../../utils/date_helper.dart';
import '../../utils/error_helper.dart';
import '../common/error_retry_view.dart';
import 'biometrik_status_widget.dart';
import '../../utils/app_theme.dart';

/// What the student's "Biometrik" menu item opens: whether a face is enrolled for the account
/// (GET /biometrik/status). Face attendance itself starts from a class with an open session (home
/// card or absensi list), so there is nothing to verify from here.
class BiometrikStatusPage extends StatefulWidget {
  /// For tests; defaults to the app's [BiometrikService].
  final BiometrikService? service;

  const BiometrikStatusPage({super.key, this.service});

  @override
  State<BiometrikStatusPage> createState() => _BiometrikStatusPageState();
}

class _BiometrikStatusPageState extends State<BiometrikStatusPage> {
  static const Color _primaryRed = AppColors.primary;

  late final BiometrikService _service = widget.service ?? BiometrikService();

  bool _isLoading = true;
  String? _errorMessage;
  BiometrikStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    // Clear the previous error first, otherwise a successful retry would still show it
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await _service.getStatusBiometrikSaya();
      if (!mounted) return;
      setState(() {
        _status = status;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorHelper.parseError(e);
        _isLoading = false;
      });
    }
  }

  /// Date of the last update in WIB (UTC+7), as the rest of the app's business dates.
  String _updatedLabel(DateTime updatedUtc) {
    return 'Terakhir diperbarui: ${formatTanggalSingkat(updatedUtc)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryRed,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Kembali',
                    icon: const Icon(appBackIcon, color: Colors.white, size: 20),
                    onPressed: () => Get.back(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Biometrik',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
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
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return ErrorRetryView(
        title: 'Gagal memuat status biometrik',
        message: errorMessage,
        onRetry: _loadStatus,
      );
    }

    // While loading the status is unknown: the widget then says "Memeriksa status…"
    final status = _isLoading ? null : _status;
    final updated = status?.diperbarui;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        BiometrikStatusWidget(
          isRegistered: status?.terdaftar,
          showAction: false,
        ),
        if (_isLoading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (status != null && status.terdaftar && updated != null) ...[
          const SizedBox(height: 12),
          Text(
            _updatedLabel(updated),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
        if (status != null && !status.terdaftar) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hubungi admin untuk pendaftaran wajah',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Data wajah didaftarkan oleh admin kampus. Absensi wajah dimulai dari '
          'kartu kelas di beranda atau dari daftar absensi saat sesi absensi '
          'dibuka.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
