import 'package:intl/intl.dart';

import '../../data/models/submission_model.dart';

class MonthlyStat {
  final String monthLabel;
  final double organik;
  final double anorganik;

  const MonthlyStat({
    required this.monthLabel,
    required this.organik,
    required this.anorganik,
  });
}

class CategoryStat {
  final String subtipe;
  final double beratKg;
  final double percent;

  const CategoryStat({
    required this.subtipe,
    required this.beratKg,
    required this.percent,
  });
}

class DashboardStats {
  final double organikThisMonth;
  final double anorganikThisMonth;
  final List<MonthlyStat> monthly;
  final List<CategoryStat> categories;

  const DashboardStats({
    required this.organikThisMonth,
    required this.anorganikThisMonth,
    required this.monthly,
    required this.categories,
  });

  static DashboardStats fromSubmissions(List<SubmissionModel> submissions) {
    final now = DateTime.now();
    double organikThisMonth = 0;
    double anorganikThisMonth = 0;

    final monthKeys = <String>[];
    final monthOrganik = <String, double>{};
    final monthAnorganik = <String, double>{};
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = '${month.year}-${month.month}';
      monthKeys.add(key);
      monthOrganik[key] = 0;
      monthAnorganik[key] = 0;
    }

    final categoryTotals = <String, double>{};
    double grandTotal = 0;

    for (final s in submissions) {
      final createdAt = s.createdAt;
      if (createdAt == null) continue;

      if (createdAt.year == now.year && createdAt.month == now.month) {
        if (s.kategori == WasteCategory.organik) {
          organikThisMonth += s.beratKg;
        } else {
          anorganikThisMonth += s.beratKg;
        }
      }

      final key = '${createdAt.year}-${createdAt.month}';
      if (monthOrganik.containsKey(key)) {
        if (s.kategori == WasteCategory.organik) {
          monthOrganik[key] = monthOrganik[key]! + s.beratKg;
        } else {
          monthAnorganik[key] = monthAnorganik[key]! + s.beratKg;
        }
      }

      categoryTotals[s.subtipe] = (categoryTotals[s.subtipe] ?? 0) + s.beratKg;
      grandTotal += s.beratKg;
    }

    final monthly = monthKeys.map((key) {
      final parts = key.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      return MonthlyStat(
        monthLabel: DateFormat('MMM', 'id_ID').format(date),
        organik: monthOrganik[key] ?? 0,
        anorganik: monthAnorganik[key] ?? 0,
      );
    }).toList();

    final categories = categoryTotals.entries
        .map((e) => CategoryStat(
              subtipe: e.key,
              beratKg: e.value,
              percent: grandTotal > 0 ? (e.value / grandTotal) * 100 : 0,
            ))
        .toList()
      ..sort((a, b) => b.beratKg.compareTo(a.beratKg));

    return DashboardStats(
      organikThisMonth: organikThisMonth,
      anorganikThisMonth: anorganikThisMonth,
      monthly: monthly,
      categories: categories.take(6).toList(),
    );
  }

  String toAiSummary({required bool isCityScope}) {
    final buffer = StringBuffer();
    buffer.writeln(isCityScope
        ? 'Data setoran sampah kota bulan ini:'
        : 'Data setoran sampah pengguna bulan ini:');
    buffer.writeln(
        '- Organik: ${organikThisMonth.toStringAsFixed(1)} kg dialihkan dari TPA');
    buffer.writeln(
        '- Anorganik: ${anorganikThisMonth.toStringAsFixed(1)} kg dialihkan dari TPA');
    if (categories.isNotEmpty) {
      final top = categories.first;
      buffer.writeln(
          '- Kategori terbanyak: ${top.subtipe} (${top.percent.toStringAsFixed(0)}%)');
    }
    if (monthly.length >= 2) {
      final prev = monthly[monthly.length - 2];
      final curr = monthly.last;
      final prevTotal = prev.organik + prev.anorganik;
      final currTotal = curr.organik + curr.anorganik;
      if (prevTotal > 0) {
        final change = ((currTotal - prevTotal) / prevTotal) * 100;
        buffer.writeln(
            '- Perubahan dari bulan lalu: ${change.toStringAsFixed(0)}%');
      }
    }
    return buffer.toString();
  }
}
