import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../setor_foto/foto_cerdas_flow.dart';
import 'voice_modal.dart';

/// Entry point for the "Setor Cerdas" FAB: lets the user pick between the
/// existing voice flow and the new photo flow before either one starts.
Future<void> showSetorCerdasModeSheet(
  BuildContext context,
  WidgetRef ref,
  String uid,
) {
  return showModalBottomSheet(
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
            Text('Setor Cerdas', style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text(
              'Pilih cara paling gampang buat kamu sekarang.',
              style: AppTextStyles.captionMuted,
            ),
            const SizedBox(height: 18),
            _ModeCard(
              icon: Icons.mic_rounded,
              title: 'Mode Suara Cerdas',
              subtitle: 'Ngomong ke Sari, langsung tercatat.',
              color: AppColors.primary,
              onTap: () {
                Navigator.of(sheetContext).pop();
                showVoiceModal(context, ref, uid);
              },
            ),
            const SizedBox(height: 12),
            _ModeCard(
              icon: Icons.camera_alt_rounded,
              title: 'Mode Foto Cerdas',
              subtitle: 'Foto sampahnya, AI yang deteksi jenisnya.',
              color: AppColors.anorganik,
              onTap: () {
                Navigator.of(sheetContext).pop();
                startFotoCerdasFlow(context, ref, uid);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyBold),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.captionMuted),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
