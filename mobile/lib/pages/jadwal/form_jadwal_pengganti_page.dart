import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/akademik_service.dart';
import '../../utils/date_helper.dart';
import '../../utils/error_helper.dart';
import '../../utils/jadwal_pengganti_helper.dart';
import '../../utils/app_theme.dart';

class FormJadwalPenggantiPage extends StatefulWidget {
  /// For tests; the app uses the default one.
  final AkademikService? akademikService;

  const FormJadwalPenggantiPage({super.key, this.akademikService});

  @override
  State<FormJadwalPenggantiPage> createState() => _FormJadwalPenggantiPageState();
}

class _FormJadwalPenggantiPageState extends State<FormJadwalPenggantiPage> {
  late final AkademikService _akademikService;
  final _formKey = GlobalKey<FormState>();
  
  // Arguments passed from previous page
  late int idKelas;
  late String namaKelas;
  
  // Form fields
  DateTime? _tanggalAsli;
  String _status = 'LIBUR'; // LIBUR or GANTI_JADWAL
  final _alasanController = TextEditingController();
  DateTime? _tanggalGanti;
  TimeOfDay? _jamMulaiGanti;
  TimeOfDay? _jamBerakhirGanti;
  String? _jamError;
  final _ruanganController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _akademikService = widget.akademikService ?? AkademikService();
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

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _jamMulaiGanti : _jamBerakhirGanti) ??
          const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _jamMulaiGanti = picked;
        } else {
          _jamBerakhirGanti = picked;
        }
        // The pair is only checked once both are picked: with one still empty there is nothing to
        // compare yet, and "Pilih jam ..." is for the submit. An error of an earlier submit stays
        // until the pair is complete.
        if (_jamMulaiGanti != null && _jamBerakhirGanti != null) {
          _jamError = validateJamGanti(_jamMulaiGanti, _jamBerakhirGanti);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tanggalAsli == null) {
      ErrorHelper.showError('Pilih tanggal kelas asli');
      return;
    }
    if (_status == 'GANTI_JADWAL' && _tanggalGanti == null) {
      ErrorHelper.showError('Pilih tanggal pengganti');
      return;
    }
    if (_status == 'GANTI_JADWAL') {
      final String? jamError = validateJamGanti(_jamMulaiGanti, _jamBerakhirGanti);
      setState(() => _jamError = jamError);
      if (jamError != null) return;
    }

    setState(() => _isLoading = true);

    try {
      final bool gantiJadwal = _status == 'GANTI_JADWAL';
      final success = await _akademikService.createJadwalPengganti(
        idKelas: idKelas,
        tanggalAsli: _tanggalAsli!,
        status: _status,
        alasan: _alasanController.text,
        tanggalGanti: gantiJadwal ? _tanggalGanti : null,
        ruanganGanti: gantiJadwal && _ruanganController.text.isNotEmpty
            ? _ruanganController.text
            : null,
        jamMulaiGanti: gantiJadwal && _jamMulaiGanti != null
            ? formatJamHHmm(_jamMulaiGanti!)
            : null,
        jamBerakhirGanti: gantiJadwal && _jamBerakhirGanti != null
            ? formatJamHHmm(_jamBerakhirGanti!)
            : null,
      );

      if (success) {
        Get.back(result: true); // Return result to refresh list
        ErrorHelper.showSuccess('Jadwal pengganti berhasil dibuat');
      }
    } catch (e) {
      // The message is the server's (e.g. the date is not on the class's weekday)
      ErrorHelper.showError(e, title: 'Gagal Membuat Jadwal');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? value,
    required bool isStart,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => _selectTime(isStart),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.access_time),
          ),
          child: Text(value != null ? formatJamHHmm(value) : 'Pilih Jam'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atur Jadwal Pengganti'),
        backgroundColor: AppColors.primary,
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
                        ? formatTanggalKalender(_tanggalAsli!)
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
                    activeColor: AppColors.primary,
                  ),
                  const Text('Liburkan Kelas'),
                  const SizedBox(width: 16),
                  Radio<String>(
                    value: 'GANTI_JADWAL',
                    groupValue: _status,
                    onChanged: (val) => setState(() => _status = val!),
                    activeColor: AppColors.primary,
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
                          ? formatTanggalKalender(_tanggalGanti!)
                          : 'Pilih Tanggal Baru',
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                const Text('Jam Pengganti (Opsional):', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTimeField(
                      label: 'Jam Mulai',
                      value: _jamMulaiGanti,
                      isStart: true,
                    ),
                    const SizedBox(width: 12),
                    _buildTimeField(
                      label: 'Jam Berakhir',
                      value: _jamBerakhirGanti,
                      isStart: false,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    _jamError ?? 'Kosongkan jika sama dengan jam kelas asli',
                    style: TextStyle(
                      fontSize: 12,
                      color: _jamError != null ? Colors.red.shade700 : Colors.grey.shade600,
                    ),
                  ),
                ),
                if (_jamMulaiGanti != null || _jamBerakhirGanti != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _jamMulaiGanti = null;
                        _jamBerakhirGanti = null;
                        _jamError = null;
                      }),
                      child: const Text('Hapus jam'),
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
                    backgroundColor: AppColors.primary,
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
