import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import '../../services/post_service.dart';
import '../common/location_picker_page.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _contentController = TextEditingController();
  final PostService _postService = PostService();
  final ImagePicker _picker = ImagePicker();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  List<File> _selectedMedia = [];
  bool _isLoading = false;
  String? _locationName;
  String? _userName;

  static const Color primaryColor = Color(0xFFE63946);

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await _storage.read(key: 'nama');
    if (mounted) {
      setState(() {
        _userName = name ?? 'User';
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_isLoading) return;
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1200,
      );
      
      if (images.isNotEmpty) {
        setState(() {
          _selectedMedia.addAll(images.map((img) => File(img.path)));
        });
      }
    } catch (e) {
      _showError('Gagal memilih gambar');
    }
  }

  Future<void> _pickVideo() async {
    if (_isLoading) return;
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      
      if (video != null) {
        setState(() {
          _selectedMedia.add(File(video.path));
        });
      }
    } catch (e) {
      _showError('Gagal memilih video');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _removeMedia(int index) {
    if (_isLoading) return;
    setState(() {
      _selectedMedia.removeAt(index);
    });
  }

  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty) {
      _showError('Tulis sesuatu terlebih dahulu');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _postService.createPost(
        content: _contentController.text.trim(),
        mediaPaths: _selectedMedia.map((f) => f.path).toList(),
        locationName: _locationName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Postingan berhasil dibuat!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        Get.back(result: true);
      }
    } catch (e) {
      _showError('Gagal membuat postingan: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setLocation() async {
    if (_isLoading) return;
    
    final result = await Navigator.push<LocationData>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerPage(
          initialLocation: _locationName,
        ),
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        _locationName = result.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.black87, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Buat Postingan',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _contentController,
              builder: (context, value, child) {
                return ElevatedButton(
                  onPressed: _isLoading || value.text.trim().isEmpty 
                      ? null 
                      : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: primaryColor.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Posting',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // User Info & Content Input
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar & Name
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [primaryColor, primaryColor.withOpacity(0.7)],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.transparent,
                          child: Text(
                            _userName?.isNotEmpty == true ? _userName![0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName ?? 'User',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Posting ke publik',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),

                  // Content Input
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 6,
                    keyboardType: TextInputType.multiline,
                    autofocus: true,
                    enabled: !_isLoading,
                    style: const TextStyle(fontSize: 17, height: 1.5),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Apa yang sedang Anda pikirkan?',
                      hintStyle: TextStyle(fontSize: 17, color: Colors.grey[400]),
                    ),
                  ),

                  // Location Tag
                  if (_locationName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            _locationName!,
                            style: const TextStyle(color: Colors.blue, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _isLoading ? null : () => setState(() => _locationName = null),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Media Preview
                  if (_selectedMedia.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedMedia.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                width: 140,
                                height: 140,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  image: DecorationImage(
                                    image: FileImage(_selectedMedia[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              if (!_isLoading)
                              Positioned(
                                top: 6,
                                right: 16,
                                child: GestureDetector(
                                  onTap: () => _removeMedia(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Actions Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                   _buildAttachmentButton(
                    icon: Icons.photo_library,
                    color: Colors.green,
                    onTap: _pickImages,
                  ),
                  const SizedBox(width: 16),
                  _buildAttachmentButton(
                    icon: Icons.videocam,
                    color: Colors.red,
                    onTap: _pickVideo,
                  ),
                  const SizedBox(width: 16),
                  _buildAttachmentButton(
                    icon: Icons.location_on,
                    color: Colors.blue,
                    onTap: _setLocation,
                  ),
                  const Spacer(),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _contentController,
                    builder: (context, value, child) {
                      return Text(
                        '${value.text.length} karakter',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
