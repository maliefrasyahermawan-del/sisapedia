import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/level_utils.dart';
import '../../data/models/submission_model.dart';

/// Simple estimate shown before admin verification actually credits points.
int _estimatedPoin(double beratKg) => (beratKg * 10).round();

class SetorSuccessScreen extends ConsumerWidget {
  const SetorSuccessScreen({super.key, required this.submission});

  final SubmissionModel submission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Sobat';
    final level = LevelProgress.fromPoin(profile?.poinSirkular ?? 0);
    final estimasi = _estimatedPoin(submission.beratKg);
    final beratLabel = NumberFormat.decimalPattern(
      'id_ID',
    ).format(submission.beratKg);

    final description = submission.partnerName != null
        ? '${submission.subtipe} $beratLabel kg berhasil dicatat. '
              '${submission.partnerName} bakal jemput sebentar lagi.'
        : '${submission.subtipe} $beratLabel kg berhasil dicatat dan diajukan untuk diverifikasi.';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14B881), AppColors.primary, Color(0xFF06603F)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -30, right: -50, child: _blob(140, 0.14)),
            Positioned(bottom: 40, left: -40, child: _blob(110, 0.12)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 26,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.accent700,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Mantap, $name!',
                      style: AppTextStyles.h1.copyWith(
                        color: Colors.white,
                        fontSize: 26,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        description,
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.accent700,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.hourglass_top_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '+$estimasi',
                            style: AppTextStyles.h1.copyWith(
                              color: AppColors.accent700,
                              fontSize: 40,
                            ),
                          ),
                          Text(
                            'ESTIMASI POIN · MENUNGGU VERIFIKASI',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              fontSize: 10.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: level.progress,
                              minHeight: 6,
                              backgroundColor: AppColors.background,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Level ${level.level} → ${(level.progress * 100).round()}% menuju Level ${level.level + 1}',
                            style: AppTextStyles.captionMuted,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/beranda'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.accent700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Kembali ke Beranda'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          context.go('/beranda');
                          context.push('/setor/${submission.kategori.value}');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Catat Sampah Lagi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
