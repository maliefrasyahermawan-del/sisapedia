import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PointsCard extends StatelessWidget {
  const PointsCard({
    super.key,
    required this.poin,
    required this.onShare,
    required this.onTukar,
    required this.onLihatRiwayat,
  });

  final int poin;
  final VoidCallback onShare;
  final VoidCallback onTukar;
  final VoidCallback onLihatRiwayat;

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat.decimalPattern('id_ID').format(poin);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text('Poin Sirkular', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 6),
          Text(formatted, style: AppTextStyles.statValue),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 16),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onTukar,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Tukar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: onLihatRiwayat,
              child: const Text('Lihat Level & Riwayat'),
            ),
          ),
        ],
      ),
    );
  }
}
