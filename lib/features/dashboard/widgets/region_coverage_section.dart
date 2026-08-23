import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';

class RegionCoverageSection extends StatelessWidget {
  const RegionCoverageSection({super.key});

  static const _regions = [
    (name: 'Semarang', active: true),
    (name: 'Jakarta', active: false),
    (name: 'Surabaya', active: false),
    (name: 'Bandung', active: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Cakupan Wilayah'),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final region in _regions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: region.active
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(region.name, style: AppTextStyles.bodyBold),
                      ),
                      Text(
                        region.active ? 'Aktif' : 'Segera hadir',
                        style: AppTextStyles.captionMuted.copyWith(
                          color: region.active
                              ? AppColors.success
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
