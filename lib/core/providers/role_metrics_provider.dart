import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../preview/preview_store.dart';
import '../session/session_mode.dart';

final dlhCompletionMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

bool isInCompletionMonth(DateTime? value, DateTime selectedMonth) {
  if (value == null) return false;
  return value.year == selectedMonth.year && value.month == selectedMonth.month;
}

final dlhMetricsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  if (ref.watch(sessionModeProvider) == SessionMode.demo) {
    final selectedMonth = ref.watch(dlhCompletionMonthProvider);
    return Stream.multi((controller) {
      void emit() {
        final rows = PreviewStore.transactions.where((tx) {
          final completion = DateTime.tryParse(
            tx['completed_at']?.toString() ??
                tx['created_at']?.toString() ??
                '',
          );
          return isInCompletionMonth(completion, selectedMonth);
        }).toList();
        double organic = 0;
        double inorganic = 0;
        double emissions = 0;
        double economic = 0;
        for (final tx in rows) {
          final submission = PreviewStore.submissions.firstWhere(
            (row) => row['id'] == tx['submission_id'],
            orElse: () => <String, dynamic>{},
          );
          final kg = (tx['actual_weight_kg'] as num?)?.toDouble() ?? 0;
          if (submission['kategori'] == 'organik') {
            organic += kg;
          } else if (submission['kategori'] == 'anorganik') {
            inorganic += kg;
          }
          emissions +=
              kg *
              ((PreviewStore.formula['emissions_factor'] as num?)?.toDouble() ??
                  0);
          economic +=
              kg *
              ((PreviewStore.formula['economic_factor'] as num?)?.toDouble() ??
                  0);
        }
        controller.add({
          'completed_transactions': rows.length,
          'organic_kg': organic,
          'inorganic_kg': inorganic,
          'active_sources': PreviewStore.profiles
              .where((row) => row['primary_role'] == 'sumber')
              .length,
          'active_processors': PreviewStore.profiles
              .where((row) => row['primary_role'] == 'pengolah')
              .length,
          'formula_version': PreviewStore.formula['version'],
          'monthly_target_kg': PreviewStore.formula['monthly_target_kg'],
          'emissions_factor': PreviewStore.formula['emissions_factor'],
          'economic_factor': PreviewStore.formula['economic_factor'],
          'emissions_avoided_kg': emissions,
          'economic_value': economic,
          'completion_month': selectedMonth.toIso8601String().substring(0, 10),
        });
      }

      emit();
      final subscription = PreviewStore.changes.listen((_) => emit());
      controller.onCancel = subscription.cancel;
    });
  }
  final selectedMonth = ref.watch(dlhCompletionMonthProvider);
  return Stream.multi((controller) {
    var closed = false;
    Future<void> emit() async {
      if (closed) return;
      controller.add(await _loadNormalMetrics(selectedMonth));
    }

    emit();
    final subscriptions = <StreamSubscription<dynamic>>[];
    try {
      final client = Supabase.instance.client;
      for (final table in const ['transactions', 'submissions']) {
        subscriptions.add(
          client
              .from(table)
              .stream(primaryKey: ['id'])
              .listen(
                (_) => emit(),
                onError: (Object error, StackTrace stack) {
                  controller.add({
                    'error': 'Realtime DLH gagal dimuat: $error',
                  });
                },
              ),
        );
      }
    } catch (error) {
      controller.add({'error': 'Realtime DLH tidak tersedia: $error'});
    }
    controller.onCancel = () async {
      closed = true;
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });
});

Future<Map<String, dynamic>> _loadNormalMetrics(DateTime selectedMonth) async {
  try {
    final client = Supabase.instance.client;
    final result = await client.rpc(
      'dlh_city_metrics',
      params: {
        'p_completion_month': selectedMonth.toIso8601String().substring(0, 10),
      },
    );
    final rows = result is List
        ? result.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const <Map<String, dynamic>>[];
    if (rows.isEmpty) return <String, dynamic>{};
    final components = rows
        .expand((row) {
          final value = row['provenance_components'];
          return value is List ? value : [row];
        })
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    // The RPC returns one denominator-safe row per city. Do not sum distinct
    // actor counts or monthly targets across provenance/month rows here.
    final row = rows.first;
    return {
      'city_id': row['city_id'],
      'completion_month': row['completion_month'],
      'completed_transactions': row['completed_transactions'],
      'organic_kg': row['organic_kg'],
      'inorganic_kg': row['inorganic_kg'],
      'active_sources': row['active_sources'],
      'active_processors': row['active_processors'],
      'monthly_target_kg': row['target_kg'],
      'formula_version': row['formula_version'],
      'baseline_id': row['baseline_id'],
      'emissions_factor': row['emissions_factor'],
      'economic_factor': row['economic_factor'],
      'emissions_avoided_kg': row['emissions_avoided_kg'],
      'economic_value': row['economic_value'],
      'provenance_components': components,
      // Preserve every city aggregate for a multi-city UI; the displayed
      // Semarang card uses the first (and currently only seeded) city row
      // without re-summing actor denominators or targets.
      'city_metrics': rows,
    };
  } catch (_) {
    return <String, dynamic>{'error': 'Agregat DLH gagal dimuat.'};
  }
}
