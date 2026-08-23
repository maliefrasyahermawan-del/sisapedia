import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/points_transaction_model.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_header.dart';

class _LevelTier {
  final String name;
  final int minKg;
  final int? maxKg;
  final IconData icon;
  final Color color;

  const _LevelTier({
    required this.name,
    required this.minKg,
    this.maxKg,
    required this.icon,
    required this.color,
  });

  String get rangeLabel => maxKg != null ? '$minKg-$maxKg kg' : '$minKg+ kg';
}

const _tiers = [
  _LevelTier(
    name: 'Perintis Sirkular',
    minKg: 0,
    maxKg: 25,
    icon: Icons.eco_rounded,
    color: Color(0xFFB08D57),
  ),
  _LevelTier(
    name: 'Penggerak Sirkular',
    minKg: 25,
    maxKg: 100,
    icon: Icons.bolt_rounded,
    color: Color(0xFF6B8F87),
  ),
  _LevelTier(
    name: 'Pejuang Sirkular',
    minKg: 100,
    maxKg: 300,
    icon: Icons.shield_rounded,
    color: AppColors.primary,
  ),
  _LevelTier(
    name: 'Duta Kota Hijau',
    minKg: 300,
    maxKg: 700,
    icon: Icons.star_rounded,
    color: Color(0xFF0EA5A4),
  ),
  _LevelTier(
    name: 'Sari Master',
    minKg: 700,
    maxKg: null,
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFCA8A04),
  ),
];

class LevelSirkularScreen extends ConsumerWidget {
  const LevelSirkularScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider).valueOrNull;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final poin = profile?.poinSirkular ?? 0;

    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final submissionsAsync = ref.watch(dashboardSubmissionsProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Level Sirkular')),
      body: submissionsAsync.when(
        data: (submissions) {
          final totalKg = submissions.fold<double>(
            0,
            (sum, s) => sum + s.beratKg,
          );
          final currentIndex = () {
            var idx = 0;
            for (var i = 0; i < _tiers.length; i++) {
              if (totalKg >= _tiers[i].minKg) idx = i;
            }
            return idx;
          }();
          final currentTier = _tiers[currentIndex];
          final nextTier = currentIndex + 1 < _tiers.length
              ? _tiers[currentIndex + 1]
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _LevelSummaryCard(
                currentTier: currentTier,
                nextTier: nextTier,
                totalKg: totalKg,
                poin: poin,
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: '5 Tingkat Level Sirkular'),
              const SizedBox(height: 12),
              for (var i = 0; i < _tiers.length; i++) ...[
                _TierTile(
                  tier: _tiers[i],
                  isDone: i < currentIndex,
                  isActive: i == currentIndex,
                ),
                if (i != _tiers.length - 1) const SizedBox(height: 10),
              ],
              const SizedBox(height: 24),
              const SectionHeader(title: 'Riwayat Poin Sirkular'),
              const SizedBox(height: 12),
              _RiwayatSection(uid: uid),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Gagal memuat data level.',
            style: AppTextStyles.captionMuted.copyWith(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}

class _LevelSummaryCard extends StatelessWidget {
  const _LevelSummaryCard({
    required this.currentTier,
    required this.nextTier,
    required this.totalKg,
    required this.poin,
  });

  final _LevelTier currentTier;
  final _LevelTier? nextTier;
  final double totalKg;
  final int poin;

  @override
  Widget build(BuildContext context) {
    final progress = nextTier != null
        ? ((totalKg - currentTier.minKg) /
                  (nextTier!.minKg - currentTier.minKg))
              .clamp(0.0, 1.0)
        : 1.0;
    final remainingKg = nextTier != null
        ? (nextTier!.minKg - totalKg).clamp(0, double.infinity)
        : 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: currentTier.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  currentTier.icon,
                  color: currentTier.color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level Aktif',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(currentTier.name, style: AppTextStyles.h1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '${totalKg.toStringAsFixed(0)} kg ',
                style: AppTextStyles.bodyBold,
              ),
              Text('teralihkan', style: AppTextStyles.captionMuted),
              const SizedBox(width: 12),
              Text(
                '${NumberFormat.decimalPattern('id_ID').format(poin)} poin',
                style: AppTextStyles.bodyBold,
              ),
            ],
          ),
          if (nextTier != null) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Menuju ${nextTier!.name}',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  '${remainingKg.toStringAsFixed(0)} kg lagi',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.border,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${totalKg.toStringAsFixed(0)} kg',
                  style: AppTextStyles.captionMuted,
                ),
                Text(
                  '${nextTier!.minKg} kg',
                  style: AppTextStyles.captionMuted,
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              'Level tertinggi tercapai! Terus jaga konsistensimu.',
              style: AppTextStyles.captionMuted,
            ),
          ],
        ],
      ),
    );
  }
}

class _TierTile extends StatelessWidget {
  const _TierTile({
    required this.tier,
    required this.isDone,
    required this.isActive,
  });

  final _LevelTier tier;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.border,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tier.color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(tier.icon, color: tier.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier.name, style: AppTextStyles.bodyBold),
                const SizedBox(height: 2),
                Text(tier.rangeLabel, style: AppTextStyles.captionMuted),
              ],
            ),
          ),
          if (isDone)
            const Icon(Icons.check_circle_rounded, color: AppColors.success)
          else if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Aktif',
                style: AppTextStyles.caption.copyWith(color: Colors.white),
              ),
            )
          else
            const Icon(Icons.lock_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _RiwayatSection extends ConsumerWidget {
  const _RiwayatSection({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(userPointsTransactionsProvider(uid));

    return txAsync.when(
      data: (txs) {
        if (txs.isEmpty) {
          return AppCard(
            child: Text(
              'Belum ada riwayat poin.',
              style: AppTextStyles.captionMuted,
            ),
          );
        }
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < txs.length; i++) ...[
                _TxTile(tx: txs[i]),
                if (i != txs.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Text(
        'Gagal memuat riwayat.',
        style: AppTextStyles.captionMuted.copyWith(color: AppColors.error),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});

  final PointsTransactionModel tx;

  @override
  Widget build(BuildContext context) {
    final isEarn = tx.jenis == PointsTransactionType.earn;
    return ListTile(
      title: Text(tx.deskripsi, style: AppTextStyles.bodySmall),
      subtitle: Text(tx.status.label, style: AppTextStyles.captionMuted),
      trailing: Text(
        '${isEarn ? '+' : '-'}${tx.jumlah}',
        style: AppTextStyles.bodyBold.copyWith(
          color: isEarn ? AppColors.success : AppColors.textSecondary,
        ),
      ),
    );
  }
}
