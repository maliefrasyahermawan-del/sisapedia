import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Shared "Kamera / Galeri" bottom sheet used anywhere the app needs a
/// photo (Setor Cerdas Mode Foto, foto bukti setoran manual, dst).
Future<ImageSource?> showImageSourceSheet(
  BuildContext context, {
  String title = 'Ambil Foto',
}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.h2),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_camera_rounded,
                  color: AppColors.primary),
              title: const Text('Kamera'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primary),
              title: const Text('Galeri'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
}
