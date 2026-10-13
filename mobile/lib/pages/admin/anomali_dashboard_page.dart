import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/anomali_controller.dart';
import '../../models/anomali_model.dart';
import '../../services/akademik_service.dart';
import '../../services/dosen_service.dart';
import '../../models/kelas.dart';
import '../../utils/anomali_helper.dart';
import '../../utils/error_helper.dart';
import '../../utils/kelas_helper.dart';
import '../common/error_retry_view.dart';
import '../../app/routes.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../app/auth_middleware.dart';
import '../../utils/app_theme.dart';

class AnomaliDashboardPage extends StatefulWidget {
  const AnomaliDashboardPage({super.key});

  @override
  State<AnomaliDashboardPage> createState() => _AnomaliDashboardPageState();
}

class _AnomaliDashboardPageState extends State<AnomaliDashboardPage> {
  final AnomaliController _anomaliController = Get.put(AnomaliController());
  final AkademikService _akademikService = AkademikService();
  final DosenService _dosenService = DosenService();

  static const Color primaryRed = AppColors.primary;
  
  List<dynamic> _kelasList = []; // Can be KelasModel or Map<String, dynamic>
  dynamic _selectedKelas;
  bool _isLoadingKelas = true;
  bool _isScanning = false;
  bool _lastScanWasAll = false; // what "Coba Lagi" repeats after a failed scan
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRoleAndKelas();
  }

  Future<void> _loadUserRoleAndKelas() async {
    setState(() => _isLoadingKelas = true);
    try {
      // Get user role from AuthMiddleware cache or FlutterSecureStorage
      const storage = FlutterSecureStorage();
      _userRole = AuthMiddleware.cachedRole ?? await storage.read(key: 'role');
      
      if (_userRole == 'DOSEN') {
        // DOSEN: Get kelas yang diampu
        final kelas = await _dosenService.getKelasDiampu();
        if (!mounted) return;
        setState(() {
          _kelasList = kelas;
          _isLoadingKelas = false;
        });
      } else {
        // ADMIN: Get all kelas
        final kelas = await _akademikService.getAllKelas(limit: 100);
        if (!mounted) return;
        setState(() {
          _kelasList = kelas;
          _isLoadingKelas = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingKelas = false);
      ErrorHelper.showToast('Error', 'Gagal memuat daftar kelas: ${ErrorHelper.parseError(e)}');
    }
  }

  Future<void> _scanKelas(int idKelas) async {
    _lastScanWasAll = false;
    setState(() => _isScanning = true);

    // Langsung await ke analyzeKelas (sekarang return Future)
    await _anomaliController.analyzeKelas(idKelas);

    if (!mounted) return;
    setState(() => _isScanning = false);
  }

  /// Scan of the class that is selected in the dropdown. [_selectedKelas] is a KelasModel for an
  /// ADMIN but a raw Map for a DOSEN, so the id goes through [kelasIdOf].
  void _scanSelectedKelas() {
    final int? idKelas = kelasIdOf(_selectedKelas);
    if (idKelas != null) _scanKelas(idKelas);
  }

  Future<void> _scanAllKelas() async {
    if (_kelasList.isEmpty) {
      ErrorHelper.showToast('Info', 'Tidak ada kelas untuk dipindai');
      return;
    }

    _lastScanWasAll = true;
    setState(() => _isScanning = true);
    _anomaliController.anomaliList.clear();

    final List<AnomaliModel> hasil = <AnomaliModel>[];
    final List<String> peringatan = <String>[];
    int gagal = 0;

    for (final kelas in _kelasList) {
      final int? idKelas = kelasIdOf(kelas);
      if (idKelas == null) {
        gagal++;
        continue;
      }

      // await each scan: the next one must not start before this one is done, and a failure
      // must be counted instead of reported as a success
      final bool berhasil = await _anomaliController.analyzeKelas(
        idKelas,
        silent: true,
      );
      if (berhasil) {
        hasil.addAll(_anomaliController.anomaliList);
        for (final w in _anomaliController.warnings) {
          if (!peringatan.contains(w)) peringatan.add(w);
        }
      } else {
        gagal++;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // analyzeKelas leaves only the last class in the list: show every class together
    _anomaliController.anomaliList.assignAll(hasil);
    _anomaliController.warnings.assignAll(peringatan);
    _anomaliController.lastScanFailed.value = gagal > 0;
    final String ringkasan = scanSummaryMessage(
      total: _kelasList.length,
      failed: gagal,
    );
    _anomaliController.message.value = ringkasan;

    if (!mounted) return;
    setState(() => _isScanning = false);

    final String peringatanText = joinWarnings(peringatan);
    ErrorHelper.showToast(
      gagal == 0 ? 'Sukses' : 'Sebagian Gagal',
      peringatanText.isEmpty ? ringkasan : '$ringkasan\n$peringatanText',
      duration: const Duration(seconds: 5),
    );
  }

  void _retryLastScan() {
    if (_lastScanWasAll || kelasIdOf(_selectedKelas) == null) {
      _scanAllKelas();
    } else {
      _scanSelectedKelas();
    }
  }

  List<AnomaliModel> get _filteredAnomalies {
    return _anomaliController.anomaliList;
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

                    _buildWarningBanner(),

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
              IconButton(
                tooltip: 'Kembali',
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                onPressed: () => Get.back(),
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
                onTap: _selectedKelas != null ? _scanSelectedKelas : null,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                ),
              ),
              if (_userRole == 'ADMIN') ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Get.toNamed(AppRoutes.adminAnomalyConfig),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.settings, color: Colors.white, size: 20),
                  ),
                ),
              ],
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

  Widget _buildWarningBanner() {
    return Obx(() {
      final warnings = _anomaliController.warnings;
      if (warnings.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  joinWarnings(warnings.toList()),
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                ),
              ),
            ],
          ),
        ),
      );
    });
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
                        if (kelas != null) _scanSelectedKelas();
                      },
                    ),
                  ),
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

      // A failed scan found nothing because it did not finish, not because all is well
      if (anomalies.isEmpty && _anomaliController.lastScanFailed.value) {
        return ErrorRetryView(
          title: 'Pemindaian anomali gagal',
          message: _anomaliController.message.value.isEmpty
              ? 'Pemindaian tidak dapat diselesaikan.'
              : _anomaliController.message.value,
          onRetry: _retryLastScan,
        );
      }

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
          final int? idKelas = kelasIdOf(_selectedKelas);
          if (idKelas != null) {
            await _scanKelas(idKelas);
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
                        anomali.nama ?? 'User ID: ${anomali.idUser}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (anomali.nama != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${anomali.idUser}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
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
              anomali.nama ?? 'User ID: ${anomali.idUser}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (anomali.nama != null) ...[
              const SizedBox(height: 4),
              Text(
                'User ID: ${anomali.idUser}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
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
          ],
        ),
      ),
    );
  }
}
