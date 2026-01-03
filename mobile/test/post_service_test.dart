import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/post_model.dart';
import 'package:mobile/services/post_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<Dio>()])
import 'post_service_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late PostService postService;

  setUp(() {
    mockDio = MockDio();
    postService = PostService(dio: mockDio);
  });

  group('PostService', () {
    test('getAllPosts should return list of PostModel on success', () async {
      final mockData = [
        {
            'id_post': 1,
            'id_user': 10,
            'content': 'Test Feed',
            'media': [],
            'createdAt': '2025-01-01T10:00:00.000Z',
            'updatedAt': '2025-01-01T10:00:00.000Z',
            'user': {'id_user':10, 'nama':'User', 'username':'u'},
            'isLiked': false, 'likeCount':0, 'commentCount':0
        }
      ];

      when(mockDio.get(any, queryParameters: anyNamed('queryParameters')))
        .thenAnswer((_) async => Response(
            data: {'status': 'success', 'data': mockData},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/posts'),
      ));

      final result = await postService.getAllPosts();

      expect(result.length, 1);
      expect(result.first.content, 'Test Feed');
    });

    test('createPost should return PostModel on success (no media)', () async {
      final mockData = {
          'id_post': 2,
          'id_user': 10,
          'content': 'New Post',
          'media': [],
          'createdAt': '2025-01-01T10:00:00.000Z',
          'updatedAt': '2025-01-01T10:00:00.000Z',
          'user': {'id_user':10, 'nama':'User', 'username':'u'},
          'isLiked': false, 'likeCount':0, 'commentCount':0
      };

      when(mockDio.post(any, data: anyNamed('data')))
        .thenAnswer((_) async => Response(
            data: {'status': 'success', 'data': mockData},
            statusCode: 201,
            requestOptions: RequestOptions(path: '/api/posts'),
      ));

      final result = await postService.createPost(content: 'New Post');
      
      expect(result, isNotNull);
      expect(result!.content, 'New Post');
    });

    test('toggleLike should return update data', () async {
        final mockData = {'likes': 10, 'isLiked': true};
        
        when(mockDio.post(any))
        .thenAnswer((_) async => Response(
            data: {'status': 'success', 'data': mockData},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/posts/1/like'),
        ));

        final result = await postService.toggleLike(1);
        expect(result['likes'], 10);
        expect(result['isLiked'], true);
    });
  });
}
