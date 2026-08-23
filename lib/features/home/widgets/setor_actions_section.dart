import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SetorActionsSection extends StatelessWidget {
  const SetorActionsSection({
    super.key,
    required this.onSetorOrganik,
    required this.onSetorAnorganik,
    required this.onWilayahPencocokan,
  });

  final VoidCallback onSetorOrganik;
  final VoidCallback onSetorAnorganik;
  final VoidCallback onWilayahPencocokan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _CategoryCard(
                icon: Icons.compost_rounded,
                color: AppColors.organik,
                background: AppColors.organikSoft,
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
                background: AppColors.anorganikSoft,
                title: 'Setor Anorganik',
                subtitle: 'Plastik, kertas, logam',
                onTap: onSetorAnorganik,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WilayahCard(onTap: onWilayahPencocokan),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: AppTextStyles.bodyBold.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: AppTextStyles.captionMuted
                    .copyWith(color: color.withValues(alpha: 0.75))),
          ],
        ),
      ),
    );
  }
}

class _WilayahCard extends StatelessWidget {
  const _WilayahCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.wilayahSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.travel_explore_rounded, color: AppColors.wilayah),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wilayah Pencocokan',
                      style: AppTextStyles.h3
                          .copyWith(color: AppColors.wilayah)),
                  const SizedBox(height: 2),
                  Text('Cari via daftar wilayah',
                      style: AppTextStyles.captionMuted.copyWith(
                          color: AppColors.wilayah.withValues(alpha: 0.75))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.wilayah.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}
