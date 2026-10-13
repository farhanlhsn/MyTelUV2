import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/akademik_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateNiceMocks([MockSpec<Dio>()])
import 'akademik_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockDio mockDio;
  late AkademikService akademikService;

  setUp(() {
    // The service keeps a copy of the schedule for offline use (JadwalCache)
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mockDio = MockDio();
    akademikService = AkademikService(dio: mockDio);
  });

  group('AkademikService', () {
    test('getKelasHariIni should return list of KelasHariIniModel on success', () async {
      final mockData = [
         {
          'id_kelas': 1,
          'nama_kelas': 'IF-44-01',
          'ruangan': 'A101',
          'jam_mulai': '08:00:00',
          'jam_berakhir': '10:00:00',
          'has_active_absensi': false,
        }
      ];

      when(mockDio.get(any)).thenAnswer((_) async => Response(
        data: {'status': 'success', 'data': mockData},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/akademik/kelas/hari-ini'),
      ));

      // The service returns (classes, whether they came from the offline copy)
      final (kelas, fromCache) = await akademikService.getKelasHariIni();

      expect(kelas.length, 1);
      expect(kelas.first.namaKelas, 'IF-44-01');
      expect(fromCache, isFalse);
    });

    test('getKelasHariIni serves the saved copy, flagged as cached, when the server cannot be reached', () async {
      when(mockDio.get(any)).thenAnswer((_) async => Response(
        data: {
          'status': 'success',
          'data': [
            {
              'id_kelas': 1,
              'nama_kelas': 'IF-44-01',
              'ruangan': 'A101',
              'jam_mulai': '08:00:00',
              'jam_berakhir': '10:00:00',
              'has_active_absensi': false,
            },
          ],
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/akademik/kelas/hari-ini'),
      ));
      await akademikService.getKelasHariIni();

      when(mockDio.get(any)).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/api/akademik/kelas/hari-ini'),
        type: DioExceptionType.connectionError,
      ));
      final (kelas, fromCache) = await akademikService.getKelasHariIni();

      expect(fromCache, isTrue);
      expect(kelas.single.namaKelas, 'IF-44-01');
    });

    test('getKelasHariIni should return empty list if response is null/empty', () async {
       when(mockDio.get(any)).thenAnswer((_) async => Response(
        data: {'status': 'success', 'data': []},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/akademik/kelas/hari-ini'),
      ));

      final (kelas, fromCache) = await akademikService.getKelasHariIni();
      expect(kelas, isEmpty);
      expect(fromCache, isFalse);
    });

    test('a failed request says what the server said, in Indonesian, without an English wrapper', () async {
      when(mockDio.get(any)).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/api/akademik/kelas/hari-ini'),
        response: Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: '/api/akademik/kelas/hari-ini'),
          data: {'status': 'error', 'message': 'Terjadi kesalahan pada server'},
        ),
        type: DioExceptionType.badResponse,
      ));

      await expectLater(
        akademikService.getKelasHariIni(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'text', 'Exception: Terjadi kesalahan pada server')),
      );
    });

    test('a failed request without a connection says so in Indonesian', () async {
      when(mockDio.get(any)).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/api/akademik/kelas/hari-ini'),
        type: DioExceptionType.connectionError,
      ));

      await expectLater(
        akademikService.getKelasHariIni(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'text',
          startsWith('Exception: Tidak dapat terhubung ke server'),
        )),
      );
    });

    // Admin test
    test('createMatakuliah should return MatakuliahModel on success', () async {
        final mockData = {
           'id_matakuliah': 100,
           'nama_matakuliah': 'New MK',
           'kode_matakuliah': 'MK100'
        };

        when(mockDio.post(any, data: anyNamed('data'))).thenAnswer((_) async => Response(
            data: {'status': 'success', 'data': mockData},
            statusCode: 201,
            requestOptions: RequestOptions(path: '/api/akademik/matakuliah'),
        ));

        final result = await akademikService.createMatakuliah(
            namaMatakuliah: 'New MK', kodeMatakuliah: 'MK100'
        );

        expect(result.namaMatakuliah, 'New MK');
        expect(result.kodeMatakuliah, 'MK100');
    });

    test('createMatakuliah should throw exception on 409 conflict', () async {
       when(mockDio.post(any, data: anyNamed('data'))).thenThrow(
         DioException(
            requestOptions: RequestOptions(path: '/'),
            response: Response(statusCode: 409, requestOptions: RequestOptions(path: '/'), data: {'message': 'Conflict'}),
            type: DioExceptionType.badResponse,
         )
       );

       expect(
         () => akademikService.createMatakuliah(namaMatakuliah: 'Exists', kodeMatakuliah: 'EX'), 
         throwsException
       );
    });
  });
}
