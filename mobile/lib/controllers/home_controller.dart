import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/kelas.dart';
import '../models/absensi.dart';
import '../models/user.dart';
import '../services/akademik_service.dart';

class HomeController extends GetxController {
  final AkademikService _akademikService = AkademikService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Observable states
  final RxBool isLoading = false.obs;
  final RxBool isLoadingKelas = false.obs;
  final RxBool isLoadingAbsensi = false.obs;

  final RxList<PesertaKelasModel> kelasList = <PesertaKelasModel>[].obs;
  final RxList<AbsensiModel> absensiList = <AbsensiModel>[].obs;
  final RxMap<int, AbsensiStatsModel> absensiStats =
      <int, AbsensiStatsModel>{}.obs;

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserData();
    loadData();
  }

  // Load user data from secure storage
  Future<void> loadUserData() async {
    try {
      final String? username = await _secureStorage.read(key: 'username');
      final String? nama = await _secureStorage.read(key: 'nama');
      final String? role = await _secureStorage.read(key: 'role');

      if (username != null && nama != null && role != null) {
        currentUser.value = UserModel(
          username: username,
          nama: nama,
          role: role,
        );
      }
    } catch (e) {
      errorMessage.value = 'Failed to load user data: ${e.toString()}';
    }
  }

  // Load all data (kelas and absensi)
  Future<void> loadData() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      await Future.wait([loadKelas(), loadAbsensi()]);
    } catch (e) {
      errorMessage.value = 'Failed to load data: ${e.toString()}';
    } finally {
      isLoading.value = false;
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

      // Load absensi stats
      final Map<int, AbsensiStatsModel> stats = await _akademikService
          .getAbsensiStats();
      absensiStats.value = stats;
    } catch (e) {
      errorMessage.value = 'Failed to load absensi: ${e.toString()}';
      absensiList.value = [];
      absensiStats.value = {};
    } finally {
      isLoadingAbsensi.value = false;
    }
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
    if (absensiStats.isEmpty) return 0.0;

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

    if (totalAbsensi == 0) return 0.0;

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
