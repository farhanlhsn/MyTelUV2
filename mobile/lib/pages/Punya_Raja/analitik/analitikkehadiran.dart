import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalitikKehadiranPage extends StatelessWidget {
  const AnalitikKehadiranPage({super.key});

  // Warna utama dari desain
  static const Color primaryColor = Color(0xFFFC5F57);
  // Warna gelap untuk chip waktu
  static const Color darkRedColor = Color(0xFFC14A44);

  @override
  Widget build(BuildContext context) {
    // --- KODE INI TIDAK DIUBAH ---
    return Scaffold(
      body: Stack(
        children: [
          // --- Bagian Atas Merah (Header) ---
          Container(
            height: 150, // Tinggi header
            decoration: const BoxDecoration(
              color: primaryColor,
            ),
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(top: 40, left: 10),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20.0, 
                  ),
                  onPressed: () {
                    // Fungsi untuk kembali
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                // PERUBAHAN: Judul diubah
                const Text(
                  'Analitik Kehadiran Anomali',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // --- Bagian Konten Utama (putih) ---
          Padding(
            padding: const EdgeInsets.only(top: 100), // Mulai konten dari bawah header
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              // --- KODE INI TIDAK DIUBAH ---
              // (SingleChildScrollView dan Column)
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0), // Padding ini penting
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 10),
                    
                    // --- Widget 1: Horizontal Time Selector (Sama seperti Analitik Parkir) ---
                    _buildTimeSelector(), // Fungsi ini sudah diubah
                    
                    const SizedBox(height: 20),

                    // --- WIDGET BARU: Info Chip ---
                    _buildInfoChip("Kelas : IF 47 06"),
                    const SizedBox(height: 12),
                    _buildInfoChip("Mata Kuliah : Teori Peluang"),

                    const SizedBox(height: 30),
                    
                    // --- PERUBAHAN UTAMA DI SINI ---
                    SizedBox(
                      height: 220, // Diperbesar sedikit agar label Y tidak terpotong
                      width: double.infinity,
                      child: AspectRatio(
                        aspectRatio: 1.7, 
                        child: LineChart(
                          LineChartData(
                            // Minimal dan Maksimal nilai untuk sumbu X (horizontal) dan Y (vertikal)
                            minX: 0,
                            maxX: 6, // 7 titik data, dari 0 sampai 6
                            minY: 0,
                            maxY: 200, // Maksimal nilai di Y adalah 200

                            // Atur border seperti di gambar
                            borderData: FlBorderData(
                              show: true,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.withOpacity(0.5), width: 1), // Garis bawah
                                left: BorderSide(color: Colors.grey.withOpacity(0.5), width: 1), // Garis kiri
                                right: BorderSide(color: Colors.transparent), // Transparan
                                top: BorderSide(color: Colors.transparent), // Transparan
                              ),
                            ),
                            
                            // Atur data garisnya
                            lineBarsData: [
                              LineChartBarData(
                                // Data dummy disesuaikan dengan gambar
                                spots: const [
                                  FlSpot(0, 100), // JAN
                                  FlSpot(1, 120), // FEB
                                  FlSpot(2, 150), // MAR
                                  FlSpot(3, 170), // APR
                                  FlSpot(4, 180), // MEI
                                  FlSpot(5, 170), // JUN
                                  FlSpot(6, 160), // JUL
                                ],
                                isCurved: true, // Membuat garis melengkung (smooth)
                                // Warna gradient seperti di desain
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFC5F57), Color.fromARGB(255, 118, 148, 237)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true, // Tampilkan titik
                                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                    radius: 5, // Ukuran titik
                                    color: Colors.blueAccent, // Warna titik di grafik
                                    strokeColor: Colors.white, // Warna border titik
                                    strokeWidth: 2,
                                  ),
                                ), 
                                belowBarData: BarAreaData(
                                  show: true, // Tampilkan area di bawah garis
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFFC5F57).withOpacity(0.3),
                                      const Color(0xFF8A2387).withOpacity(0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                            
                            // Konfigurasi Title/Label Sumbu X dan Y
                            titlesData: FlTitlesData(
                              show: true,
                              // Label Sumbu Kanan & Atas disembunyikan
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              
                              // Konfigurasi Label Sumbu Bawah (X-axis)
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30, // Ruang untuk label
                                  interval: 1, // Interval setiap titik data
                                  getTitlesWidget: (value, meta) {
                                    const style = TextStyle(
                                      color: Color(0xff68737d),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    );
                                    String text;
                                    switch (value.toInt()) {
                                      case 0: text = 'JAN'; break;
                                      case 1: text = 'FEB'; break;
                                      case 2: text = 'MAR'; break;
                                      case 3: text = 'APR'; break;
                                      case 4: text = 'MAY'; break;
                                      case 5: text = 'JUN'; break;
                                      case 6: text = 'JUL'; break;
                                      default: text = ''; break;
                                    }
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      space: 8.0,
                                      child: Text(text, style: style),
                                    );
                                  },
                                ),
                              ),
                              
                              // Konfigurasi Label Sumbu Kiri (Y-axis)
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40, // Ruang untuk label
                                  interval: 50, // Interval setiap 50 (0, 50, 100, 150, 200)
                                  getTitlesWidget: (value, meta) {
                                    const style = TextStyle(
                                      color: Color(0xff67727d),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    );
                                    String text;
                                    if (value == 0) {
                                      text = '0';
                                    } else if (value == 50) {
                                      text = '50';
                                    } else if (value == 100) {
                                      text = '100';
                                    } else if (value == 150) {
                                      text = '150';
                                    } else if (value == 200) {
                                      text = '200';
                                    } else {
                                      return Container(); // Sembunyikan label lain
                                    }
                                    return Text(text, style: style, textAlign: TextAlign.left);
                                  },
                                ),
                              ),
                            ),
                            
                            // Konfigurasi Grid (garis horizontal)
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false, // Sembunyikan garis vertikal
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey.withOpacity(0.2), // Warna garis horizontal
                                  strokeWidth: 1,
                                );
                              },
                              horizontalInterval: 50, // Interval garis horizontal setiap 50
                            ),

                            // Legend (Label "Data" di bawah chart)
                            // Anda bisa membuat custom legend di luar LineChart jika ingin lebih banyak kontrol.
                            // Untuk saat ini, kita akan membuat placeholder yang mirip.
                            extraLinesData: ExtraLinesData(
                                horizontalLines: [],
                                verticalLines: [],
                                extraLinesOnTop: false
                            ),
                            // FlChart tidak memiliki legend bawaan yang persis seperti itu.
                            // Kita bisa membuatnya secara manual di luar chart jika diperlukan.
                          ),
                        ),
                      ),
                    ),
                    
                    // --- Kustomisasi Legend "Data" (Manual) ---
                    // Karena fl_chart tidak memiliki legend bawaan seperti di gambar,
                    // kita akan membuatnya secara manual di luar chart.
                    const SizedBox(height: 10), // Jarak antara chart dan legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 18,
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.blueAccent.withOpacity(0.5), // Warna mirip area bawah grafik
                            border: Border.all(color: Colors.grey.withOpacity(0.5)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Data',
                          style: TextStyle(
                            color: Color(0xff68737d),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // --- AKHIR DARI PERUBAHAN ---
                    
                    const SizedBox(height: 30),

                    // --- WIDGET BARU: Tombol Edit & Label ---
                    _buildEditHeader(),

                    const SizedBox(height: 15),

                    // --- WIDGET BARU: Daftar Data ---
                    _buildDataTable(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- KODE DI BAWAH INI TIDAK DIUBAH SAMA SEKALI ---

  // --- PERUBAHAN 1: Menghapus logika 'isSelected' ---
  Widget _buildTimeSelector() {
    final List<Map<String, String>> times = [
      {"day": "Fri", "date": "22", "time": "17:00"},
      {"day": "Fri", "date": "22", "time": "18:00"},
      {"day": "Fri", "date": "22", "time": "19:00"},
      {"day": "Fri", "date": "22", "time": "20:00"},
      {"day": "Fri", "date": "22", "time": "21:00"},
    ];

    return SizedBox(
      height: 150, 
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        
        // --- PERUBAHAN ALIGNMENT ---
        // Padding 'SingleChildScrollView' (induk) adalah 20.
        // Jika kita ingin item pertama tidak menempel di kiri, kita
        // bisa set padding ListView.builder. Tapi di kasus ini,
        // padding 20 dari induk sudah cukup.
        
        // Kita Hapus 'padding' dari item, dan pindahkan ke ListView
        // agar item pertama dan terakhir punya spasi.
        // padding: const EdgeInsets.symmetric(horizontal: 20.0), // Batalkan ini, karena induk sudah punya padding 20
        
        itemCount: times.length,
        itemBuilder: (context, index) {
          final item = times[index];
          // final bool isSelected = index == 0; // <-- LOGIKA INI DIHAPUS
          
          return _buildTimeChip(
            item['day']!,
            item['date']!,
            item['time']!,
            // isSelected, // <-- PARAMETER INI DIHAPUS
          );
        },
      ),
    );
  }

  // --- PERUBAHAN 2: Menghapus 'isSelected' dan 'unselectedGradient' ---
  Widget _buildTimeChip(String day, String date, String time) { // <-- Parameter 'isSelected' dihapus
    
    // HANYA ADA SATU GRADASI
    final Gradient cardGradient = LinearGradient(
      colors: [
        primaryColor.withOpacity(1.0), // Menggunakan gradasi yang Anda set sebelumnya
        const Color(0xFF130B2B).withOpacity(0.78), 
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    
    // HAPUS 'unselectedGradient'
    // final Gradient unselectedGradient = ... (DIHAPUS)
    
    // Bayangan untuk kartu
    final List<BoxShadow> cardShadow = [
      BoxShadow(
        color: darkRedColor.withOpacity(0.3),
        blurRadius: 5,
        offset: const Offset(0, 3),
      )
    ];

    return Padding(
      // --- PERUBAHAN ALIGNMENT ---
      // Agar item pertama (kiri) selaras, kita beri padding kiri 
      // HANYA jika itu item pertama (index == 0).
      // TAPI cara termudah adalah memberi padding pada ListView.builder
      // Karena ListView.builder sudah ada di dalam SingleChildScrollView
      // yang punya padding 20, kita tidak perlu padding kiri lagi.
      // Kita hanya perlu padding kanan antar item.
      
      padding: const EdgeInsets.only(right: 12.0), // Tetap gunakan ini
      
      child: Column(
        children: [
          // --- KARTU TANGGAL (BESAR) ---
          Container(
            width: 60,
            height: 95,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              // Terapkan HANYA SATU gradasi
              gradient: cardGradient, // <-- DIUBAH
              boxShadow: cardShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10), // Jarak antar kartu

          // --- KARTU WAKTU (KECIL) ---
          Container(
            width: 55, // Sedikit lebih kecil dari kartu atas
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              // Terapkan HANYA SATU gradasi
              gradient: cardGradient, // <-- DIUBAH
              boxShadow: cardShadow,
            ),
            child: Text(
              time,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // --- KODE DI BAWAH INI TIDAK DIUBAH SAMA SEKALI ---

  // WIDGET BARU: Helper untuk Chip Info (Kelas & Matkul)
  Widget _buildInfoChip(String text) {
  // ... (Sama seperti kode Anda)
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // Border merah seperti di desain
        border: Border.all(color: primaryColor.withOpacity(0.7), width: 1.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  // WIDGET BARU: Helper untuk header "EDIT" dan "Struktur Data"
  Widget _buildEditHeader() {
  // ... (Sama seperti kode Anda)
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Tombol EDIT
        ElevatedButton(
          onPressed: () {
            // Logika saat tombol edit ditekan
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20), // Sangat rounded
            ),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
          ),
          child: const Text(
            'EDIT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        // Label "Struktur Data"
        const Text(
          'Struktur Data',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black38,
          ),
        ),
      ],
    );
  }

  // WIDGET BARU: Helper untuk tabel/daftar data anomali
  Widget _buildDataTable() {
  // ... (Sama seperti kode Anda)
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.7), width: 1.5),
      ),
      // Gunakan Column untuk menumpuk baris-baris data
      child: Column(
        children: [
          // Baris data (buatkan helper-nya)
          _buildDataRow("Daniandra Prayudi...", "14 April 2024", "HADIR", Colors.black),
          const Divider(height: 1, indent: 15, endIndent: 15), // Garis pemisah
          _buildDataRow("Daniandra Prayudi...", "14 April 2024", "SAKIT", Colors.black),
          const Divider(height: 1, indent: 15, endIndent: 15),
          _buildDataRow("Daniandra Prayudi...", "14 April 2024", "DISPEN", Colors.black),
          const Divider(height: 1, indent: 15, endIndent: 15),
          _buildDataRow("Daniandra Prayudi...", "14 April 2024", "ALPA", Colors.black),
        ],
      ),
    );
  }

  // WIDGET BARU: Helper untuk satu baris data
  Widget _buildDataRow(String name, String date, String status, Color statusColor) {
  // ... (Sama seperti kode Anda)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Nama (dibuat 'Expanded' agar mendorong sisanya ke kanan)
          Expanded(
            flex: 3, // Beri porsi 3
            child: Text(
              name,
              style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis, // Jika nama terlalu panjang
            ),
          ),
          // Tanggal
          Expanded(
            flex: 2, // Beri porsi 2
            child: Text(
              date,
              textAlign: TextAlign.center, // Tengah
              style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w700),
            ),
          ),
          // Status
          Expanded(
            flex: 1, // Beri porsi 1
            child: Text(
              status,
              textAlign: TextAlign.right, // Rata kanan
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}