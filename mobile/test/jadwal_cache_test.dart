import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/jadwal_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('saves and loads the classes of today', () async {
    await JadwalCache.saveKelasHariIni(<dynamic>[
      <String, dynamic>{'id_kelas': 1},
    ]);

    expect(await JadwalCache.loadKelasHariIni(), hasLength(1));
    expect(await JadwalCache.getKelasHariIniTimestamp(), isNotNull);
  });

  test('clear removes both saved schedules and their times, and nothing else', () async {
    await JadwalCache.saveKelasHariIni(<dynamic>[
      <String, dynamic>{'id_kelas': 1},
    ]);
    await JadwalCache.saveJadwalMingguan(<String, List<dynamic>>{
      'Senin': <dynamic>[
        <String, dynamic>{'id_kelas': 1},
      ],
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('something_else', 'stays');

    await JadwalCache.clear();

    expect(await JadwalCache.loadKelasHariIni(), isNull);
    expect(await JadwalCache.loadJadwalMingguan(), isNull);
    expect(await JadwalCache.getKelasHariIniTimestamp(), isNull);
    expect(await JadwalCache.getJadwalMingguanTimestamp(), isNull);
    expect(prefs.getString('something_else'), 'stays');
  });

  test('clear on an empty cache is fine', () async {
    await expectLater(JadwalCache.clear(), completes);
  });
}
