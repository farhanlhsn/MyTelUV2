import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/validators.dart';

void main() {
  group('Validators.username', () {
    test('is required, 3-30 characters', () {
      expect(Validators.username(null), 'Username wajib diisi');
      expect(Validators.username('  '), 'Username wajib diisi');
      expect(Validators.username('ab'), 'Username minimal 3 karakter');
      expect(Validators.username('a' * 31), 'Username maksimal 30 karakter');
    });

    test('follows the server pattern: letter first, then letters, digits or underscore', () {
      const message =
          'Username harus diawali huruf dan hanya boleh berisi huruf, angka, dan underscore';
      expect(Validators.username('1budi'), message);
      expect(Validators.username('_budi'), message);
      expect(Validators.username('john.doe'), message);
      expect(Validators.username('john doe'), message);
      expect(Validators.username('budi_01'), isNull);
      expect(Validators.username('Budi'), isNull);
      expect(Validators.username(' budi '), isNull);
    });
  });

  group('Validators.nama', () {
    test('is required', () {
      expect(Validators.nama(null), 'Nama wajib diisi');
      expect(Validators.nama('   '), 'Nama wajib diisi');
      expect(Validators.nama('Budi Santoso'), isNull);
    });
  });

  group('Validators.password', () {
    test('requires a value', () {
      expect(Validators.password(null), 'Password wajib diisi');
      expect(Validators.password(''), 'Password wajib diisi');
    });

    test('needs at least 8 characters', () {
      expect(Validators.password('abc1234'), 'Password minimal 8 karakter');
      expect(Validators.password('1234567'), 'Password minimal 8 karakter');
    });

    test('needs a letter and a digit, like the server', () {
      const message = 'Password harus mengandung huruf dan angka';
      expect(Validators.password('abcdefgh'), message);
      expect(Validators.password('12345678'), message);
    });

    test('accepts 8+ characters with a letter and a digit', () {
      expect(Validators.password('abcd1234'), isNull);
      expect(Validators.password('Rahasia2026!'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('requires a value', () {
      expect(
        Validators.confirmPassword('', 'abcd1234'),
        'Konfirmasi password wajib diisi',
      );
      expect(
        Validators.confirmPassword(null, 'abcd1234'),
        'Konfirmasi password wajib diisi',
      );
    });

    test('must equal the password', () {
      expect(
        Validators.confirmPassword('abcd1235', 'abcd1234'),
        'Konfirmasi password tidak cocok',
      );
      expect(Validators.confirmPassword('abcd1234', 'abcd1234'), isNull);
    });
  });

  group('Validators.nimNip', () {
    test('is optional', () {
      expect(Validators.nimNip(null), isNull);
      expect(Validators.nimNip(''), isNull);
      expect(Validators.nimNip('   ', role: 'DOSEN'), isNull);
    });

    test('MAHASISWA: 11 or 12 digits', () {
      const message = 'NIM harus 11 atau 12 digit angka';
      expect(Validators.nimNip('1234567890'), message); // 10
      expect(Validators.nimNip('1234567890123'), message); // 13
      expect(Validators.nimNip('1234567890a'), message);
      expect(Validators.nimNip('12345678901'), isNull); // 11
      expect(Validators.nimNip('123456789012', role: 'MAHASISWA'), isNull); // 12
    });

    test('DOSEN and ADMIN: 8 to 20 digits', () {
      const message = 'NIP/NIDN harus 8 sampai 20 digit angka';
      for (final role in <String>['DOSEN', 'ADMIN']) {
        expect(Validators.nimNip('1234567', role: role), message, reason: role);
        expect(Validators.nimNip('123456789012345678901', role: role), message);
        expect(Validators.nimNip('1234abcd5678', role: role), message);
        expect(Validators.nimNip('12345678', role: role), isNull, reason: role);
        expect(Validators.nimNip('198001012005011001', role: role), isNull);
        expect(Validators.nimNip('12345678901234567890', role: role), isNull);
      }
    });

    test('trims before validating', () {
      expect(Validators.nimNip(' 12345678901 '), isNull);
    });
  });

  group('Validators.email', () {
    test('is optional', () {
      expect(Validators.email(null), isNull);
      expect(Validators.email(''), isNull);
      expect(Validators.email('  '), isNull);
    });

    test('accepts a plausible address', () {
      expect(Validators.email('budi@student.telkomuniversity.ac.id'), isNull);
      expect(Validators.email('  budi@example.com '), isNull);
    });

    test('rejects malformed addresses', () {
      for (final value in <String>[
        'budi',
        'budi@',
        '@example.com',
        'budi@example',
        'bu di@example.com',
      ]) {
        expect(Validators.email(value), 'Format email tidak valid', reason: value);
      }
    });
  });

  group('Validators.durasiMenit', () {
    test('requires a number', () {
      expect(Validators.durasiMenit(null), 'Durasi wajib diisi');
      expect(Validators.durasiMenit(''), 'Durasi wajib diisi');
      expect(Validators.durasiMenit('abc'), 'Durasi harus berupa angka');
      expect(Validators.durasiMenit('3.5'), 'Durasi harus berupa angka');
    });

    test('is limited to 1..240 minutes', () {
      const message = 'Durasi harus antara 1 dan 240 menit';
      expect(Validators.durasiMenit('0'), message);
      expect(Validators.durasiMenit('-5'), message);
      expect(Validators.durasiMenit('241'), message);
      expect(Validators.durasiMenit('1'), isNull);
      expect(Validators.durasiMenit('30'), isNull);
      expect(Validators.durasiMenit('240'), isNull);
      expect(Validators.durasiMenit(' 90 '), isNull);
    });
  });

  group('Validators.namaKendaraan', () {
    test('is required', () {
      expect(Validators.namaKendaraan(null), 'Nama kendaraan wajib diisi');
      expect(Validators.namaKendaraan('  '), 'Nama kendaraan wajib diisi');
      expect(Validators.namaKendaraan('Honda Vario'), isNull);
    });
  });

  group('Validators.matchesConfirmation', () {
    test('only the exact keyword confirms', () {
      expect(Validators.matchesConfirmation('HAPUS'), isTrue);
      expect(Validators.matchesConfirmation(' HAPUS '), isTrue);
      expect(Validators.matchesConfirmation('hapus'), isFalse);
      expect(Validators.matchesConfirmation('HAPUS SEMUA'), isFalse);
      expect(Validators.matchesConfirmation(''), isFalse);
      expect(Validators.matchesConfirmation(null), isFalse);
      expect(Validators.matchesConfirmation('DELETE', keyword: 'DELETE'), isTrue);
    });
  });
}
