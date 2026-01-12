import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/user.dart';

void main() {
  group('UserModel', () {
    test('fromMap should return a valid UserModel', () {
      final map = {
        'id_user': 1,
        'username': 'testuser',
        'nama': 'Test User',
        'role': 'MAHASISWA',
      };

      final user = UserModel.fromMap(map);

      expect(user.idUser, 1);
      expect(user.username, 'testuser');
      expect(user.nama, 'Test User');
      expect(user.role, 'MAHASISWA');
    });

    test('fromMap should handle missing fields/fallback', () {
       // Assuming fallback behavior is desired based on fromMap implementation 
       // (e.g. ?? 0 or ?? '')
       final map = <String, dynamic>{};
       
       final user = UserModel.fromMap(map);
       
       expect(user.idUser, 0); // Default int fallback
       expect(user.username, '');
       expect(user.nama, '');
       expect(user.role, '');
    });
  });
}
