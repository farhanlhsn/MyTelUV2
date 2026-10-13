import '../models/kelas.dart';
import '../models/kelas_hari_ini.dart';

/// The class lists of the app come as typed models (ADMIN, via AkademikService) or as raw Maps
/// (DOSEN, via DosenService.getKelasDiampu). This returns the id of either, or null when the
/// item has no usable id, so callers never cast blindly.
int? kelasIdOf(dynamic item) {
  int? id;
  if (item is KelasModel) {
    id = item.idKelas;
  } else if (item is KelasHariIniModel) {
    id = item.idKelas;
  } else if (item is PesertaKelasModel) {
    id = item.idKelas;
  } else if (item is Map) {
    final raw = item['id_kelas'];
    if (raw is num) {
      id = raw.toInt();
    } else if (raw is String) {
      id = int.tryParse(raw);
    }
  }
  return (id != null && id > 0) ? id : null;
}

/// Headline of a "kelas hari ini" card: the course name, else the class name.
String kelasHariIniTitle(KelasHariIniModel kelas) {
  final course = kelas.matakuliah?.namaMatakuliah.trim() ?? '';
  if (course.isNotEmpty) return course;
  final name = kelas.namaKelas.trim();
  return name.isNotEmpty ? name : 'Kelas';
}
