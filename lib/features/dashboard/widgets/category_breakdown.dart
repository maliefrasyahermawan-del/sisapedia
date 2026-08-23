import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../dashboard_stats.dart';

class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({super.key, required this.categories});

  final List<CategoryStat> categories;

  static const _palette = [
    AppColors.primary,
    AppColors.anorganik,
    Color(0xFFF59E0B),
    Color(0xFF7C3AED),
    Color(0xFFEF4444),
    Color(0xFF0891B2),
  ];

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Text(
        'Belum ada data setoran terverifikasi.',
        style: AppTextStyles.captionMuted,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < categories.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    categories[i].subtipe,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: categories[i].percent / 100,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      color: _palette[i % _palette.length],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${categories[i].percent.toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
