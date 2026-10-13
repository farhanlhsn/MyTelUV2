import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../common/error_retry_view.dart';
import 'comments_page.dart';

/// Route target of a social notification: only the post id is known (`Get.arguments['id_post']`),
/// so the post is fetched first and then shown in the comments page.
class PostCommentsRoutePage extends StatefulWidget {
  /// Loads a post by id; the real [PostService] unless a test replaces it.
  final Future<PostModel?> Function(int idPost)? loadPost;

  /// The post id; read from `Get.arguments` when not given.
  final int? idPost;

  const PostCommentsRoutePage({super.key, this.loadPost, this.idPost});

  @override
  State<PostCommentsRoutePage> createState() => _PostCommentsRoutePageState();
}

class _PostCommentsRoutePageState extends State<PostCommentsRoutePage> {
  PostModel? _post;
  bool _isLoading = true;
  String? _errorMessage;

  /// The post is gone (deleted, or the id is no good): asking again would not change the answer.
  bool _notFound = false;

  static const String _notFoundMessage = 'Postingan tidak ditemukan atau sudah dihapus.';

  int? get _idPost {
    if (widget.idPost != null) return widget.idPost;
    final Object? arguments = Get.arguments;
    final Object? raw = arguments is Map ? arguments['id_post'] : null;
    return raw is int ? raw : int.tryParse('$raw');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int? idPost = _idPost;
    if (idPost == null) {
      setState(() {
        _isLoading = false;
        _notFound = true;
        _errorMessage = _notFoundMessage;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _notFound = false;
      _errorMessage = null;
    });

    try {
      final Future<PostModel?> Function(int) loader =
          widget.loadPost ?? PostService().getPostById;
      final PostModel? post = await loader(idPost);
      if (!mounted) return;
      setState(() {
        _post = post;
        _isLoading = false;
        _notFound = post == null;
        _errorMessage = post == null ? _notFoundMessage : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Tidak dapat memuat postingan. Periksa koneksi Anda lalu coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PostModel? post = _post;
    if (post != null) return CommentsPage(post: post);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Komentar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE63946),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE63946)),
            )
          : ErrorRetryView(
              title: _notFound ? 'Postingan tidak tersedia' : 'Gagal membuka postingan',
              message: _errorMessage ?? _notFoundMessage,
              // Nothing to retry for a post that is gone
              onRetry: _notFound ? null : _load,
            ),
    );
  }
}
