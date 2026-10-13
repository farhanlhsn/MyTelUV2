import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/auth_service.dart';
import '../../utils/error_helper.dart';
import '../common/error_retry_view.dart';

/// Push notification preference. The switch shows what the server has for the user
/// (`push_notifications_enabled` of `GET /auth/me`) and saves a change with
/// `PUT /auth/preferences`; when saving fails the switch goes back and an error is shown.
class NotificationPage extends StatefulWidget {
  /// The real [AuthService] unless a test replaces it.
  final AuthService? authService;

  const NotificationPage({super.key, this.authService});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late final AuthService _authService = widget.authService ?? AuthService();

  // The server default (column default true) until the profile says otherwise
  bool _isNotificationEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final Map<String, dynamic> result = await _authService.getMe();
      final Object? data = result['data'];
      final Object? enabled = data is Map ? data['push_notifications_enabled'] : null;
      if (!mounted) return;
      setState(() {
        _isNotificationEnabled = enabled is bool ? enabled : true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = ErrorHelper.parseError(e);
      });
    }
  }

  Future<void> _onChanged(bool value) async {
    if (_isSaving) return;
    final bool previous = _isNotificationEnabled;

    setState(() {
      _isNotificationEnabled = value;
      _isSaving = true;
    });

    try {
      await _authService.updatePushPreference(enabled: value);
      if (!mounted) return;
      _showSnackBar(
        value
            ? 'Notifikasi aktif - Anda akan menerima notifikasi'
            : 'Notifikasi non-aktif - Anda tidak akan menerima notifikasi',
      );
    } catch (e) {
      if (!mounted) return;
      // Not saved: the server still has the old value, so the switch must show it
      setState(() => _isNotificationEnabled = previous);
      _showSnackBar(
        'Gagal menyimpan pengaturan notifikasi. ${ErrorHelper.parseError(e)}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade600 : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Warna tema
    const Color primaryColor = Color(0xFFE63946);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Notifikasi",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),
      body: _buildBody(primaryColor),
    );
  }

  Widget _buildBody(Color primaryColor) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    final String? loadError = _loadError;
    if (loadError != null) {
      return ErrorRetryView(
        title: 'Gagal memuat pengaturan',
        message: loadError,
        onRetry: _loadPreference,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Preferensi",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 10),

          // --- KARTU SWITCH ON/OFF ---
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            // Material between the card and the tile: the tile paints its ink on it, not under the card
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                activeColor: primaryColor, // Warna merah saat ON
                title: const Text(
                  "Push Notifikasi",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  "Terima notifikasi di HP Anda",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: _isNotificationEnabled,
                // Locked while the change is being saved
                onChanged: _isSaving ? null : _onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
