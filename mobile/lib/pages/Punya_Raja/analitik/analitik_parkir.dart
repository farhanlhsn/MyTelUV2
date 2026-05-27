import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/parkir_service.dart';
import '../../../services/parkir_socket_service.dart';
import '../../../services/api_client.dart';
import '../../../models/parkir_model.dart';
import 'package:mobile/utils/logger.dart';

class AnalitikParkirPage extends StatefulWidget {
  const AnalitikParkirPage({super.key});

  @override
  State<AnalitikParkirPage> createState() => _AnalitikParkirPageState();
}

class _AnalitikParkirPageState extends State<AnalitikParkirPage> {
  final ParkirService _parkirService = ParkirService();
  final ParkirSocketService _socketService = ParkirSocketService();

  ParkirAnalitikModel? _analitik;
  bool _isLoading = true;
  bool _isLive = false;       // true ketika WebSocket berhasil connect
  String? _errorMessage;

  static const Color primaryColor   = Color(0xFFE63946);
  static const Color darkRedColor   = Color(0xFFC14A44);

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
    _connectSocket();
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('🔄 Loading analitik data...');
      final data = await _parkirService.getAnalitikParkiran();
      debugLog('✅ Analitik data loaded: ${data?.parkiran.length ?? 0} parkiran');

      if (mounted) {
        setState(() {
          _analitik = data;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugLog('❌ Error loading analitik: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ─── WebSocket ────────────────────────────────────────────────────────────

  void _connectSocket() {
    final baseUrl = ApiClient.baseUrl; // Gunakan base URL yang sama dengan HTTP
    _socketService.connect(
      baseUrl: baseUrl,
      onConnected: () {
        if (mounted) setState(() => _isLive = true);
      },
      onDisconnected: () {
        if (mounted) setState(() => _isLive = false);
      },
      onError: (_) {
        if (mounted) setState(() => _isLive = false);
      },
      onUpdate: _onParkingUpdate,
    );
  }

  /// Dipanggil setiap kali backend mengemit event `parking_update`.
  /// Hanya memperbarui satu item parkiran yang relevan, bukan reload seluruh data.
  void _onParkingUpdate(Map<String, dynamic> data) {
    if (_analitik == null || !mounted) return;

    final int idParkiran   = (data['id_parkiran']   as num).toInt();
    final int liveKapasitas = (data['live_kapasitas'] as num).toInt();
    final int kapasitas     = (data['kapasitas']     as num).toInt();

    final updatedList = _analitik!.parkiran.map((p) {
      if (p.idParkiran == idParkiran) {
        final slotTersedia   = kapasitas - liveKapasitas;
        final persentaseTerisi = kapasitas > 0
            ? (liveKapasitas / kapasitas) * 100
            : 0.0;
        return p.copyWith(
          liveKapasitas:   liveKapasitas,
          slotTersedia:    slotTersedia,
          persentaseTerisi: persentaseTerisi,
        );
      }
      return p;
    }).toList();

    // Recalculate summary
    final totalKapasitas = updatedList.fold<int>(0, (s, p) => s + p.kapasitas);
    final totalTerisi    = updatedList.fold<int>(0, (s, p) => s + p.liveKapasitas);
    final totalTersedia  = totalKapasitas - totalTerisi;
    final persen = totalKapasitas > 0
        ? (totalTerisi / totalKapasitas) * 100
        : 0.0;

    setState(() {
      _analitik = _analitik!.copyWith(
        parkiran: updatedList,
        summary: ParkirSummary(
          totalKapasitas:  totalKapasitas,
          totalTerisi:     totalTerisi,
          totalTersedia:   totalTersedia,
          persentaseTerisi: persen,
        ),
      );
    });
    debugLog('🔄 UI updated via WebSocket: parkiran $idParkiran → $liveKapasitas/$kapasitas');
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Analitik Ketersediaan Parkir',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Indikator live WebSocket
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isLive
                        ? Row(
                            key: const ValueKey('live'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          )
                        : const Icon(
                            key: ValueKey('offline'),
                            Icons.wifi_off,
                            color: Colors.white54,
                            size: 16,
                          ),
                  ),
                ],
              ),
            ),

            // Konten utama (putih melengkung)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft:  Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft:  Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: _buildContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadData, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_analitik == null || _analitik!.parkiran.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_parking, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Tidak ada data parkiran',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            _buildSummaryCard(_analitik!.summary),
            const SizedBox(height: 24),

            const Text(
              'Lokasi Parkiran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            ...(_analitik!.parkiran.map((parkiran) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildLocationCard(
                name:        'Lokasi Parkiran : ${parkiran.namaParkiran}',
                slotTersedia: parkiran.slotTersedia,
                kapasitas:   parkiran.kapasitas,
                persentase:  parkiran.persentaseTerisi ?? 0,
              ),
            ))),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ParkirSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            const Color(0xFF130B2B).withValues(alpha: 0.78),
          ],
          begin: Alignment.centerLeft,
          end:   Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:     darkRedColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset:    const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Ringkasan Parkir',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total',    summary.totalKapasitas.toString()),
              _buildSummaryItem('Terisi',   summary.totalTerisi.toString()),
              _buildSummaryItem('Tersedia', summary.totalTersedia.toString()),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value:           summary.persentaseTerisi / 100,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor:      const AlwaysStoppedAnimation<Color>(Colors.white),
            borderRadius:    BorderRadius.circular(10),
            minHeight:       8,
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.persentaseTerisi.toStringAsFixed(1)}% Terisi',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard({
    required String name,
    required int    slotTersedia,
    required int    kapasitas,
    required double persentase,
  }) {
    final Color statusColor = slotTersedia > 10
        ? Colors.green
        : slotTersedia > 0
            ? Colors.orange
            : Colors.red;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: primaryColor, width: 1),
        boxShadow: [
          BoxShadow(
            color:      Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kapasitas: $kapasitas',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:      kapasitas > 0 ? (kapasitas - slotTersedia) / kapasitas : 0,
                    minHeight:  5,
                    backgroundColor:  Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color:        statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Slot : $slotTersedia',
              style: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.bold,
                fontSize:   14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}