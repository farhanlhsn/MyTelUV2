import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/anomali_helper.dart';

void main() {
  group('parseAnomaliWarnings', () {
    test('reads the warnings array of the analyze response', () {
      expect(
        parseAnomaliWarnings(<String, dynamic>{
          'status': 'success',
          'data': <dynamic>[],
          'warnings': <dynamic>['Layanan analisis pola waktu tidak tersedia'],
        }),
        <String>['Layanan analisis pola waktu tidak tersedia'],
      );
    });

    test('is empty when the response has no warnings', () {
      expect(
        parseAnomaliWarnings(<String, dynamic>{'data': <dynamic>[]}),
        isEmpty,
      );
      expect(parseAnomaliWarnings(null), isEmpty);
      expect(parseAnomaliWarnings('bukan map'), isEmpty);
      expect(
        parseAnomaliWarnings(<String, dynamic>{'warnings': 'teks'}),
        isEmpty,
      );
    });

    test('drops blanks and non-strings and removes duplicates', () {
      expect(
        parseAnomaliWarnings(<String, dynamic>{
          'warnings': <dynamic>['A', ' ', 3, null, 'A', ' B '],
        }),
        <String>['A', 'B'],
      );
    });
  });

  group('scanSummaryMessage', () {
    test('all scans succeeded', () {
      expect(
        scanSummaryMessage(total: 4, failed: 0),
        'Scan selesai untuk 4 kelas',
      );
    });

    test('some scans failed: counts the failures', () {
      expect(
        scanSummaryMessage(total: 4, failed: 1),
        'Scan selesai, 1 dari 4 kelas gagal dipindai',
      );
    });

    test('every scan failed', () {
      expect(
        scanSummaryMessage(total: 3, failed: 3),
        'Scan gagal untuk semua kelas (3)',
      );
    });
  });

  group('joinWarnings', () {
    test('joins one warning per line', () {
      expect(joinWarnings(<String>['A', 'B']), 'A\nB');
      expect(joinWarnings(<String>[]), '');
    });
  });
}
