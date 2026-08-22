import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/level_utils.dart';

/// Green gamification card shown just below the Beranda header: a circular
/// level-progress ring, current Poin Sirkular, and a "Tukar" shortcut.
class PointsCard extends StatelessWidget {
  const PointsCard({
    super.key,
    required this.poin,
    required this.onTukar,
    required this.onLihatRiwayat,
  });

  final int poin;
  final VoidCallback onTukar;
  final VoidCallback onLihatRiwayat;

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat.decimalPattern('id_ID').format(poin);
    final level = LevelProgress.fromPoin(poin);

    return InkWell(
      onTap: onLihatRiwayat,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 20, 16, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D8A61), Color(0xFF075A3F)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -21,
              right: 6,
              child: Transform.rotate(
                angle: 2 * math.pi / 180,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.levelBadge,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    'LV. ${level.level}',
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF5C3D00),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _LevelRing(progress: level.progress),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PENGUMPUL RAJIN',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.levelBadge,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          style: AppTextStyles.h1.copyWith(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.15,
                          ),
                          children: [
                            TextSpan(text: '$formatted '),
                            TextSpan(
                              text: 'Poin',
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${level.poinRemaining} poin lagi ke Level ${level.level + 1}',
                        style: AppTextStyles.captionMuted.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onTukar,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Tukar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelRing extends StatelessWidget {
  const _LevelRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: progress.clamp(0.02, 1.0),
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              color: AppColors.levelBadge,
              backgroundColor: Colors.transparent,
            ),
          ),
          Text(
            '${(progress * 100).round()}%',
            style: AppTextStyles.bodyBold
                .copyWith(color: Colors.white, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
