import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/input_formatters.dart';
import 'package:mobile/utils/validators.dart';

void main() {
  group('Validators.platNomor', () {
    test('accepts the usual Indonesian plate shapes', () {
      for (final plate in <String>[
        'B 1234 ABC',
        'B1234ABC',
        'D 1234 AB',
        'DD 0000 KE',
        'AB 1 A',
        'D 1',
        'KT 123 ZZ',
      ]) {
        expect(Validators.platNomor(plate), isNull, reason: plate);
      }
    });

    test('trims surrounding whitespace before validating', () {
      expect(Validators.platNomor('  B 1234 ABC  '), isNull);
    });

    test('collapses runs of whitespace inside the plate', () {
      expect(Validators.platNomor('B  1234 AB'), isNull);
      expect(Validators.platNomor('B   1234    ABC'), isNull);
      expect(Validators.platNomor(' B\t1234  AB '), isNull);
    });

    test('rejects an empty or blank plate as required', () {
      expect(Validators.platNomor(null), 'Plat nomor wajib diisi');
      expect(Validators.platNomor(''), 'Plat nomor wajib diisi');
      expect(Validators.platNomor('   '), 'Plat nomor wajib diisi');
    });

    test('rejects malformed plates with the format message', () {
      const message = 'Format plat nomor tidak valid. Contoh: D 1234 ABC';
      for (final plate in <String>[
        '1234', // no region letters
        'B', // no digits
        'BBB 1234 A', // three region letters
        'B 12345 A', // five digits
        'B 1234 ABCD', // four suffix letters
        'B-1234-AB', // separators other than whitespace
        'B 12 34 AB', // whitespace inside the digits
        'B 12A4 AB', // letter inside the digits
      ]) {
        expect(Validators.platNomor(plate), message, reason: plate);
      }
    });

    test('is strict about case: lowercase must be uppercased by the input first', () {
      expect(
        Validators.platNomor('b 1234 abc'),
        'Format plat nomor tidak valid. Contoh: D 1234 ABC',
      );
    });
  });

  group('Validators.normalizePlat', () {
    test('trims and collapses whitespace to single spaces, keeping the letters as typed', () {
      expect(Validators.normalizePlat('  B   1234\tAB  '), 'B 1234 AB');
      expect(Validators.normalizePlat('B1234AB'), 'B1234AB');
      expect(Validators.normalizePlat(''), '');
    });
  });

  group('UpperCaseTextFormatter', () {
    const formatter = UpperCaseTextFormatter();

    test('uppercases what is typed and keeps the caret where it was', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: 'B 12'),
        const TextEditingValue(
          text: 'b 12a',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(result.text, 'B 12A');
      expect(result.selection, const TextSelection.collapsed(offset: 5));
    });

    test('leaves already uppercase input untouched', () {
      const value = TextEditingValue(
        text: 'D 1234 AB',
        selection: TextSelection.collapsed(offset: 9),
      );
      expect(formatter.formatEditUpdate(value, value), value);
    });
  });
}
