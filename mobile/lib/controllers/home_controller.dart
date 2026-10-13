import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/kelas.dart';
import '../models/kelas_hari_ini.dart';
import '../models/user.dart';
import '../services/akademik_service.dart';
import '../utils/attendance_status.dart';
import '../utils/logger.dart';

class HomeController extends GetxController {
  final AkademikService _akademikService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// [akademikService] is for tests; the app uses the default one.
  HomeController({AkademikService? akademikService})
    : _akademikService = akademikService ?? AkademikService();

  // Observable states
  final RxBool isLoading = false.obs;
  final RxBool isLoadingKelas = false.obs;
  final RxBool isLoadingKelasHariIni = false.obs;
  final RxBool isLoadingAbsensi = false.obs;

  final RxList<PesertaKelasModel> kelasList = <PesertaKelasModel>[].obs;
  final RxList<KelasHariIniModel> kelasHariIniList = <KelasHariIniModel>[].obs;

  /// Attendance of the student over all their classes, in percent (see [loadAbsensi]). Null until
  /// the history was loaded once: an unknown value is not 0%.
  final Rxn<double> kehadiranPercentage = Rxn<double>();
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

  // Load the attendance percentage of the student. It comes from the same history the absensi page
  // shows (the server's own counts: every closed session counts, also one the student missed without
  // leaving a record; izin/sakit are left out), so Home and History say the same.
  Future<void> loadAbsensi() async {
    isLoadingAbsensi.value = true;
    try {
      final List<Map<String, dynamic>> history =
          await _akademikService.getAbsensiKuHistory();
      kehadiranPercentage.value = overallAttendancePercentage(history);
    } catch (e) {
      // The last percentage stays on screen (none yet if this was the first load)
      errorMessage.value = 'Failed to load absensi: ${e.toString()}';
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

  // Attendance percentage over all classes: null until the history was loaded, 0 when nothing is
  // countable yet
  double? get totalKehadiranPercentage => kehadiranPercentage.value;

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
      final Map<String, dynamic> body = await _akademikService.createAbsensi(
        idKelas: idKelas,
        idSesiAbsensi: idSesiAbsensi,
        latitude: latitude,
        longitude: longitude,
      );
      final bool success = body['status'] == 'success';

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
