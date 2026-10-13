import 'package:flutter/material.dart';

import '../../utils/validators.dart';

/// Confirmation for an action that cannot be undone: the confirm button stays disabled until the
/// user types [keyword] exactly. Resolves to true only when confirmed.
Future<bool> showTypedConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String keyword = 'HAPUS',
  String confirmLabel = 'HAPUS SEMUA',
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => TypedConfirmDialog(
      title: title,
      message: message,
      keyword: keyword,
      confirmLabel: confirmLabel,
    ),
  );
  return confirmed == true;
}

class TypedConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String keyword;
  final String confirmLabel;

  const TypedConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.keyword = 'HAPUS',
    this.confirmLabel = 'HAPUS SEMUA',
  });

  @override
  State<TypedConfirmDialog> createState() => _TypedConfirmDialogState();
}

class _TypedConfirmDialogState extends State<TypedConfirmDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canConfirm = Validators.matchesConfirmation(
      _controller.text,
      keyword: widget.keyword,
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Ketik ${widget.keyword} untuk melanjutkan',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: canConfirm ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            disabledBackgroundColor: Colors.red.shade100,
          ),
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
