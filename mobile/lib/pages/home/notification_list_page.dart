import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/notification_controller.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  final NotificationController _controller = Get.find<NotificationController>();
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _controller.markAllAsRead();
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
    const Color primaryColor = Color(0xFFE63946);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          // Popup Menu Filter Dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 26),
            tooltip: 'Filter Kategori',
            onSelected: (String value) {
              setState(() {
                _selectedCategory = value;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'Semua',
                child: Row(
                  children: [
                    Icon(Icons.notifications_none_rounded, color: _selectedCategory == 'Semua' ? primaryColor : Colors.grey),
                    const SizedBox(width: 12),
                    Text('Semua', style: TextStyle(color: _selectedCategory == 'Semua' ? primaryColor : Colors.black87, fontWeight: _selectedCategory == 'Semua' ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'Akademik',
                child: Row(
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, color: _selectedCategory == 'Akademik' ? primaryColor : Colors.grey),
                    const SizedBox(width: 12),
                    Text('Akademik & Absensi', style: TextStyle(color: _selectedCategory == 'Akademik' ? primaryColor : Colors.black87, fontWeight: _selectedCategory == 'Akademik' ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'Kendaraan',
                child: Row(
                  children: [
                    Icon(Icons.directions_car_outlined, color: _selectedCategory == 'Kendaraan' ? primaryColor : Colors.grey),
                    const SizedBox(width: 12),
                    Text('Kendaraan & Parkir', style: TextStyle(color: _selectedCategory == 'Kendaraan' ? primaryColor : Colors.black87, fontWeight: _selectedCategory == 'Kendaraan' ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'Sosial',
                child: Row(
                  children: [
                    Icon(Icons.favorite_border_rounded, color: _selectedCategory == 'Sosial' ? primaryColor : Colors.grey),
                    const SizedBox(width: 12),
                    Text('Sosial', style: TextStyle(color: _selectedCategory == 'Sosial' ? primaryColor : Colors.black87, fontWeight: _selectedCategory == 'Sosial' ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
          Obx(() {
            if (_controller.notifications.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white, size: 26),
              tooltip: 'Hapus Semua',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Hapus Semua Notifikasi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: const Text('Apakah Anda yakin ingin menghapus semua histori notifikasi Anda? Action ini tidak dapat diurungkan.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _controller.clearAll();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('HAPUS', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
      body: Column(
        children: [
          _buildActiveFilterBanner(),
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value && _controller.notifications.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              final allNotifs = _controller.notifications;

              // Filter list based on selected category tag
              List<Map<String, dynamic>> filteredList;
              if (_selectedCategory == 'Akademik') {
                filteredList = allNotifs
                    .where((n) => n['type'] == 'ABSENSI_NOTIFICATION')
                    .toList();
              } else if (_selectedCategory == 'Kendaraan') {
                filteredList = allNotifs
                    .where((n) {
                      final String type = n['type'] ?? '';
                      return type == 'PARKING_NOTIFICATION' || type.startsWith('KENDARAAN_');
                    })
                    .toList();
              } else if (_selectedCategory == 'Sosial') {
                filteredList = allNotifs
                    .where((n) => n['type'] == 'SOCIAL_NOTIFICATION')
                    .toList();
              } else {
                filteredList = allNotifs;
              }

              return _buildNotificationList(filteredList);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterBanner() {
    if (_selectedCategory == 'Semua') return const SizedBox.shrink();

    String label = '';
    if (_selectedCategory == 'Akademik') label = 'Akademik & Absensi';
    if (_selectedCategory == 'Kendaraan') label = 'Kendaraan & Parkir';
    if (_selectedCategory == 'Sosial') label = 'Sosial';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.orange.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list_alt, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Filter: $label',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = 'Semua';
              });
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 72,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Belum Ada Notifikasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Notifikasi baru yang Anda terima akan muncul di sini sesuai kategorinya.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _controller.loadNotifications(),
      color: const Color(0xFFE63946),
      child: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final notif = list[index];
          final keyString = notif['id'] ?? notif['timestamp'] ?? index.toString();
          
          return Dismissible(
            key: Key(keyString),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Hapus',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.delete_outline, color: Colors.white, size: 28),
                ],
              ),
            ),
            onDismissed: (direction) {
              _controller.deleteNotification(notif);
            },
            child: _buildNotificationCard(notif),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final String title = notif['title'] ?? 'Notifikasi';
    final String body = notif['body'] ?? '';
    final String date = notif['timestamp'] ?? DateTime.now().toIso8601String();
    final String type = notif['type'] ?? 'general';

    Color themeColor;
    IconData iconData;

    if (type == 'ABSENSI_NOTIFICATION') {
      themeColor = const Color(0xFF009688); // Teal
      iconData = Icons.assignment_turned_in_rounded;
    } else if (type == 'PARKING_NOTIFICATION') {
      themeColor = const Color(0xFF2196F3); // Blue
      iconData = Icons.local_parking_rounded;
    } else if (type.startsWith('KENDARAAN_APPROVED') || type == 'KENDARAAN_DELETED') {
      themeColor = const Color(0xFF4CAF50); // Green
      iconData = Icons.check_circle_rounded;
    } else if (type.startsWith('KENDARAAN_REJECTED') || type == 'KENDARAAN_DELETE_REJECTED') {
      themeColor = const Color(0xFFF44336); // Red
      iconData = Icons.cancel_rounded;
    } else if (type == 'SOCIAL_NOTIFICATION') {
      themeColor = const Color(0xFFE91E63); // Pink
      iconData = title.toLowerCase().contains('menyukai') || title.toLowerCase().contains('like')
          ? Icons.favorite_rounded
          : Icons.comment_rounded;
    } else {
      themeColor = const Color(0xFF607D8B); // Blue Grey
      iconData = Icons.notifications_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeColor.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Styled Icon Badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: themeColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Content Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(date),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
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
