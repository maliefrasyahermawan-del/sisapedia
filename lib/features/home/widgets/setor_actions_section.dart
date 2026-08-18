import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';

class SetorActionsSection extends StatelessWidget {
  const SetorActionsSection({
    super.key,
    required this.onSetorCerdas,
    required this.onSetorOrganik,
    required this.onSetorAnorganik,
    required this.onWilayahPencocokan,
  });

  final VoidCallback onSetorCerdas;
  final VoidCallback onSetorOrganik;
  final VoidCallback onSetorAnorganik;
  final VoidCallback onWilayahPencocokan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          onTap: onSetorCerdas,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mic_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Setor Cerdas', style: AppTextStyles.h3),
                    const SizedBox(height: 2),
                    Text('Cukup bicara, Sari catat otomatis',
                        style: AppTextStyles.captionMuted),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CategoryCard(
                icon: Icons.compost_rounded,
                color: AppColors.organik,
                title: 'Setor Organik',
                subtitle: 'Sisa dapur, sayur, buah',
                onTap: onSetorOrganik,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CategoryCard(
                icon: Icons.recycling_rounded,
                color: AppColors.anorganik,
                title: 'Setor Anorganik',
                subtitle: 'Plastik, kertas, logam',
                onTap: onSetorAnorganik,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          onTap: onWilayahPencocokan,
          child: Row(
            children: [
              const Icon(Icons.travel_explore_rounded, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wilayah Pencocokan', style: AppTextStyles.h3),
                    const SizedBox(height: 2),
                    Text('Cari via daftar wilayah',
                        style: AppTextStyles.captionMuted),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(title, style: AppTextStyles.bodyBold),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTextStyles.captionMuted),
        ],
      ),
    );
  }
}
