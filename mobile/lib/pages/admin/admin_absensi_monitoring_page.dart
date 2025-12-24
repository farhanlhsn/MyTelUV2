import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:mobile/models/kelas.dart';
import 'package:mobile/services/akademik_service.dart';
import 'package:mobile/services/api_client.dart';

class AdminAbsensiMonitoringPage extends StatefulWidget {
  const AdminAbsensiMonitoringPage({super.key});

  @override
  State<AdminAbsensiMonitoringPage> createState() => _AdminAbsensiMonitoringPageState();
}

class _AdminAbsensiMonitoringPageState extends State<AdminAbsensiMonitoringPage> {
  final AkademikService _akademikService = AkademikService();
  final Dio _dio = ApiClient.dio;

  List<KelasModel> _kelasList = [];
  Map<int, Map<String, dynamic>> _kelasStats = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final kelasList = await _akademikService.getAllKelas(limit: 100);
      setState(() {
        _kelasList = kelasList;
        _isLoading = false;
      });

      // Load stats for each kelas in background
      for (final kelas in kelasList) {
        _loadKelasStats(kelas.idKelas);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadKelasStats(int idKelas) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/akademik/absensi/kelas/$idKelas/stats',
      );

      if (response.data is Map<String, dynamic> && response.data['status'] == 'success') {
        setState(() {
          _kelasStats[idKelas] = response.data['data'] as Map<String, dynamic>;
        });
      }
    } catch (e) {
      // Ignore individual errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE63946),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      "Monitoring Kehadiran",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Summary Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      Icons.class_,
                      '${_kelasList.length}',
                      'Total Kelas',
                    ),
                    _buildSummaryItem(
                      Icons.people,
                      '${_kelasStats.values.fold<int>(0, (sum, s) => sum + (s['totalPeserta'] as int? ?? 0))}',
                      'Total Peserta',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFE63946)),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_error!, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadData,
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          )
                        : _kelasList.isEmpty
                            ? const Center(
                                child: Text('Tidak ada kelas', style: TextStyle(color: Colors.grey)),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadData,
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _kelasList.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final kelas = _kelasList[index];
                                    final stats = _kelasStats[kelas.idKelas];
                                    return _buildKelasCard(kelas, stats);
                                  },
                                ),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildKelasCard(KelasModel kelas, Map<String, dynamic>? stats) {
    final totalPeserta = stats?['totalPeserta'] as int? ?? 0;
    final totalSesi = stats?['totalMahasiswaAbsensi'] as int? ?? 0;
    final totalAbsensi = stats?['totalAbsensi'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.class_, color: Color(0xFFE63946)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kelas.namaKelas,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (kelas.matakuliah != null)
                      Text(
                        '${kelas.matakuliah!.kodeMatakuliah} - ${kelas.matakuliah!.namaMatakuliah}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dosen
          Row(
            children: [
              Icon(Icons.person, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                kelas.dosen?.nama ?? '-',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Peserta', '$totalPeserta', Colors.blue),
                _buildStatItem('Sesi', '$totalSesi', Colors.orange),
                _buildStatItem('Absensi', '$totalAbsensi', Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
