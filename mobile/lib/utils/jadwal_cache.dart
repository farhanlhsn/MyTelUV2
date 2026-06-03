import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache key constants
class JadwalCacheKeys {
  static const String jadwalMingguan = 'cache_jadwal_mingguan';
  static const String jadwalMingguanTs = 'cache_jadwal_mingguan_ts';
  static const String kelasHariIni    = 'cache_kelas_hari_ini';
  static const String kelasHariIniTs  = 'cache_kelas_hari_ini_ts';
}

class JadwalCache {
  /// Simpan jadwal mingguan ke cache
  static Future<void> saveJadwalMingguan(
      Map<String, List<dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        JadwalCacheKeys.jadwalMingguan, jsonEncode(data));
    await prefs.setString(
        JadwalCacheKeys.jadwalMingguanTs, DateTime.now().toIso8601String());
  }

  /// Load jadwal mingguan dari cache
  static Future<Map<String, List<dynamic>>?> loadJadwalMingguan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(JadwalCacheKeys.jadwalMingguan);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as List<dynamic>)));
    } catch (_) {
      return null;
    }
  }

  /// Simpan kelas hari ini ke cache
  static Future<void> saveKelasHariIni(List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(JadwalCacheKeys.kelasHariIni, jsonEncode(data));
    await prefs.setString(
        JadwalCacheKeys.kelasHariIniTs, DateTime.now().toIso8601String());
  }

  /// Load kelas hari ini dari cache
  static Future<List<dynamic>?> loadKelasHariIni() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(JadwalCacheKeys.kelasHariIni);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Ambil timestamp cache (untuk ditampilkan di UI)
  static Future<DateTime?> getJadwalMingguanTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(JadwalCacheKeys.jadwalMingguanTs);
    return ts != null ? DateTime.tryParse(ts) : null;
  }

  static Future<DateTime?> getKelasHariIniTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(JadwalCacheKeys.kelasHariIniTs);
    return ts != null ? DateTime.tryParse(ts) : null;
  }
}
