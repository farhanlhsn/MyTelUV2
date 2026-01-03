import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/pengajuan_plat_model.dart';

void main() {
  group('PengajuanPlatModel', () {
    test('fromJson should parse valid JSON correctly', () {
      final json = {
        'id_kendaraan': 1,
        'id_user': 10,
        'plat_nomor': 'D 1234 ABC',
        'nama_kendaraan': 'Motor Honda',
        'status_pengajuan': 'MENUNGGU',
        'feedback': null,
        'fotoKendaraan': ['url1', 'url2'],
        'fotoSTNK': 'url_stnk',
        'createdAt': '2025-01-01T10:00:00.000Z',
        'updatedAt': '2025-01-01T10:00:00.000Z',
        'user': {
          'nama': 'Test User',
          'username': 'testuser'
        }
      };

      final model = PengajuanPlatModel.fromJson(json);

      expect(model.idKendaraan, 1);
      expect(model.idUser, 10);
      expect(model.platNomor, 'D 1234 ABC');
      expect(model.namaKendaraan, 'Motor Honda');
      expect(model.statusPengajuan, 'MENUNGGU');
      expect(model.fotoKendaraan.length, 2);
      expect(model.fotoSTNK, 'url_stnk');
      expect(model.userName, 'Test User');
      expect(model.userUsername, 'testuser');
    });

    test('fromJson should handle null fields and defaults', () {
      final json = {
        'id_kendaraan': 1,
        // Missing optional fields
      };

      final model = PengajuanPlatModel.fromJson(json);

      expect(model.idKendaraan, 1);
      expect(model.platNomor, '');
      expect(model.statusPengajuan, 'MENUNGGU');
      expect(model.fotoKendaraan, isEmpty);
    });

    test('getStatusColor should return correct colors', () {
      final modelApproved = PengajuanPlatModel(
          idKendaraan: 1, platNomor: '', namaKendaraan: '', statusPengajuan: 'DISETUJUI', 
          fotoKendaraan: [], fotoSTNK: '', createdAt: DateTime.now(), updatedAt: DateTime.now());
      
      final modelRejected = PengajuanPlatModel(
          idKendaraan: 1, platNomor: '', namaKendaraan: '', statusPengajuan: 'DITOLAK', 
          fotoKendaraan: [], fotoSTNK: '', createdAt: DateTime.now(), updatedAt: DateTime.now());

      final modelPending = PengajuanPlatModel(
          idKendaraan: 1, platNomor: '', namaKendaraan: '', statusPengajuan: 'MENUNGGU', 
          fotoKendaraan: [], fotoSTNK: '', createdAt: DateTime.now(), updatedAt: DateTime.now());

      expect(modelApproved.getStatusColor(), const Color(0xFF00C853));
      expect(modelRejected.getStatusColor(), const Color(0xFFF85E55));
      expect(modelPending.getStatusColor(), const Color(0xFFFC5F57));
    });
  });
}
