import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preview/preview_mode.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../pengolah_colors.dart';
import '../pengolah_providers.dart';

class PengolahDashboardTab extends ConsumerWidget {
  const PengolahDashboardTab({super.key});

  static const _weekly = [
    (organik: 0.70, anorganik: 0.30, height: 62.0),
    (organik: 0.55, anorganik: 0.45, height: 78.0),
    (organik: 0.65, anorganik: 0.35, height: 70.0),
    (organik: 0.60, anorganik: 0.40, height: 95.0),
    (organik: 0.58, anorganik: 0.42, height: 85.0),
    (organik: 0.66, anorganik: 0.34, height: 110.0),
    (organik: 0.63, anorganik: 0.37, height: 90.0),
  ];
  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menungguVerifikasi = kPreviewMode
        ? 3
        : ref
                .watch(pengolahMenungguVerifikasiCountProvider)
                .maybeWhen(data: (n) => n, orElse: () => 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(
          children: [
            Text('Dashboard Pengolah', style: AppTextStyles.h1),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: PengolahColors.primarySoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Mitra Pengolah Sampah',
                style: AppTextStyles.captionMuted
                    .copyWith(color: PengolahColors.primaryDark, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('Bank Sampah Melati Bersih', style: AppTextStyles.captionMuted),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _MiniStat(label: 'Kapasitas Gudang', percent: 0.72, color: PengolahColors.primary)),
            const SizedBox(width: 12),
            Expanded(
              child: _CountStat(
                label: 'Menunggu Verifikasi',
                count: menungguVerifikasi,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tren Setoran Mingguan', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              SizedBox(
                height: 110,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final w in _weekly) ...[
                      Expanded(
                        child: SizedBox(
                          height: w.height,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Column(
                              children: [
                                Expanded(
                                  flex: (w.organik * 100).round(),
                                  child: Container(color: AppColors.organik),
                                ),
                                Expanded(
                                  flex: (w.anorganik * 100).round(),
                                  child: Container(color: PengolahColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (w != _weekly.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final d in _days)
                    Text(d, style: AppTextStyles.captionMuted.copyWith(fontSize: 10)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Legend(color: AppColors.organik, label: 'Organik'),
                  const SizedBox(width: 14),
                  _Legend(color: PengolahColors.primary, label: 'Anorganik'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text('Insight AI Sari',
                      style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Setoran organik dari Warung Bu Sri naik 18% minggu ini. Kapasitas '
                'gudang diperkirakan penuh dalam 5 hari, pertimbangkan jadwalkan '
                'pengangkutan lebih awal.',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white, height: 1.5),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InsightChip(label: 'Tren naik'),
                  _InsightChip(label: 'Peringatan kapasitas'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.percent, required this.color});

  final String label;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 7,
              backgroundColor: AppColors.background,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text('${(percent * 100).round()}% terisi', style: AppTextStyles.captionMuted),
        ],
      ),
    );
  }
}

class _CountStat extends StatelessWidget {
  const _CountStat({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 10),
          Text('$count', style: AppTextStyles.statValue.copyWith(color: color)),
          const SizedBox(height: 6),
          Text('setoran menunggu diverifikasi', style: AppTextStyles.captionMuted),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.captionMuted),
      ],
    );
  }
}

class _InsightChip extends StatelessWidget {
  const _InsightChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: AppTextStyles.captionMuted.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}
