import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/post_model.dart';

void main() {
  group('PostModel', () {
    test('fromJson should parse valid JSON correctly', () {
      final json = {
        'id_post': 1,
        'id_user': 10,
        'content': 'Hello World',
        'media': ['url1', 'url2'],
        'latitude': -6.9,
        'longitude': 107.6,
        'location_name': 'Bandung',
        'createdAt': '2025-01-01T10:00:00.000Z',
        'updatedAt': '2025-01-01T10:00:00.000Z',
        'isLiked': true,
        'likeCount': 5,
        'commentCount': 2,
        'user': {
          'id_user': 10,
          'nama': 'Test User',
          'username': 'testuser',
          'role': 'MAHASISWA'
        }
      };

      final model = PostModel.fromJson(json);

      expect(model.idPost, 1);
      expect(model.content, 'Hello World');
      expect(model.media.length, 2);
      expect(model.latitude, -6.9);
      expect(model.isLiked, true);
      expect(model.user.nama, 'Test User');
    });

    test('fromJson should handle nulls/defaults', () {
      final json = {
        'id_post': 1,
        'id_user': 10,
        'content': 'Hello',
        // Missing optional fields
        'createdAt': '2025-01-01T10:00:00.000Z',
        'updatedAt': '2025-01-01T10:00:00.000Z',
        'user': {
          'id_user': 10,
          'nama': 'Test User',
          'username': 'testuser',
        }
      };

      final model = PostModel.fromJson(json);

      expect(model.media, isEmpty);
      expect(model.latitude, null);
      expect(model.isLiked, false);
      expect(model.likeCount, 0);
    });
  });

  group('UserInfo', () {
    test('fromJson should parse correctly', () {
       final json = {
          'id_user': 10,
          'nama': 'Test User',
          'username': 'testuser',
          'role': 'MAHASISWA'
        };
        final user = UserInfo.fromJson(json);
        expect(user.idUser, 10);
        expect(user.role, 'MAHASISWA');
    });
  });
}
