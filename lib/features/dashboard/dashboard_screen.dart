import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_header.dart';
import 'dashboard_stats.dart';
import 'widgets/ai_insight_card.dart';
import 'widgets/category_breakdown.dart';
import 'widgets/region_coverage_section.dart';
import 'widgets/trend_chart.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isCityScope = false;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider).valueOrNull;
    final scopeUid = _isCityScope ? null : uid;
    final submissionsAsync = ref.watch(dashboardSubmissionsProvider(scopeUid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Dampak Sirkular')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScopeToggle(
              isCityScope: _isCityScope,
              onChanged: (v) => setState(() => _isCityScope = v),
            ),
            const SizedBox(height: 16),
            submissionsAsync.when(
              data: (submissions) {
                final stats = DashboardStats.fromSubmissions(submissions);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            label: 'Organik Dialihkan',
                            value: '${stats.organikThisMonth.toStringAsFixed(1)} kg',
                            caption: 'dari TPA bulan ini',
                            color: AppColors.organik,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            label: 'Anorganik Dialihkan',
                            value:
                                '${stats.anorganikThisMonth.toStringAsFixed(1)} kg',
                            caption: 'dari TPA bulan ini',
                            color: AppColors.anorganik,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Tren Bulanan'),
                    const SizedBox(height: 12),
                    AppCard(child: TrendChart(monthly: stats.monthly)),
                    const SizedBox(height: 20),
                    AiInsightCard(
                      dataSummary: stats.toAiSummary(isCityScope: _isCityScope),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(
                      title: 'Jenis Sampah Terkelola',
                      subtitle: 'Berdasarkan kategori setoran bulan ini',
                    ),
                    const SizedBox(height: 12),
                    AppCard(child: CategoryBreakdown(categories: stats.categories)),
                    const SizedBox(height: 24),
                    const RegionCoverageSection(),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Text('Gagal memuat data dashboard.',
                  style: AppTextStyles.captionMuted.copyWith(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  const _ScopeToggle({required this.isCityScope, required this.onChanged});

  final bool isCityScope;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _segment(context, 'Saya', !isCityScope, () => onChanged(false))),
          Expanded(
              child: _segment(
                  context, 'Kota Semarang', isCityScope, () => onChanged(true))),
        ],
      ),
    );
  }

  Widget _segment(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.bodyBold.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.captionMuted),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.h2),
          Text(caption, style: AppTextStyles.captionMuted),
        ],
      ),
    );
  }
}
