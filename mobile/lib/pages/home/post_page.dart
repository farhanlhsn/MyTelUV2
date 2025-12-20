import 'package:flutter/material.dart';

class PostPage extends StatefulWidget {
  // Callback untuk memberi tahu Induk agar menutup
  final VoidCallback? onCloseTapped;

  const PostPage({super.key, this.onCloseTapped});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final _contentController = TextEditingController();
  bool _isPostButtonEnabled = false;

  // Data dummy
  final String _dummyUserName = "John Doe";
  final String _dummyUserHandle = "@johndoe";
  final Widget _dummyProfileAvatar = const CircleAvatar(
    backgroundColor: Colors.blueAccent,
    foregroundColor: Colors.white,
    child: Icon(Icons.person, size: 28),
  );

  @override
  void initState() {
    super.initState();
    _contentController.addListener(() {
      setState(() {
        _isPostButtonEnabled = _contentController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _submitPost() {
    if (!_isPostButtonEnabled) return;
    final String content = _contentController.text;
    print('Postingan Baru: $content');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Postingan berhasil dibuat!'),
        backgroundColor: Colors.green,
      ),
    );
    _contentController.clear();
    widget.onCloseTapped?.call();
  }

  // --- LOGIKA BARU UNTUK LAMPIRAN ---

  /// Fungsi untuk memunculkan opsi Foto/Video/dll dalam Bottom Sheet
  void _showAttachmentOptions() {
    // Menutup keyboard dulu agar tampilan lebih rapi
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Transparan agar bisa kita styling sendiri
      builder: (BuildContext ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ukuran menyesuaikan isi
            children: [
              // Garis kecil di atas (handle bar)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                "Tambahkan ke postingan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Grid menu opsi
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   _buildOptionItem(Icons.photo_library, "Foto", Colors.green),
                   _buildOptionItem(Icons.videocam, "Video", Colors.red),
                   _buildOptionItem(Icons.location_on, "Lokasi", Colors.blue),
                   _buildOptionItem(Icons.gif_box, "GIF", Colors.purple),
                ],
              ),
              const SizedBox(height: 20), // Jarak aman bawah
            ],
          ),
        );
      },
    );
  }

  /// Widget helper untuk item di dalam Modal
  Widget _buildOptionItem(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Tutup modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fitur "$label" dipilih.')),
        );
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1), // Warna background tipis
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // --- WIDGET BUILDER ---

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: Border(
        bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
      ),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black87),
        onPressed: widget.onCloseTapped,
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: FilledButton(
            onPressed: _isPostButtonEnabled ? _submitPost : null,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Posting', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildUserInfo(),
          const SizedBox(height: 16),
          _buildContentInput(),
          // Tambahan ruang kosong di bawah agar teks tidak tertutup FAB
          const SizedBox(height: 80), 
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dummyProfileAvatar,
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dummyUserName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _dummyUserHandle,
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContentInput() {
    return TextFormField(
      controller: _contentController,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      autofocus: true,
      style: const TextStyle(fontSize: 18, height: 1.5),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: "Apa yang sedang Anda pikirkan?",
        hintStyle: TextStyle(fontSize: 18, color: Colors.grey[600]),
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: _buildBody(context),
      
      // Bungkus FloatingActionButton dengan Padding
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0, right: 10.0), 
        child: FloatingActionButton(
          onPressed: _showAttachmentOptions,
          backgroundColor: Color(0xFFE63946),
          elevation: 2,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      
      resizeToAvoidBottomInset: true,
    );
  }
}