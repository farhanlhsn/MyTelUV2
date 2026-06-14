import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/kelas.dart';
import '../models/kelas_hari_ini.dart';
import '../models/absensi.dart';
import '../models/user.dart';
import '../services/akademik_service.dart';
import '../utils/logger.dart';

class HomeController extends GetxController {
  final AkademikService _akademikService = AkademikService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Observable states
  final RxBool isLoading = false.obs;
  final RxBool isLoadingKelas = false.obs;
  final RxBool isLoadingKelasHariIni = false.obs;
  final RxBool isLoadingAbsensi = false.obs;

  final RxList<PesertaKelasModel> kelasList = <PesertaKelasModel>[].obs;
  final RxList<KelasHariIniModel> kelasHariIniList = <KelasHariIniModel>[].obs;
  final RxList<AbsensiModel> absensiList = <AbsensiModel>[].obs;
  final RxMap<int, AbsensiStatsModel> absensiStats =
      <int, AbsensiStatsModel>{}.obs;
  final RxBool isKelasHariIniFromCache = false.obs;

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  // Load user data from secure storage
  Future<void> loadUserData() async {
    try {
      final String? idUser = await _secureStorage.read(key: 'id_user');
      final String? username = await _secureStorage.read(key: 'username');
      final String? nama = await _secureStorage.read(key: 'nama');
      final String? role = await _secureStorage.read(key: 'role');

      if (idUser != null && username != null && nama != null && role != null) {
        currentUser.value = UserModel(
          idUser: int.parse(idUser),
          username: username,
          nama: nama,
          role: role,
        );
      }
    } catch (e) {
      errorMessage.value = 'Failed to load user data: ${e.toString()}';
    }
  }

  // Load all data (kelas hari ini and absensi)
  Future<void> loadData() async {
    isLoading.value = true;
    errorMessage.value = '';

    // First load user data so we have the role
    await loadUserData();

    final userRole = currentUser.value?.role;
    final List<Future<dynamic>> tasks = [
      Future(() => loadKelasHariIni()).catchError((e) {
        debugLog('⚠️ Error loading kelas hari ini: $e');
        return null;
      }),
    ];

    if (userRole == 'MAHASISWA') {
      tasks.add(
        Future(() => loadKelas()).catchError((e) {
          debugLog('⚠️ Error loading kelas: $e');
          return null;
        }),
      );
      tasks.add(
        Future(() => loadAbsensi()).catchError((e) {
          debugLog('⚠️ Error loading absensi: $e');
          return null;
        }),
      );
    }

    await Future.wait(tasks);
    isLoading.value = false;
  }

  // Load kelas hari ini (classes for today)
  Future<void> loadKelasHariIni() async {
    isLoadingKelasHariIni.value = true;
    try {
      final (kelas, fromCache) = await _akademikService.getKelasHariIni();
      kelasHariIniList.value = kelas;
      isKelasHariIniFromCache.value = fromCache;
    } catch (e) {
      errorMessage.value = 'Failed to load kelas hari ini: ${e.toString()}';
      kelasHariIniList.value = [];
      isKelasHariIniFromCache.value = false;
    } finally {
      isLoadingKelasHariIni.value = false;
    }
  }

  // Load kelas mahasiswa
  Future<void> loadKelas() async {
    isLoadingKelas.value = true;
    try {
      final List<PesertaKelasModel> kelas = await _akademikService.getKelasKu();
      kelasList.value = kelas;
    } catch (e) {
      errorMessage.value = 'Failed to load kelas: ${e.toString()}';
      kelasList.value = [];
    } finally {
      isLoadingKelas.value = false;
    }
  }

  // Load absensi mahasiswa
  Future<void> loadAbsensi() async {
    isLoadingAbsensi.value = true;
    try {
      final List<AbsensiModel> absensi = await _akademikService.getAbsensiKu();
      absensiList.value = absensi;
      absensiStats.value = _buildAbsensiStats(absensi);
    } catch (e) {
      errorMessage.value = 'Failed to load absensi: ${e.toString()}';
      absensiList.value = [];
      absensiStats.value = {};
    } finally {
      isLoadingAbsensi.value = false;
    }
  }

  Map<int, AbsensiStatsModel> _buildAbsensiStats(
    List<AbsensiModel> absensiList,
  ) {
    final Map<int, Map<String, int>> countsByKelas = {};

    for (final AbsensiModel absensi in absensiList) {
      final counts = countsByKelas.putIfAbsent(
        absensi.idKelas,
        () => {'HADIR': 0, 'IJIN': 0, 'SAKIT': 0, 'ALPHA': 0},
      );
      counts[absensi.typeAbsensi] = (counts[absensi.typeAbsensi] ?? 0) + 1;
    }

    return countsByKelas.map(
      (int idKelas, Map<String, int> counts) =>
          MapEntry(idKelas, AbsensiStatsModel.fromJson(counts)),
    );
  }

  // Get next class (kelas terdekat berdasarkan jadwal)
  PesertaKelasModel? get nextClass {
    if (kelasList.isEmpty) return null;

    // Return first class for now
    // TODO: Implement proper scheduling logic based on jadwal field
    return kelasList.first;
  }

  // Get absensi stats for a specific class
  AbsensiStatsModel? getAbsensiStatsForKelas(int idKelas) {
    return absensiStats[idKelas];
  }

  // Get total kehadiran percentage across all classes
  double get totalKehadiranPercentage {
    if (absensiStats.isEmpty) return 100.0;

    int totalHadir = 0;
    int totalAbsensi = 0;

    for (final AbsensiStatsModel stats in absensiStats.values) {
      totalHadir += stats.totalHadir;
      totalAbsensi +=
          stats.totalHadir +
          stats.totalIjin +
          stats.totalSakit +
          stats.totalAlpha;
    }

    if (totalAbsensi == 0) return 100.0;

    return (totalHadir / totalAbsensi * 100);
  }

  // Refresh all data
  Future<void> refreshData() async {
    await loadData();
  }

  // Daftar kelas baru
  Future<bool> daftarKelas(int idKelas) async {
    try {
      isLoading.value = true;
      final bool success = await _akademikService.daftarKelas(idKelas);

      if (success) {
        await loadKelas(); // Reload kelas list
      }

      return success;
    } catch (e) {
      errorMessage.value = 'Failed to daftar kelas: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Drop kelas
  Future<bool> dropKelas(int idKelas) async {
    try {
      isLoading.value = true;
      final bool success = await _akademikService.dropKelas(idKelas);

      if (success) {
        await loadKelas(); // Reload kelas list
      }

      return success;
    } catch (e) {
      errorMessage.value = 'Failed to drop kelas: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Create absensi
  Future<bool> createAbsensi({
    required int idKelas,
    required int idSesiAbsensi,
    required double latitude,
    required double longitude,
  }) async {
    try {
      isLoading.value = true;
      final bool success = await _akademikService.createAbsensi(
        idKelas: idKelas,
        idSesiAbsensi: idSesiAbsensi,
        latitude: latitude,
        longitude: longitude,
      );

      if (success) {
        await loadAbsensi(); // Reload absensi list
      }

      return success;
    } catch (e) {
      errorMessage.value = 'Failed to create absensi: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    // Clean up resources if needed
    super.onClose();
  }
}
