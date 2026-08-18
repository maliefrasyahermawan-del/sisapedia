import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../dashboard_stats.dart';

class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.monthly});

  final List<MonthlyStat> monthly;

  @override
  Widget build(BuildContext context) {
    var maxY = 0.0;
    for (final m in monthly) {
      if (m.organik > maxY) maxY = m.organik;
      if (m.anorganik > maxY) maxY = m.anorganik;
    }
    final safeMaxY = maxY <= 0 ? 10.0 : maxY * 1.3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: safeMaxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: safeMaxY / 4,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.border, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= monthly.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(monthly[index].monthLabel,
                            style: AppTextStyles.captionMuted),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: true),
              lineBarsData: [
                _line(
                  monthly
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value.organik))
                      .toList(),
                  AppColors.organik,
                ),
                _line(
                  monthly
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value.anorganik))
                      .toList(),
                  AppColors.anorganik,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            _LegendDot(color: AppColors.organik, label: 'Organik'),
            SizedBox(width: 16),
            _LegendDot(color: AppColors.anorganik, label: 'Anorganik'),
          ],
        ),
      ],
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.captionMuted),
      ],
    );
  }
}
