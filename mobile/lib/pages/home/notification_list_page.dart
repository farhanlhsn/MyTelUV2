import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../utils/error_helper.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notificationsString = prefs.getString('local_notifications');
    
    if (notificationsString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(notificationsString);
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(decoded).reversed.toList();
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_notifications');
    setState(() {
      _notifications = [];
    });
    ErrorHelper.showSuccess('Semua notifikasi dihapus');
  }

  String _formatDate(String isoString) {
    try {
      final DateTime date = DateTime.parse(isoString);
      final DateTime now = DateTime.now();
      final Duration diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return 'Baru saja';
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes}m lalu';
      } else if (diff.inDays < 1) {
        return DateFormat('HH:mm').format(date);
      } else if (diff.inDays < 7) {
        return DateFormat('EEEE, HH:mm').format(date);
      } else {
        return DateFormat('dd MMM yyyy').format(date);
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Hapus Semua'),
                    content: const Text('Yakin ingin menghapus semua notifikasi?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearAllNotifications();
                        },
                        child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_off_outlined,
                            size: 60, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum ada notifikasi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final String title = notif['title'] ?? 'Notifikasi';
                    final String body = notif['body'] ?? '';
                    final String date = notif['timestamp'] ?? DateTime.now().toIso8601String();
                    final String type = notif['type'] ?? 'info';

                    Color iconColor = Colors.blue;
                    IconData iconData = Icons.notifications;

                    if (type == 'PARKING_NOTIFICATION') {
                      iconColor = Colors.orange;
                      iconData = Icons.local_parking;
                    } else if (title.toLowerCase().contains('berhasil')) {
                      iconColor = Colors.green;
                      iconData = Icons.check_circle;
                    } else if (title.toLowerCase().contains('gagal') ||
                        title.toLowerCase().contains('error')) {
                      iconColor = Colors.red;
                      iconData = Icons.error;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(iconData, color: iconColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatDate(date),
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  body,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
