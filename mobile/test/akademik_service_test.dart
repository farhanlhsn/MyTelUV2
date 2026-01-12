import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/kelas_hari_ini.dart';
import 'package:mobile/services/akademik_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<Dio>()])
import 'akademik_service_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late AkademikService akademikService;

  setUp(() {
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

      final result = await akademikService.getKelasHariIni();

      expect(result.length, 1);
      expect(result.first.namaKelas, 'IF-44-01');
    });

    test('getKelasHariIni should return empty list if response is null/empty', () async {
       when(mockDio.get(any)).thenAnswer((_) async => Response(
        data: {'status': 'success', 'data': []},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/akademik/kelas/hari-ini'),
      ));

      final result = await akademikService.getKelasHariIni();
      expect(result, isEmpty);
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
