import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/akademik_service.dart';
import '../../controllers/home_controller.dart';
import '../../app/routes.dart';
import '../../utils/error_helper.dart';

class JadwalMingguanPage extends StatefulWidget {
  const JadwalMingguanPage({super.key});

  @override
  State<JadwalMingguanPage> createState() => _JadwalMingguanPageState();
}

class _JadwalMingguanPageState extends State<JadwalMingguanPage> with SingleTickerProviderStateMixin {
  final AkademikService _akademikService = AkademikService();
  late TabController _tabController;
  
  final List<String> _dayOrder = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  final List<String> _shortDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  
  bool _isLoading = true;
  Map<String, List<dynamic>> _jadwalByDay = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday - 1;
    _tabController = TabController(length: 7, vsync: this, initialIndex: today.clamp(0, 6));
    _loadJadwal();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadJadwal() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final jadwal = await _akademikService.getJadwalMingguan();
      setState(() {
        _jadwalByDay = jadwal;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
        title: const Text('Jadwal Mingguan'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: _shortDays.map((day) => Tab(text: day)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadJadwal,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: _dayOrder.map((day) => _buildDaySchedule(day)).toList(),
                ),
    );
  }

  Widget _buildDaySchedule(String dayName) {
    final classes = _jadwalByDay[dayName] ?? [];

    if (classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada kelas di hari $dayName',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJadwal,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: classes.length,
        itemBuilder: (context, index) {
          return _buildClassCard(classes[index]);
        },
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> kelas) {
    final matakuliah = kelas['matakuliah'] as Map<String, dynamic>?;
    final dosen = kelas['dosen'] as Map<String, dynamic>?;
    final override = kelas['override'] as Map<String, dynamic>?;
    
    // Check if user is Dosen
    bool isDosen = false;
    try {
       final user = Get.find<HomeController>().currentUser.value;
       isDosen = user?.role == 'DOSEN';
    } catch (_) {}

    Color cardColor = Colors.white;
    Color statusColor = const Color(0xFFE63946);
    String statusText = '';

    if (override != null) {
      if (override['status'] == 'LIBUR') {
        cardColor = Colors.red.shade50;
        statusText = 'DILIBURKAN';
      } else if (override['status'] == 'GANTI_JADWAL') {
        cardColor = Colors.orange.shade50;
        statusColor = Colors.orange.shade800;
        statusText = 'JADWAL PENGGANTI';
      }
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (isDosen) {
            _showDosenOptions(kelas);
          } else {
             final message = override != null 
                ? 'Info: ${override['alasan'] ?? 'Ada perubahan jadwal'}'
                : 'Detail: ${matakuliah?['nama_matakuliah']}';
                
            ErrorHelper.showInfo(message);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (statusText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (override != null && override['alasan'] != null)
                        Expanded(
                          child: Text(
                            ' - ${override['alasan']}',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                children: [
                  // Time column
                  Container(
                    width: 70,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.schedule, size: 20, color: statusColor),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(kelas['jam_mulai']),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: statusColor,
                          ),
                        ),
                        Text('-', style: TextStyle(color: statusColor, fontSize: 10)),
                        Text(
                          _formatTime(kelas['jam_berakhir']),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Class info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          matakuliah?['nama_matakuliah'] ?? kelas['nama_kelas'] ?? 'Kelas',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: override?['status'] == 'LIBUR' 
                                ? TextDecoration.lineThrough 
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (matakuliah != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              matakuliah['kode_matakuliah'] ?? '',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (dosen != null)
                          Row(
                            children: [
                              Icon(Icons.person, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  dosen['nama'] ?? '',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        if (kelas['ruangan'] != null)
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  override?['ruangan_ganti'] ?? kelas['ruangan'],
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: Colors.grey[600],
                                    fontWeight: override?['ruangan_ganti'] != null 
                                        ? FontWeight.bold 
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isDosen) ...[
                const Divider(),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _showDosenOptions(kelas),
                    icon: Icon(Icons.edit_calendar, color: statusColor, size: 16),
                    label: Text(
                      'Atur Jadwal / Liburkan',
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDosenOptions(Map<String, dynamic> kelas) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Opsi Dosen: ${kelas['nama_kelas']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Color(0xFFE63946)),
              title: const Text('Buat Jadwal Pengganti / Libur'),
              subtitle: const Text('Ubah jadwal untuk minggu ini'),
              onTap: () async {
                Get.back();
                final result = await Get.toNamed(
                  AppRoutes.formJadwalPengganti, // Ensure this route is defined
                  arguments: {
                    'id_kelas': kelas['id_kelas'],
                    'nama_kelas': kelas['nama_kelas'],
                  },
                );
                if (result == true) {
                  _loadJadwal(); // Refresh list if created
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.blue),
              title: const Text('Lihat Riwayat Perubahan'),
              onTap: () {
                Get.back();
                // TODO: Navigate to history list if needed
                ErrorHelper.showInfo('Fitur riwayat belum tersedia');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic time) {
    if (time == null) return '--:--';
    final timeStr = time.toString();
    if (timeStr.length >= 5) {
      return timeStr.substring(0, 5);
    }
    return timeStr;
  }
}
