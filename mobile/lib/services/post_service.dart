import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../models/post_model.dart';
import 'api_client.dart';

class PostService {
  final Dio _dio = ApiClient.dio;

  // Get all posts (feed)
  Future<List<PostModel>> getAllPosts({int page = 1, int limit = 10}) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/posts',
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final List<dynamic> posts = data['data'] as List<dynamic>? ?? [];

        return posts
            .map((dynamic item) => PostModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to get posts: ${e.message}');
    }
  }

  // Get single post by ID
  Future<PostModel?> getPostById(int id) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/posts/$id',
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        if (data['data'] != null) {
          return PostModel.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } on DioException catch (e) {
      throw Exception('Failed to get post: ${e.message}');
    }
  }

  // Create new post
  Future<PostModel?> createPost({
    required String content,
    List<String>? mediaPaths,
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    try {
      final FormData formData = FormData.fromMap({
        'content': content,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (locationName != null) 'location_name': locationName,
      });

      // Add media files if any
      if (mediaPaths != null && mediaPaths.isNotEmpty) {
        for (int i = 0; i < mediaPaths.length; i++) {
          final String path = mediaPaths[i];
          final String fileName = path.split('/').last;
          final String ext = fileName.split('.').last.toLowerCase();
          
          MediaType mediaType;
          if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
            mediaType = MediaType('image', ext == 'jpg' ? 'jpeg' : ext);
          } else if (['gif'].contains(ext)) {
            mediaType = MediaType('image', 'gif');
          } else if (['mp4', 'webm', 'mov'].contains(ext)) {
            mediaType = MediaType('video', ext == 'mov' ? 'quicktime' : ext);
          } else {
            continue; // Skip unsupported formats
          }

          formData.files.add(MapEntry(
            'media',
            await MultipartFile.fromFile(path, contentType: mediaType),
          ));
        }
      }

      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/posts',
        data: formData,
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        if (data['data'] != null) {
          return PostModel.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Failed to create post');
      }
      throw Exception('Network error: ${e.message}');
    }
  }

  // Delete post
  Future<bool> deletePost(int id) async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        '/api/posts/$id',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Failed to delete post: ${e.message}');
    }
  }

  // Toggle like
  Future<Map<String, dynamic>> toggleLike(int postId) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/posts/$postId/like',
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        return data['data'] as Map<String, dynamic>? ?? {};
      }
      return {};
    } on DioException catch (e) {
      throw Exception('Failed to toggle like: ${e.message}');
    }
  }

  // Get comments
  Future<List<CommentModel>> getComments(int postId, {int page = 1, int limit = 20}) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/posts/$postId/comments',
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final List<dynamic> comments = data['data'] as List<dynamic>? ?? [];

        return comments
            .map((dynamic item) => CommentModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to get comments: ${e.message}');
    }
  }

  // Add comment
  Future<CommentModel?> addComment(int postId, String content) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/posts/$postId/comments',
        data: {'content': content},
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        if (data['data'] != null) {
          return CommentModel.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } on DioException catch (e) {
      throw Exception('Failed to add comment: ${e.message}');
    }
  }

  // Delete comment
  Future<bool> deleteComment(int postId, int commentId) async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        '/api/posts/$postId/comments/$commentId',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Failed to delete comment: ${e.message}');
    }
  }

  // Get my posts
  Future<List<PostModel>> getMyPosts({int page = 1, int limit = 10}) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/posts/me',
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final List<dynamic> posts = data['data'] as List<dynamic>? ?? [];

        return posts
            .map((dynamic item) => PostModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to get my posts: ${e.message}');
    }
  }
}
