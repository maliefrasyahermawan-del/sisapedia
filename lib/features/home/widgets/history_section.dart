import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';

class HistorySection extends ConsumerWidget {
  const HistorySection({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(userSubmissionsProvider(uid));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Riwayat Setoran',
          actionLabel: 'Lihat semua',
          onAction: () {},
        ),
        const SizedBox(height: 12),
        submissionsAsync.when(
          data: (submissions) {
            if (submissions.isEmpty) {
              return Text('Belum ada setoran. Yuk mulai setor sampahmu!',
                  style: AppTextStyles.captionMuted);
            }
            return Column(
              children: [
                for (final s in submissions.take(5)) ...[
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.subtipe, style: AppTextStyles.bodyBold),
                              const SizedBox(height: 4),
                              Text(
                                '${s.beratKg.toStringAsFixed(1)} kg'
                                '${s.partnerName != null ? ' · ${s.partnerName}' : ''}',
                                style: AppTextStyles.captionMuted,
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(status: s.status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text('Gagal memuat riwayat.',
              style: AppTextStyles.captionMuted.copyWith(color: AppColors.error)),
        ),
      ],
    );
  }
}
