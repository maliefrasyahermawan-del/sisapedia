import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/data_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';

class AiInsightCard extends ConsumerWidget {
  const AiInsightCard({super.key, required this.dataSummary});

  final String dataSummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConfigured = ref.watch(sariGatewayProvider).isConfigured;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text('Insight AI Sari', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 12),
          if (!isConfigured)
            Text(
              'Gateway Sari belum dikonfigurasi. Insight tersedia setelah Edge Function aktif.',
              style: AppTextStyles.captionMuted,
            )
          else
            Consumer(
              builder: (context, ref, _) {
                final insightAsync = ref.watch(aiInsightProvider(dataSummary));
                return insightAsync.when(
                  data: (text) => Text(text, style: AppTextStyles.body),
                  loading: () => Row(
                    children: [
                      const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Sari sedang menganalisis datamu...',
                        style: AppTextStyles.captionMuted,
                      ),
                    ],
                  ),
                  error: (_, _) => Text(
                    'Sari belum bisa memberi insight saat ini. Coba lagi nanti.',
                    style: AppTextStyles.captionMuted,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
