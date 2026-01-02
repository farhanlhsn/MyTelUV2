import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../services/akademik_service.dart';

class FormJadwalPenggantiPage extends StatefulWidget {
  const FormJadwalPenggantiPage({super.key});

  @override
  State<FormJadwalPenggantiPage> createState() => _FormJadwalPenggantiPageState();
}

class _FormJadwalPenggantiPageState extends State<FormJadwalPenggantiPage> {
  final AkademikService _akademikService = AkademikService();
  final _formKey = GlobalKey<FormState>();
  
  // Arguments passed from previous page
  late int idKelas;
  late String namaKelas;
  
  // Form fields
  DateTime? _tanggalAsli;
  String _status = 'LIBUR'; // LIBUR or GANTI_JADWAL
  final _alasanController = TextEditingController();
  DateTime? _tanggalGanti;
  final _ruanganController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    idKelas = args['id_kelas'];
    namaKelas = args['nama_kelas'];
  }

  @override
  void dispose() {
    _alasanController.dispose();
    _ruanganController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isOriginalDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        if (isOriginalDate) {
          _tanggalAsli = picked;
        } else {
          _tanggalGanti = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tanggalAsli == null) {
      Get.snackbar('Error', 'Pilih tanggal kelas asli', backgroundColor: Colors.red[100]);
      return;
    }
    if (_status == 'GANTI_JADWAL' && _tanggalGanti == null) {
      Get.snackbar('Error', 'Pilih tanggal pengganti', backgroundColor: Colors.red[100]);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _akademikService.createJadwalPengganti(
        idKelas: idKelas,
        tanggalAsli: _tanggalAsli!,
        status: _status,
        alasan: _alasanController.text,
        tanggalGanti: _status == 'GANTI_JADWAL' ? _tanggalGanti : null,
        ruanganGanti: _status == 'GANTI_JADWAL' && _ruanganController.text.isNotEmpty 
            ? _ruanganController.text 
            : null,
      );

      if (success) {
        Get.back(result: true); // Return result to refresh list
        Get.snackbar(
          'Sukses', 
          'Jadwal pengganti berhasil dibuat',
          backgroundColor: Colors.green[100],
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error', 
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red[100],
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atur Jadwal Pengganti'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kelas: $namaKelas',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              // Tanggal Asli
              const Text('Tanggal Kelas Asli:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context, true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _tanggalAsli != null 
                        ? DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_tanggalAsli!)
                        : 'Pilih Tanggal',
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Status Choice
              const Text('Jenis Perubahan:', style: TextStyle(fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Radio<String>(
                    value: 'LIBUR',
                    groupValue: _status,
                    onChanged: (val) => setState(() => _status = val!),
                    activeColor: const Color(0xFFE63946),
                  ),
                  const Text('Liburkan Kelas'),
                  const SizedBox(width: 16),
                  Radio<String>(
                    value: 'GANTI_JADWAL',
                    groupValue: _status,
                    onChanged: (val) => setState(() => _status = val!),
                    activeColor: const Color(0xFFE63946),
                  ),
                  const Text('Ganti Jadwal'),
                ],
              ),
              
              // Fields specific to GANTI_JADWAL
              if (_status == 'GANTI_JADWAL') ...[
                const SizedBox(height: 16),
                const Text('Tanggal Pengganti:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDate(context, false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _tanggalGanti != null 
                          ? DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_tanggalGanti!)
                          : 'Pilih Tanggal Baru',
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ruanganController,
                  decoration: const InputDecoration(
                    labelText: 'Ruangan Baru (Opsional)',
                    border: OutlineInputBorder(),
                    helperText: 'Kosongkan jika sama dengan ruangan asli',
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Alasan
              TextFormField(
                controller: _alasanController,
                decoration: const InputDecoration(
                  labelText: 'Alasan Perubahan',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (val) => val == null || val.isEmpty ? 'Alasan wajib diisi' : null,
              ),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE63946),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
