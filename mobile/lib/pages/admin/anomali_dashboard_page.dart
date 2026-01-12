import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/anomali_controller.dart';
import '../../models/anomali_model.dart';
import '../../services/akademik_service.dart';
import '../../services/dosen_service.dart';
import '../../models/kelas.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnomaliDashboardPage extends StatefulWidget {
  const AnomaliDashboardPage({super.key});

  @override
  State<AnomaliDashboardPage> createState() => _AnomaliDashboardPageState();
}

class _AnomaliDashboardPageState extends State<AnomaliDashboardPage> {
  final AnomaliController _anomaliController = Get.put(AnomaliController());
  final AkademikService _akademikService = AkademikService();
  final DosenService _dosenService = DosenService();

  static const Color primaryRed = Color(0xFFE63946);
  
  List<dynamic> _kelasList = []; // Can be KelasModel or Map<String, dynamic>
  dynamic _selectedKelas;
  String _selectedFilter = 'Semua';
  bool _isLoadingKelas = true;
  bool _isScanning = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRoleAndKelas();
  }

  Future<void> _loadUserRoleAndKelas() async {
    setState(() => _isLoadingKelas = true);
    try {
      // Get user role from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _userRole = prefs.getString('role');
      
      if (_userRole == 'DOSEN') {
        // DOSEN: Get kelas yang diampu
        final kelas = await _dosenService.getKelasDiampu();
        setState(() {
          _kelasList = kelas;
          _isLoadingKelas = false;
        });
      } else {
        // ADMIN: Get all kelas
        final kelas = await _akademikService.getAllKelas(limit: 100);
        setState(() {
          _kelasList = kelas;
          _isLoadingKelas = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingKelas = false);
      Get.snackbar('Error', 'Gagal memuat daftar kelas: $e');
    }
  }

  Future<void> _scanKelas(int idKelas) async {
    setState(() => _isScanning = true);
    
    // Langsung await ke analyzeKelas (sekarang return Future)
    await _anomaliController.analyzeKelas(idKelas);
    
    setState(() => _isScanning = false);
  }

  Future<void> _scanAllKelas() async {
    setState(() => _isScanning = true);
    _anomaliController.anomaliList.clear();
    
    for (final kelas in _kelasList) {
      // Handle both KelasModel and Map<String, dynamic>
      final int idKelas = kelas is KelasModel 
          ? kelas.idKelas 
          : (kelas as Map<String, dynamic>)['id_kelas'] as int;
      _anomaliController.analyzeKelas(idKelas);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    setState(() => _isScanning = false);
    Get.snackbar('Sukses', 'Scan selesai untuk ${_kelasList.length} kelas');
  }

  List<AnomaliModel> get _filteredAnomalies {
    if (_selectedFilter == 'Semua') {
      return _anomaliController.anomaliList;
    } else if (_selectedFilter == 'Jarang Hadir') {
      return _anomaliController.anomaliList
          .where((a) => a.typeAnomali == 'TIDAK_HADIR_BERULANG')
          .toList();
    } else {
      return _anomaliController.anomaliList
          .where((a) => a.typeAnomali == 'KEHADIRAN_GANDA')
          .toList();
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
            _buildHeader(),
            
            // Content
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
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Kelas Dropdown
                    _buildKelasDropdown(),
                    
                    const SizedBox(height: 16),
                    
                    // Filter Chips
                    _buildFilterChips(),
                    
                    const SizedBox(height: 16),
                    
                    // Anomaly List
                    Expanded(
                      child: _buildAnomalyList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 20),
      child: Column(
        children: [
          // Title Row
          Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                "Deteksi Anomali",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Refresh Button
              GestureDetector(
                onTap: _selectedKelas != null 
                    ? () => _scanKelas(_selectedKelas!.idKelas)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Obx(() => Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_anomaliController.anomaliList.length} Anomali Terdeteksi',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lihat detail dan ambil tindakan',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Scan All Button
                GestureDetector(
                  onTap: _isScanning ? null : _scanAllKelas,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isScanning)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryRed),
                            ),
                          )
                        else
                          const Icon(Icons.sync, color: primaryRed, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _isScanning ? 'Scanning...' : 'Scan Ulang',
                          style: const TextStyle(
                            color: primaryRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildKelasDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: _isLoadingKelas
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : _kelasList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Tidak ada kelas tersedia', 
                      style: TextStyle(color: Colors.grey)),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<dynamic>(
                      isExpanded: true,
                      hint: const Text('Pilih Kelas untuk Scan'),
                      value: _selectedKelas,
                      icon: const Icon(Icons.keyboard_arrow_down, color: primaryRed),
                      items: _kelasList.map((kelas) {
                        // Handle both KelasModel and Map<String, dynamic>
                        String namaKelas;
                        String namaMk;
                        
                        if (kelas is KelasModel) {
                          namaKelas = kelas.namaKelas;
                          namaMk = kelas.matakuliah?.namaMatakuliah ?? '';
                        } else {
                          final map = kelas as Map<String, dynamic>;
                          namaKelas = map['nama_kelas'] ?? '';
                          final mk = map['matakuliah'] as Map<String, dynamic>?;
                          namaMk = mk?['nama_matakuliah'] ?? '';
                        }
                        
                        return DropdownMenuItem<dynamic>(
                          value: kelas,
                          child: Text(
                            '$namaKelas - $namaMk',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (dynamic kelas) {
                        setState(() => _selectedKelas = kelas);
                        if (kelas != null) {
                          // Get idKelas from either type
                          final int idKelas = kelas is KelasModel 
                              ? kelas.idKelas 
                              : (kelas as Map<String, dynamic>)['id_kelas'] as int;
                          _scanKelas(idKelas);
                        }
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Semua', 'Jarang Hadir', 'Kehadiran Ganda'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedFilter = filter);
              },
              selectedColor: primaryRed.withOpacity(0.2),
              checkmarkColor: primaryRed,
              labelStyle: TextStyle(
                color: isSelected ? primaryRed : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? primaryRed : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnomalyList() {
    return Obx(() {
      if (_anomaliController.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: primaryRed),
        );
      }

      final anomalies = _filteredAnomalies;

      if (anomalies.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedKelas == null
                    ? Icons.touch_app
                    : Icons.check_circle_outline,
                size: 64,
                color: _selectedKelas == null ? Colors.grey.shade400 : Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                _selectedKelas == null
                    ? 'Pilih kelas untuk mulai scan'
                    : 'Tidak ada anomali terdeteksi',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              if (_selectedKelas != null) ...[
                const SizedBox(height: 8),
                Text(
                  _anomaliController.message.value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          if (_selectedKelas != null) {
            await _scanKelas(_selectedKelas!.idKelas);
          }
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: anomalies.length,
          itemBuilder: (context, index) {
            return _buildAnomalyCard(anomalies[index]);
          },
        ),
      );
    });
  }

  Widget _buildAnomalyCard(AnomaliModel anomali) {
    final bool isSevere = anomali.typeAnomali == 'TIDAK_HADIR_BERULANG';
    final MaterialColor cardColor = isSevere ? Colors.red : Colors.orange;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardColor[400]!,
            cardColor[600]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showAnomalyDetail(anomali),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User ID: ${anomali.idUser}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        anomali.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Badge & Arrow
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isSevere ? 'Jarang Hadir' : 'Ganda',
                        style: TextStyle(
                          color: cardColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAnomalyDetail(AnomaliModel anomali) {
    final bool isSevere = anomali.typeAnomali == 'TIDAK_HADIR_BERULANG';
    final Color accentColor = isSevere ? Colors.red : Colors.orange;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isSevere ? Icons.warning_amber_rounded : Icons.copy_all,
                color: accentColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            
            // Title
            Text(
              isSevere ? 'Kehadiran Rendah' : 'Kehadiran Ganda',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // User ID
            Text(
              'User ID: ${anomali.idUser}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            
            // Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deskripsi:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anomali.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Tutup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Get.snackbar(
                        'Info',
                        'Fitur kirim peringatan akan segera tersedia',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Kirim Peringatan',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
