import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';

class RedeemArticleSection extends ConsumerWidget {
  const RedeemArticleSection({
    super.key,
    required this.onRedeem,
  });

  final void Function(int jumlah, String deskripsi) onRedeem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(articlesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Rekomendasi & Artikel',
          subtitle: 'Tukar poin atau baca info edukasi sampah',
        ),
        const SizedBox(height: 12),
        _RedeemCard(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Tukar Poin jadi Saldo E-Wallet',
          subtitle: 'Cairkan Poin ke Dana/OVO · Min. 500 poin sirkular',
          poin: 500,
          onTap: () => onRedeem(500, 'Cairkan Poin ke Dana/OVO'),
        ),
        const SizedBox(height: 10),
        _RedeemCard(
          icon: Icons.card_giftcard_rounded,
          title: 'Voucher Kompos Organik',
          subtitle: 'Dari mitra Kompos Tandur Ijo',
          poin: 300,
          onTap: () => onRedeem(300, 'Voucher Kompos Organik'),
        ),
        const SizedBox(height: 16),
        articlesAsync.when(
          data: (articles) {
            if (articles.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                for (final article in articles.take(3)) ...[
                  _ArticleCard(
                    title: article.title,
                    summary: article.summary,
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
          error: (_, _) => const SizedBox.shrink(),
        ),
        Center(
          child: TextButton(
            onPressed: () {},
            child: const Text('Lihat Lainnya'),
          ),
        ),
      ],
    );
  }
}

class _RedeemCard extends StatelessWidget {
  const _RedeemCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.poin,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int poin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyBold),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.captionMuted),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Poin Sirkular', style: AppTextStyles.captionMuted),
              Text('$poin', style: AppTextStyles.bodyBold),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.title, required this.summary});

  final String title;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ARTIKEL',
              style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
          const SizedBox(height: 6),
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text('Selengkapnya', style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }
}
