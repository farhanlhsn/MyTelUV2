import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/post_service.dart';
import '../../models/post_model.dart';
import 'create_post_page.dart';
import 'comments_page.dart';

class PostPage extends StatefulWidget {
  final VoidCallback? onCloseTapped;

  const PostPage({super.key, this.onCloseTapped});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final PostService _postService = PostService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ScrollController _scrollController = ScrollController();
  
  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _limit = 10;
  
  String? _errorMessage;
  int? _currentUserId;
  String? _currentUserName;

  static const Color primaryColor = Color(0xFFE63946);

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      _loadMorePosts();
    }
  }

  Future<void> _loadCurrentUser() async {
    final userId = await _storage.read(key: 'id_user');
    final userName = await _storage.read(key: 'nama');
    if (userId != null) {
      if (mounted) {
        setState(() {
          _currentUserId = int.tryParse(userId);
          _currentUserName = userName ?? 'User';
        });
      }
    }
  }

  Future<void> _loadPosts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
        _hasMore = true;
      });

      final posts = await _postService.getAllPosts(page: 1, limit: _limit);
      
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
          // If we got fewer items than the limit, we've reached the end
          if (posts.length < _limit) {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final posts = await _postService.getAllPosts(page: nextPage, limit: _limit);

      if (mounted) {
        setState(() {
          if (posts.isEmpty) {
            _hasMore = false;
          } else {
            _posts.addAll(posts);
            _currentPage = nextPage;
            if (posts.length < _limit) {
              _hasMore = false;
            }
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // Optionally show a snackbar for error loading more
        });
      }
    }
  }

  Future<void> _toggleLike(int postId) async {
    try {
      final result = await _postService.toggleLike(postId);
      final bool isLiked = result['isLiked'] as bool? ?? false;
      final int likeCount = result['likeCount'] as int? ?? 0;

      if (mounted) {
        setState(() {
          final index = _posts.indexWhere((p) => p.idPost == postId);
          if (index != -1) {
            final oldPost = _posts[index];
            _posts[index] = PostModel(
              idPost: oldPost.idPost,
              idUser: oldPost.idUser,
              content: oldPost.content,
              media: oldPost.media,
              latitude: oldPost.latitude,
              longitude: oldPost.longitude,
              locationName: oldPost.locationName,
              createdAt: oldPost.createdAt,
              updatedAt: oldPost.updatedAt,
              user: oldPost.user,
              isLiked: isLiked,
              likeCount: likeCount,
              commentCount: oldPost.commentCount,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deletePost(int postId) async {
    try {
      await _postService.deletePost(postId);
      if (mounted) {
        setState(() {
          _posts.removeWhere((p) => p.idPost == postId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Postingan dihapus'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteConfirmation(int postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Postingan?'),
        content: const Text('Apakah Anda yakin ingin menghapus postingan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost(postId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _navigateToCreatePost() async {
    final result = await Get.to(() => const CreatePostPage());
    if (result == true) {
      _loadPosts(); // Reloads first page
    }
  }

  void _sharePost(PostModel post) {
    final String content = '${post.user.nama} memposting:\n\n${post.content}${post.locationName != null ? '\n\n📍 ${post.locationName}' : ''}\n\nVia MyTelUV2';
    Share.share(content);
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}h lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}j lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m lalu';
    } else {
      return 'Baru saja';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar with Create Post Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Postingan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Create Post Box
                  GestureDetector(
                    onTap: _navigateToCreatePost,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: primaryColor,
                            child: Text(
                              _currentUserName?.isNotEmpty == true 
                                  ? _currentUserName![0].toUpperCase() 
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Apa yang sedang Anda pikirkan?',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Posting',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Post List
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_errorMessage != null && _posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat postingan',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: _loadPosts,
              ),
            ],
          ),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.article_outlined, size: 60, color: primaryColor.withOpacity(0.6)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Belum Ada Postingan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Jadilah yang pertama membuat postingan!',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Buat Postingan Pertama'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: _navigateToCreatePost,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _loadPosts,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 100), // Extra bottom padding for navbar
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(color: primaryColor, strokeWidth: 3),
              ),
            );
          }
          return _buildPostCard(_posts[index]);
        },
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    final bool isOwner = _currentUserId == post.idUser;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.transparent,
                    child: Text(
                      post.user.nama.isNotEmpty ? post.user.nama[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.user.nama,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '@${post.user.username}',
                            style: TextStyle(color: primaryColor.withOpacity(0.8), fontSize: 12),
                          ),
                          Text(
                            ' • ${_formatTimeAgo(post.createdAt)}',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'delete') _showDeleteConfirmation(post.idPost);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Hapus', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),

          // Media (if any)
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: SizedBox(
                height: 250,
                width: double.infinity,
                child: post.media.length == 1
                    ? CachedNetworkImage(
                        imageUrl: post.media[0],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: CircularProgressIndicator(color: primaryColor),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 40),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: post.media.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 200,
                            margin: EdgeInsets.only(right: index < post.media.length - 1 ? 8 : 0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: post.media[index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: CircularProgressIndicator(color: primaryColor),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, size: 40),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],

          // Location (if any)
          if (post.locationName != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        post.locationName!,
                        style: const TextStyle(color: Colors.blue, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Actions
          Container(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                // Like Button
                _buildActionButton(
                  icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${post.likeCount}',
                  color: post.isLiked ? Colors.red : Colors.grey.shade600,
                  onTap: () => _toggleLike(post.idPost),
                ),
                // Comment Button
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: '${post.commentCount}',
                  color: Colors.grey.shade600,
                  onTap: () async {
                    final newCount = await Get.to(() => CommentsPage(post: post));
                    if (newCount != null) {
                      setState(() {
                        final index = _posts.indexWhere((p) => p.idPost == post.idPost);
                        if (index != -1) {
                          final oldPost = _posts[index];
                          _posts[index] = PostModel(
                            idPost: oldPost.idPost,
                            idUser: oldPost.idUser,
                            content: oldPost.content,
                            media: oldPost.media,
                            latitude: oldPost.latitude,
                            longitude: oldPost.longitude,
                            locationName: oldPost.locationName,
                            createdAt: oldPost.createdAt,
                            updatedAt: oldPost.updatedAt,
                            user: oldPost.user,
                            isLiked: oldPost.isLiked,
                            likeCount: oldPost.likeCount,
                            commentCount: newCount as int,
                          );
                        }
                      });
                    }
                  },
                ),
                // Share Button
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Bagikan',
                  color: Colors.grey.shade600,
                  onTap: () => _sharePost(post),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}