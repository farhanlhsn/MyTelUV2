import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/post_model.dart';
import 'package:mobile/services/post_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<Dio>()])
import 'post_service_test.mocks.dart';
import 'support/stub_http_adapter.dart';

/// No answer at all: the phone is offline.
class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Tidak ada koneksi',
    );
  }

  @override
  void close({bool force = false}) {}
}

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

    group('getPostById', () {
      test('returns the post', () async {
        final adapter = StubHttpAdapter(200, <String, dynamic>{
          'status': 'success',
          'data': <String, dynamic>{
            'id_post': 5,
            'id_user': 10,
            'content': 'Halo',
            'media': <dynamic>[],
            'createdAt': '2025-01-01T10:00:00.000Z',
            'updatedAt': '2025-01-01T10:00:00.000Z',
            'user': <String, dynamic>{'id_user': 10, 'nama': 'User', 'username': 'u'},
            'isLiked': false,
            'likeCount': 0,
            'commentCount': 0,
          },
        });

        final PostModel? post = await PostService(dio: adapter.dio()).getPostById(5);

        expect(post?.content, 'Halo');
        expect(adapter.lastRequest!.path, '/api/v1/posts/5');
      });

      test('a deleted (or never existing) post is null, not an error', () async {
        final adapter = StubHttpAdapter(404, <String, dynamic>{
          'status': 'error',
          'message': 'Post tidak ditemukan',
        });

        final PostModel? post = await PostService(dio: adapter.dio()).getPostById(5);

        expect(post, isNull);
      });

      test('a server error is still an error', () async {
        final adapter = StubHttpAdapter(500, <String, dynamic>{
          'status': 'error',
          'message': 'Terjadi kesalahan',
        });

        await expectLater(
          PostService(dio: adapter.dio()).getPostById(5),
          throwsA(isA<Exception>()),
        );
      });

      test('a connection failure is still an error', () async {
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
          ..httpClientAdapter = _FailingAdapter();

        await expectLater(
          PostService(dio: dio).getPostById(5),
          throwsA(isA<Exception>()),
        );
      });
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
