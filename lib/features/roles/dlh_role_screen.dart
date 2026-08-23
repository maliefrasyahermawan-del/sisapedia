import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/role_metrics_provider.dart';

/// DLH is intentionally backed only by the aggregate RPC/preview aggregate.
/// It never reads submissions, processor profiles, or precise locations.
class DlhRoleScreen extends ConsumerWidget {
  const DlhRoleScreen({super.key, required this.tab});
  final int tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(dlhCompletionMonthProvider);
    return ref
        .watch(dlhMetricsProvider)
        .when(
          data: (metrics) {
            if (metrics['error'] != null) {
              return Center(child: Text(metrics['error'].toString()));
            }
            return Column(
              children: [
                _MonthSelector(month: selectedMonth),
                Expanded(
                  child: switch (tab) {
                    1 => const _Districts(),
                    2 => _Report(metrics: metrics),
                    3 => const _DlhProfile(),
                    _ => _DlhDashboard(metrics: metrics),
                  },
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Data DLH belum tersedia: $error')),
        );
  }
}

class _MonthSelector extends ConsumerWidget {
  const _MonthSelector({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(
          'Bulan selesai: ${month.year}-${month.month.toString().padLeft(2, '0')}',
        ),
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: month,
            firstDate: DateTime(2024),
            lastDate: DateTime.now(),
            helpText: 'Pilih bulan completion',
          );
          if (picked != null && context.mounted) {
            ref.read(dlhCompletionMonthProvider.notifier).state = DateTime(
              picked.year,
              picked.month,
            );
          }
        },
      ),
    ),
  );
}

class _DlhDashboard extends StatelessWidget {
  const _DlhDashboard({required this.metrics});
  final Map<String, dynamic> metrics;

  @override
  Widget build(BuildContext context) {
    final organic = (metrics['organic_kg'] as num?)?.toDouble() ?? 0;
    final inorganic = (metrics['inorganic_kg'] as num?)?.toDouble() ?? 0;
    final activeSources = (metrics['active_sources'] as num?)?.toInt() ?? 0;
    final activeProcessors =
        (metrics['active_processors'] as num?)?.toInt() ?? 0;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Dampak Kota Semarang',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Hanya agregat terverifikasi yang tampil. Tidak ada alamat atau lokasi individu di dashboard DLH.',
        ),
        const SizedBox(height: 16),
        _metric(
          'Total diversi',
          '${(organic + inorganic).toStringAsFixed(1)} kg',
          Icons.eco,
        ),
        _metric(
          'Organik',
          '${organic.toStringAsFixed(1)} kg',
          Icons.compost_rounded,
        ),
        _metric(
          'Anorganik',
          '${inorganic.toStringAsFixed(1)} kg',
          Icons.recycling,
        ),
        _metric(
          'Transaksi selesai',
          '${metrics['completed_transactions'] ?? 0}',
          Icons.verified,
        ),
        _metric(
          'Aktor aktif',
          '${activeSources + activeProcessors}',
          Icons.groups,
        ),
        _metric(
          'Emisi terhindar',
          '${metrics['emissions_avoided_kg'] ?? 0} kg CO₂e',
          Icons.air,
        ),
        const SizedBox(height: 12),
        Text(
          'Target bulan terpilih: ${metrics['monthly_target_kg'] ?? '-'} kg · Formula ${metrics['formula_version'] ?? '-'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        ...((metrics['provenance_components'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (component) => Text(
                'Provenance: ${component['formula_version'] ?? '-'} · baseline ${component['baseline_id'] ?? '-'} · faktor ${component['emissions_factor'] ?? '-'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
      ],
    );
  }
}

class _Districts extends StatelessWidget {
  const _Districts();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Wilayah', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const ListTile(
        leading: Icon(Icons.location_city),
        title: Text('Semarang'),
        subtitle: Text(
          'Agregat wilayah tersedia offline; peta bukan prasyarat matching.',
        ),
      ),
    ],
  );
}

class _Report extends StatelessWidget {
  const _Report({required this.metrics});
  final Map<String, dynamic> metrics;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Laporan dampak', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          title: const Text('Emisi terhindar (estimasi)'),
          subtitle: Text(
            '${metrics['emissions_avoided_kg'] ?? 0} kg CO₂e · faktor ${metrics['emissions_factor'] ?? '-'} · Formula ${metrics['formula_version'] ?? '-'}',
          ),
        ),
      ),
      Card(
        child: ListTile(
          title: Text('Nilai ekonomi (estimasi)'),
          subtitle: Text('Faktor historis tersimpan per transaksi.'),
          trailing: Text('${metrics['economic_value'] ?? 0}'),
        ),
      ),
    ],
  );
}

class _DlhProfile extends StatelessWidget {
  const _DlhProfile();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: const [
      Text('Profil DLH'),
      ListTile(
        title: Text('Dinas Lingkungan Hidup Kota Semarang'),
        subtitle: Text('Akses read-only · agregat terverifikasi'),
      ),
    ],
  );
}

Widget _metric(String title, String value, IconData icon) => Card(
  child: ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(value),
  ),
);
