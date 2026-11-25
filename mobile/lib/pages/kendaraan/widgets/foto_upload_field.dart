import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/app_theme.dart';

const Color _primaryColor = AppColors.primary;

/// Bottom sheet that asks where a photo comes from. Returns null when dismissed.
Future<ImageSource?> showFotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Sumber Foto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              _SourceTile(
                icon: Icons.camera_alt,
                title: 'Kamera',
                subtitle: 'Ambil foto langsung',
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              _SourceTile(
                icon: Icons.photo_library,
                title: 'Galeri',
                subtitle: 'Pilih dari galeri',
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _primaryColor),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

/// One photo slot of the vehicle forms: thumbnail + label + state, with an inline [errorText]
/// when the photo is still missing after the user tried to submit.
class FotoUploadField extends StatelessWidget {
  final String label;
  final String? imagePath;
  final String? errorText;
  final VoidCallback onTap;

  const FotoUploadField({
    super.key,
    required this.label,
    required this.imagePath,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final String? path = imagePath;
    final bool hasError = errorText != null;
    final Color borderColor = hasError
        ? AppColors.danger
        : (path != null ? _primaryColor : Colors.grey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: path != null ? '$label, foto terpilih' : '$label, belum dipilih',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: borderColor,
                  width: path != null || hasError ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: path != null ? _primaryColor.withValues(alpha: 0.05) : null,
              ),
              child: Row(
                children: [
                  // Thumbnail preview or icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: path != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                            ),
                          )
                        : Icon(
                            Icons.add_a_photo,
                            size: 28,
                            color: Colors.grey[500],
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Label and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: path != null
                                ? _primaryColor
                                : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          path != null
                              ? 'Foto terpilih'
                              : 'Ketuk untuk memilih foto',
                          style: TextStyle(
                            fontSize: 12,
                            color: path != null
                                ? Colors.green
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action icon
                  Icon(
                    path != null ? Icons.check_circle : Icons.folder_open,
                    color: path != null ? Colors.green : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              errorText!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
