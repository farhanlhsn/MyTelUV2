import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/pengajuan_plat_model.dart';
import 'package:mobile/utils/ui_helpers.dart';

PengajuanPlatModel _model(String status, {String? feedback}) {
  return PengajuanPlatModel(
    idKendaraan: 1,
    platNomor: 'D 1234 AB',
    namaKendaraan: 'Honda Vario',
    statusPengajuan: status,
    feedback: feedback,
    fotoKendaraan: const <String>[],
    fotoSTNK: '',
    createdAt: DateTime.utc(2026, 10, 1, 3, 0),
    updatedAt: DateTime.utc(2026, 10, 2, 4, 30),
  );
}

void main() {
  group('status colour, icon and label', () {
    test('MENUNGGU is amber with an hourglass', () {
      final model = _model('MENUNGGU');
      expect(model.getStatusColor(), const Color(0xFFF59E0B));
      expect(model.getStatusIcon(), Icons.hourglass_top);
      expect(model.getStatusText(), 'Menunggu');
    });

    test('DITOLAK is red with a cancel icon', () {
      final model = _model('DITOLAK');
      expect(model.getStatusColor(), const Color(0xFFDC2626));
      expect(model.getStatusIcon(), Icons.cancel);
      expect(model.getStatusText(), 'Ditolak');
    });

    test('DISETUJUI is green with a check icon and reads Disetujui, not Selesai', () {
      final model = _model('DISETUJUI');
      expect(model.getStatusColor(), const Color(0xFF16A34A));
      expect(model.getStatusIcon(), Icons.check_circle);
      expect(model.getStatusText(), 'Disetujui');
    });

    test('pending and rejected are clearly different colours', () {
      expect(
        _model('MENUNGGU').getStatusColor(),
        isNot(_model('DITOLAK').getStatusColor()),
      );
    });

    test('an unknown status falls back to the pending style', () {
      final model = _model('ENTAH');
      expect(model.getStatusColor(), const Color(0xFFF59E0B));
      expect(model.getStatusIcon(), Icons.hourglass_top);
      expect(model.getStatusText(), 'Menunggu');
    });
  });

  group('getTimeline', () {
    test('pending: submitted, then still waiting', () {
      final steps = _model('MENUNGGU').getTimeline();
      expect(steps.map((s) => s.title), <String>['Diajukan', 'Menunggu']);
      expect(steps.first.time, DateTime.utc(2026, 10, 1, 3, 0));
      expect(steps.first.isCurrent, isFalse);
      expect(steps.last.isCurrent, isTrue);
      expect(steps.last.time, isNull);
      expect(steps.last.color, const Color(0xFFF59E0B));
      expect(steps.last.icon, Icons.hourglass_top);
    });

    test('rejected: the admin feedback is attached to the last step', () {
      final steps = _model('DITOLAK', feedback: 'Foto STNK buram').getTimeline();
      expect(steps.map((s) => s.title), <String>['Diajukan', 'Ditolak']);
      expect(steps.last.time, DateTime.utc(2026, 10, 2, 4, 30));
      expect(steps.last.note, 'Foto STNK buram');
      expect(steps.last.color, const Color(0xFFDC2626));
      expect(steps.last.isCurrent, isTrue);
    });

    test('approved without feedback has no note', () {
      final steps = _model('DISETUJUI').getTimeline();
      expect(steps.map((s) => s.title), <String>['Diajukan', 'Disetujui']);
      expect(steps.last.note, isNull);
      expect(steps.last.color, const Color(0xFF16A34A));
    });

    test('blank feedback is treated as no feedback', () {
      expect(_model('DITOLAK', feedback: '   ').getTimeline().last.note, isNull);
    });

    test('a delete request on an approved vehicle shows as its own step without the raw prefix', () {
      final steps = _model(
        'DISETUJUI',
        feedback: 'DELETE_REQUEST: Motor dijual',
      ).getTimeline();
      expect(steps.map((s) => s.title), <String>[
        'Diajukan',
        'Disetujui',
        'Permintaan hapus diajukan',
      ]);
      expect(steps[1].isCurrent, isFalse);
      expect(steps.last.isCurrent, isTrue);
      expect(steps.last.time, DateTime.utc(2026, 10, 2, 4, 30));
      expect(steps.last.note, 'Alasan: Motor dijual');
    });
  });
}
