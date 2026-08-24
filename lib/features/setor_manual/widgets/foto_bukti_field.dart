import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// "Foto Bukti Sampah" upload card for the manual Setor flow — required so
/// mitra pengolah can verify a setoran before it's counted as verified.
class FotoBuktiField extends StatelessWidget {
  const FotoBuktiField({
    super.key,
    required this.imagePath,
    required this.onPick,
    this.errorText,
  });

  final String? imagePath;
  final VoidCallback onPick;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: imagePath == null ? 140 : 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: errorText != null ? AppColors.error : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: imagePath == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_rounded,
                      color: AppColors.primary, size: 30),
                  const SizedBox(height: 8),
                  Text('Tambah Foto Bukti Sampah',
                      style: AppTextStyles.bodyBold
                          .copyWith(color: AppColors.primary)),
                  const SizedBox(height: 2),
                  Text('Kamera atau galeri', style: AppTextStyles.captionMuted),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(imagePath!), fit: BoxFit.cover),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('Ganti Foto',
                              style: AppTextStyles.caption
                                  .copyWith(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
