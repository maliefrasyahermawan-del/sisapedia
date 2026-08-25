import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preview/preview_mode.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../pengolah_colors.dart';
import '../pengolah_providers.dart';
import '../data/pengolah_articles.dart';
import '../data/pengolah_mock.dart';
import 'pengolah_article_detail_screen.dart';

class PengolahBerandaTab extends ConsumerWidget {
  const PengolahBerandaTab({super.key, required this.onNavigate});

  /// index: 1 = Dashboard, 2 = Setoran, 3 = Komunitas
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingCount = kPreviewMode
        ? pengolahSubmissions.length
        : ref
                .watch(pengolahIncomingQueueCountProvider)
                .maybeWhen(data: (n) => n, orElse: () => 0);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          decoration: const BoxDecoration(color: PengolahColors.primary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SisaPedia', style: AppTextStyles.brand),
                  _NotifBell(onTap: () => onNavigate(2)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: PengolahColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_outlined,
                          color: PengolahColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, $pengolahNamaAkun',
                              style: AppTextStyles.bodyBold),
                          const SizedBox(height: 2),
                          Text('Kelola setoran dan komunitasmu hari ini',
                              style: AppTextStyles.captionMuted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: const _CapacityRow(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text('Menu Cepat', style: AppTextStyles.h3),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _QuickMenuTile(
                  label: 'Lihat Dashboard',
                  onTap: () => onNavigate(1),
                ),
                const Divider(height: 1),
                _QuickMenuTile(
                  label: 'Setoran Masuk · $incomingCount baru',
                  onTap: () => onNavigate(2),
                ),
                const Divider(height: 1),
                _QuickMenuTile(
                  label: 'Komunitas',
                  onTap: () => onNavigate(3),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Artikel Seputar Pengolah', style: AppTextStyles.h3),
              const SizedBox(height: 2),
              Text('Smart waste & tips operasional bank sampah',
                  style: AppTextStyles.captionMuted),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 128,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < pengolahArticles.length; i++) ...[
                _ArticleCard(
                  title: pengolahArticles[i].title,
                  meta: pengolahArticles[i].readTime,
                  color: _articleCardColors[i % _articleCardColors.length],
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PengolahArticleDetailScreen(
                        article: pengolahArticles[i]),
                  )),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _NotifBell extends ConsumerWidget {
  const _NotifBell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This app has no push notifications — Pengolah "gets notified" of a
    // new incoming submission via this badge (live Firestore count),
    // rather than a separate notifications collection like Sumber's bell
    // uses (see core/providers/notification_providers.dart).
    final unreadCount = kPreviewMode
        ? 0
        : ref
                .watch(pengolahIncomingQueueCountProvider)
                .maybeWhen(data: (n) => n, orElse: () => 0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(Icons.notifications_none_rounded,
                  color: Colors.white, size: 18),
            ),
            if (unreadCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CapacityRow extends ConsumerWidget {
  const _CapacityRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menungguVerifikasi = kPreviewMode
        ? 3
        : ref
                .watch(pengolahMenungguVerifikasiCountProvider)
                .maybeWhen(data: (n) => n, orElse: () => 0);

    return Row(
      children: [
        const Expanded(
          child: _CapacityCard(
            label: 'Kapasitas Gudang',
            percent: 0.72,
            color: PengolahColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CountCard(
            label: 'Menunggu Verifikasi',
            count: menungguVerifikasi,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
  });

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

class _CapacityCard extends StatelessWidget {
  const _CapacityCard({
    required this.label,
    required this.percent,
    required this.color,
  });

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
          Text('${(percent * 100).round()}% terisi',
              style: AppTextStyles.captionMuted),
        ],
      ),
    );
  }
}

class _QuickMenuTile extends StatelessWidget {
  const _QuickMenuTile({
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodyBold),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.title,
    required this.meta,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String meta;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 60, color: color),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(meta, style: AppTextStyles.captionMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _articleCardColors = [
  PengolahColors.primarySoft,
  Color(0xFFFEF3E2),
  Color(0xFFE8F7EF),
];
