import 'package:flutter/material.dart';
import '../../../utils/attendance_status.dart';
import '../../../utils/app_theme.dart';

/// Saves the chosen status and note. Returns the error text to show in the sheet, or null when it
/// was saved (the sheet then closes).
typedef OverrideSave = Future<String?> Function(String status, String? keterangan);

/// Longest note the server accepts.
const int overrideKeteranganMaxLength = 255;

/// Opens the sheet where a dosen sets the attendance status of one student by hand. Resolves to
/// true when the status was saved, false/null when the sheet was cancelled.
Future<bool?> showOverrideStatusSheet(
  BuildContext context, {
  required String namaMahasiswa,
  required String? currentStatus,
  String? currentKeterangan,
  required OverrideSave onSave,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    enableDrag: false, // a swipe must not close the sheet while it saves
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext sheetContext) => OverrideStatusSheet(
      namaMahasiswa: namaMahasiswa,
      currentStatus: currentStatus,
      currentKeterangan: currentKeterangan,
      onSave: onSave,
    ),
  );
}

/// The five statuses and an optional note. While [onSave] runs nothing in the sheet can be
/// changed or closed; a failure keeps the sheet open with the error so it can be retried.
class OverrideStatusSheet extends StatefulWidget {
  final String namaMahasiswa;
  final String? currentStatus;
  final String? currentKeterangan;
  final OverrideSave onSave;

  const OverrideStatusSheet({
    super.key,
    required this.namaMahasiswa,
    required this.currentStatus,
    this.currentKeterangan,
    required this.onSave,
  });

  @override
  State<OverrideStatusSheet> createState() => _OverrideStatusSheetState();
}

class _OverrideStatusSheetState extends State<OverrideStatusSheet> {
  late final TextEditingController _keteranganController;
  String? _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = normalizeAttendanceStatus(widget.currentStatus);
    _keteranganController = TextEditingController(text: widget.currentKeterangan ?? '');
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    super.dispose();
  }

  bool get _unchanged =>
      _selected == normalizeAttendanceStatus(widget.currentStatus) &&
      _keteranganController.text.trim() == (widget.currentKeterangan ?? '').trim();

  Future<void> _save() async {
    final String? status = _selected;
    if (status == null || _saving) return;

    final String note = _keteranganController.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });

    final String? error = await widget.onSave(status, note.isEmpty ? null : note);
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ubah Kehadiran',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.namaMahasiswa,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                for (final String status in attendanceStatuses) _buildStatusTile(status),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('override-keterangan'),
                  controller: _keteranganController,
                  enabled: !_saving,
                  maxLength: overrideKeteranganMaxLength,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Keterangan (opsional)',
                    hintText: 'Mis. surat izin, surat dokter',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      _error!,
                      key: const Key('override-error'),
                      style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('override-cancel'),
                        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('override-save'),
                        onPressed: _saving || _selected == null || _unchanged ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTile(String status) {
    final bool selected = _selected == status;
    final Color color = attendanceStatusColor(status);

    return ListTile(
      key: Key('override-status-$status'),
      enabled: !_saving,
      selected: selected,
      selectedTileColor: color.withValues(alpha: 0.08),
      selectedColor: color,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Icon(attendanceStatusIcon(status), color: color),
      title: Text(
        attendanceStatusLabel(status),
        style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.w500),
      ),
      trailing: selected ? Icon(Icons.check, color: color) : null,
      onTap: () => setState(() => _selected = status),
    );
  }
}
