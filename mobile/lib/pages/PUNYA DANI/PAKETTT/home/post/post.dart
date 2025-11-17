import 'package:flutter/material.dart';

class PostPage extends StatefulWidget {
  // --- BARU: Callback untuk memberi tahu Induk agar menutup ---
  // Halaman induk yang menampilkan PostPage ini harus menyediakan fungsi ini,
  // misalnya: () => _tabController.animateTo(0);
  final VoidCallback? onCloseTapped;

  const PostPage({super.key, this.onCloseTapped});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final _contentController = TextEditingController();
  bool _isPostButtonEnabled = false;

  // Data dummy tetap sama
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

    // Panggil callback 'close' jika ada
    widget.onCloseTapped?.call();
  }

  // --- WIDGET BUILDER BARU ---

  /// Membangun AppBar bagian atas
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      // Kita gunakan warna putih dan buang bayangan
      backgroundColor: Colors.white,
      elevation: 0,
      // Tambahkan garis bawah tipis seperti desain Anda
      shape: Border(
        bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
      ),
      // Tombol 'Close' di kiri
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black87),
        onPressed: widget.onCloseTapped ?? () {
          // Fallback jika tidak ada callback (opsional)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Callback "Close" tidak diatur.')),
          );
        },
      ),
      // Tombol 'Posting' di kanan
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: FilledButton(
            onPressed: _isPostButtonEnabled ? _submitPost : null,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Posting',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// Membangun bagian body utama (Info User dan Input Teks)
  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      // Memberi sedikit padding bawah agar tidak terlalu mepet action bar
      // saat di-scroll ke paling bawah
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildUserInfo(),
          const SizedBox(height: 16),
          _buildContentInput(),
        ],
      ),
    );
  }

  /// Membangun info profil pengguna
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _dummyUserHandle,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Membangun field input teks
  Widget _buildContentInput() {
    return TextFormField(
      controller: _contentController,
      maxLines: null, // Memungkinkan input multi-baris tak terbatas
      keyboardType: TextInputType.multiline,
      autofocus: true, // Langsung fokus saat halaman dibuka
      style: const TextStyle(fontSize: 18, height: 1.5),
      decoration: InputDecoration(
        border: InputBorder.none, // Tidak ada garis bawah
        hintText: "Apa yang sedang Anda pikirkan?",
        hintStyle: TextStyle(
          fontSize: 18,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  /// Membangun Action Bar bagian bawah (Foto, Video, dll.)
  Widget _buildBottomActions(BuildContext context) {
    // Kita bungkus dengan SafeArea agar tidak tembus 'home bar' (navigasi gestur)
    return SafeArea(
      // Hanya terapkan SafeArea untuk bagian bawah
      bottom: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(Icons.photo_library, "Foto", Colors.green),
            _buildActionButton(Icons.videocam, "Video", Colors.red),
            _buildActionButton(Icons.location_on, "Lokasi", Colors.blue),
            _buildActionButton(Icons.gif_box, "GIF", Colors.purple),
          ],
        ),
      ),
    );
  }

  /// Widget helper untuk tombol-tombol di Action Bar (sama seperti kode Anda)
  Widget _buildActionButton(IconData icon, String label, Color color) {
    return TextButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fitur "$label" belum diimplementasi.')),
        );
      },
      icon: Icon(icon, color: color, size: 24),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(
        foregroundColor: Colors.black54,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // --- BUILD UTAMA YANG SUDAH DI-RENOVASI ---
  @override
  Widget build(BuildContext context) {
    // KITA MENGGUNAKAN SCAFFOLD!
    // Ini adalah kunci untuk membuat semuanya "gacor".
    return Scaffold(
      backgroundColor: Colors.white,
      
      // Menggunakan AppBar standar
      appBar: _buildAppBar(context),
      
      // Body yang bisa di-scroll
      body: _buildBody(context),
      
      // Menempatkan action bar Anda di slot bottomNavigationBar.
      // Flutter akan OTOMATIS mengangkatnya ke atas keyboard
      // dengan animasi yang sempurna.
      bottomNavigationBar: _buildBottomActions(context),
      
      // (PENTING) Properti ini (default-nya true) adalah yang
      // "mengerutkan" body saat keyboard muncul.
      resizeToAvoidBottomInset: true,
    );
  }
}