import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/controllers/home_controller.dart';
import 'package:mobile/services/akademik_service.dart';

import 'support/stub_http_adapter.dart';

/// One class of `GET /akademik/absensi/ku/history`: the server's own stats, which already count
/// every closed session of the class (a session without a record is "tidak hadir") and leave
/// izin/sakit out of the percentage.
Map<String, dynamic> _kelas({
  required int totalSesi,
  required int hadir,
  int izin = 0,
  int sakit = 0,
}) => <String, dynamic>{
  'kelas': <String, dynamic>{'id_kelas': 1, 'nama_kelas': 'IF-44-01'},
  'sessions': <dynamic>[],
  'stats': <String, dynamic>{
    'total_sesi': totalSesi,
    'total_hadir': hadir,
    'total_telat': 0,
    'total_izin': izin,
    'total_sakit': sakit,
    'total_tidak_hadir': totalSesi - hadir - izin - sakit,
    'persentase': '0',
  },
};

void main() {
  HomeController controllerFor(StubHttpAdapter adapter) =>
      HomeController(akademikService: AkademikService(dio: adapter.dio()));

  group('totalKehadiranPercentage (Home) follows the attendance history', () {
    test('is read from the history of the student, not worked out from their own rows', () async {
      final adapter = StubHttpAdapter(200, <String, dynamic>{
        'status': 'success',
        // 5 closed sessions of which the student attended 2: the three missed ones leave no row
        'data': <dynamic>[_kelas(totalSesi: 5, hadir: 2)],
      });
      final HomeController controller = controllerFor(adapter);

      await controller.loadAbsensi();

      expect(adapter.lastRequest!.path, '/api/v1/akademik/absensi/ku/history');
      expect(controller.totalKehadiranPercentage, 40.0);
    });

    test('adds the classes up and leaves izin/sakit out of the denominator', () async {
      final adapter = StubHttpAdapter(200, <String, dynamic>{
        'status': 'success',
        'data': <dynamic>[
          _kelas(totalSesi: 4, hadir: 3, izin: 1),
          _kelas(totalSesi: 2, hadir: 1),
        ],
      });
      final HomeController controller = controllerFor(adapter);

      await controller.loadAbsensi();

      expect(controller.totalKehadiranPercentage, 80.0);
    });

    test('a loaded student without a countable session is at 0 (known), not 100 and not unknown', () async {
      final adapter = StubHttpAdapter(200, <String, dynamic>{
        'status': 'success',
        'data': <dynamic>[_kelas(totalSesi: 0, hadir: 0)],
      });
      final HomeController controller = controllerFor(adapter);

      await controller.loadAbsensi();

      expect(controller.totalKehadiranPercentage, 0.0);
    });

    test('a loaded student without any class is at 0 as well', () async {
      final adapter = StubHttpAdapter(200, <String, dynamic>{
        'status': 'success',
        'data': <dynamic>[],
      });
      final HomeController controller = controllerFor(adapter);

      await controller.loadAbsensi();

      expect(controller.totalKehadiranPercentage, 0.0);
    });

    test('before anything is loaded it is unknown (null), not 0', () {
      final HomeController controller = controllerFor(StubHttpAdapter(200, <String, dynamic>{}));

      expect(controller.totalKehadiranPercentage, isNull);
    });

    test('a first load that fails leaves it unknown and reports the error', () async {
      final adapter = StubHttpAdapter(500, <String, dynamic>{
        'status': 'error',
        'message': 'Terjadi kesalahan',
      });
      final HomeController controller = controllerFor(adapter);

      await controller.loadAbsensi();

      expect(controller.totalKehadiranPercentage, isNull);
      expect(controller.errorMessage.value, isNotEmpty);
      expect(controller.isLoadingAbsensi.value, isFalse);
    });

    test('a load that works after a failed one sets it', () async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (500, <String, dynamic>{'status': 'error', 'message': 'Terjadi kesalahan'}),
        (
          200,
          <String, dynamic>{
            'status': 'success',
            'data': <dynamic>[_kelas(totalSesi: 4, hadir: 3)],
          },
        ),
      ]);
      final HomeController controller = controllerFor(adapter);

      await controller.loadAbsensi();
      expect(controller.totalKehadiranPercentage, isNull);
      await controller.loadAbsensi();

      expect(controller.totalKehadiranPercentage, 75.0);
    });

    test('a failed request keeps the last percentage and reports the error', () async {
      final adapter = StubHttpAdapter.sequence(<(int, Map<String, dynamic>)>[
        (
          200,
          <String, dynamic>{
            'status': 'success',
            'data': <dynamic>[_kelas(totalSesi: 4, hadir: 3)],
          },
        ),
        (500, <String, dynamic>{'status': 'error', 'message': 'Terjadi kesalahan'}),
      ]);
      final HomeController controller = controllerFor(adapter);
      await controller.loadAbsensi();
      expect(controller.totalKehadiranPercentage, 75.0);

      await controller.loadAbsensi();

      expect(controller.totalKehadiranPercentage, 75.0);
      expect(controller.errorMessage.value, isNotEmpty);
      expect(controller.isLoadingAbsensi.value, isFalse);
    });
  });
}
