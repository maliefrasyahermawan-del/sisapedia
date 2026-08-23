import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../preview/preview_store.dart';
import '../session/session_mode.dart';

/// Stable role data shape shared by Preview and Supabase screens.
/// Normal mode only loads tables permitted to the current role.
class RoleSnapshot {
  static RoleSnapshot current = const RoleSnapshot();
  static String currentProcessorId = 'preview-pengolah';

  const RoleSnapshot({
    this.profiles = const [],
    this.submissions = const [],
    this.candidates = const [],
    this.offers = const [],
    this.transactions = const [],
    this.capacities = const [],
    this.redeems = const [],
    this.audits = const [],
    this.content = const [],
    this.events = const [],
    this.error,
    this.formula = const {},
  });

  final List<Map<String, dynamic>> profiles,
      submissions,
      candidates,
      offers,
      transactions,
      capacities,
      redeems,
      audits,
      content,
      events;
  final String? error;
  final Map<String, dynamic> formula;

  static RoleSnapshot fromPreview() {
    final profiles = PreviewStore.profiles
        .map(
          (row) => <String, dynamic>{
            ...row,
            if (row['evidence_path'] != null)
              'evidence_url': row['evidence_url'] ?? row['evidence_path'],
          },
        )
        .toList();
    final transactions = PreviewStore.transactions
        .map(
          (row) => <String, dynamic>{
            ...row,
            if (row['evidence_path'] != null)
              'evidence_url': row['evidence_url'] ?? row['evidence_path'],
            if (row['weighing_evidence_path'] != null)
              'evidence_url':
                  row['evidence_url'] ?? row['weighing_evidence_path'],
          },
        )
        .toList();
    final submissions = PreviewStore.submissions
        .map((row) => <String, dynamic>{...row})
        .toList();
    for (final submission in submissions) {
      final transaction = transactions.firstWhere(
        (row) => row['submission_id'] == submission['id'],
        orElse: () => const <String, dynamic>{},
      );
      if (transaction['evidence_url'] != null) {
        submission['evidence_url'] = transaction['evidence_url'];
      }
    }
    return RoleSnapshot(
      profiles: profiles,
      submissions: submissions,
      candidates: List<Map<String, dynamic>>.from(PreviewStore.candidates),
      offers: List<Map<String, dynamic>>.from(PreviewStore.offers),
      transactions: transactions,
      capacities: List<Map<String, dynamic>>.from(PreviewStore.capacities),
      redeems: List<Map<String, dynamic>>.from(PreviewStore.redeems),
      audits: List<Map<String, dynamic>>.from(PreviewStore.audits),
      content: List<Map<String, dynamic>>.from(PreviewStore.content),
      events: const [],
      formula: PreviewStore.formula,
    );
  }
}

final roleSnapshotProvider = StreamProvider<RoleSnapshot>((ref) {
  if (ref.watch(sessionModeProvider) == SessionMode.demo) {
    return Stream.multi((controller) {
      void emit() {
        final snapshot = RoleSnapshot.fromPreview();
        RoleSnapshot.currentProcessorId = 'preview-pengolah';
        RoleSnapshot.current = snapshot;
        controller.add(snapshot);
      }

      emit();
      final subscription = PreviewStore.changes.listen((_) => emit());
      controller.onCancel = subscription.cancel;
    });
  }

  try {
    final client = Supabase.instance.client;
    return Stream.multi((controller) {
      var closed = false;
      var loading = false;
      Future<void> refresh() async {
        if (closed || loading) return;
        loading = true;
        try {
          controller.add(await _loadNormalSnapshot());
        } finally {
          loading = false;
        }
      }

      refresh();
      final subscriptions = <StreamSubscription<dynamic>>[];
      for (final table in const [
        'submissions',
        'match_candidates',
        'offers',
        'transactions',
        'notifications',
        'processor_profiles',
        'content',
        'events',
      ]) {
        subscriptions.add(
          client
              .from(table)
              .stream(primaryKey: ['id'])
              .listen(
                (_) => refresh(),
                onError: (Object error, StackTrace stack) {
                  controller.add(
                    RoleSnapshot(error: 'Realtime peran gagal dimuat: $error'),
                  );
                },
              ),
        );
      }
      controller.onCancel = () async {
        closed = true;
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  } catch (_) {
    return Stream.fromFuture(_loadNormalSnapshot());
  }
});

Future<List<Map<String, dynamic>>> _safeRows(
  Future<dynamic> Function() query, {
  bool critical = false,
}) async {
  try {
    final value = await query();
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  } catch (error) {
    if (critical) rethrow;
    return const [];
  }
}

Future<List<Map<String, dynamic>>> _enrichCandidates(
  SupabaseClient client,
  List<Map<String, dynamic>> candidates,
) async {
  final ids = candidates
      .map((row) => row['processor_id']?.toString())
      .whereType<String>()
      .toSet()
      .toList();
  if (ids.isEmpty) return candidates;
  final processors = await _safeRows(
    () => client
        .from('processor_profiles')
        .select(
          'id,display_name,materials,available_capacity_kg,total_capacity_kg,minimum_pickup_kg,pickup_available,pickup_start_time,pickup_end_time',
        )
        .inFilter('id', ids),
    critical: true,
  );
  for (final candidate in candidates) {
    final processor = processors.firstWhere(
      (row) => row['id']?.toString() == candidate['processor_id']?.toString(),
      orElse: () => const <String, dynamic>{},
    );
    candidate.addAll({
      if (processor['display_name'] != null)
        'processor_name': processor['display_name'],
      if (processor['materials'] != null)
        'processor_materials': processor['materials'],
      if (processor['available_capacity_kg'] != null)
        'available_capacity_kg': processor['available_capacity_kg'],
      if (processor['total_capacity_kg'] != null)
        'total_capacity_kg': processor['total_capacity_kg'],
      if (processor['minimum_pickup_kg'] != null)
        'minimum_pickup_kg': processor['minimum_pickup_kg'],
      if (processor['pickup_available'] != null)
        'pickup_available': processor['pickup_available'],
      if (processor['pickup_start_time'] != null)
        'pickup_start_time': processor['pickup_start_time'],
      if (processor['pickup_end_time'] != null)
        'pickup_end_time': processor['pickup_end_time'],
    });
  }
  return candidates;
}

Future<String?> _signedProcessorEvidence(
  SupabaseClient client,
  String path,
) async {
  try {
    return await client.storage
        .from('processor-evidence')
        .createSignedUrl(path, 3600);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _submission(Map<String, dynamic> row) => {
  ...row,
  'kategori': row['kategori'] ?? row['material_category'],
  'subtipe': row['subtipe'] ?? row['material_subtype'],
  'berat_kg': row['berat_kg'] ?? row['estimated_weight_kg'],
  'partner_id': row['partner_id'] ?? row['selected_processor_id'],
  'source_id': row['source_user_id'] ?? row['source_id'] ?? row['created_by'],
  'status': row['status'] == 'en_route' ? 'enRoute' : row['status'],
};

Future<RoleSnapshot> _loadNormalSnapshot() async {
  const empty = RoleSnapshot();
  try {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      RoleSnapshot.current = empty;
      return empty;
    }
    final ownProfile = await client
        .from('profiles')
        .select('id,name,primary_role')
        .eq('id', uid)
        .maybeSingle();
    if (ownProfile == null) {
      const snapshot = RoleSnapshot(error: 'Profil akun belum diprovision.');
      RoleSnapshot.current = snapshot;
      return snapshot;
    }
    final role = ownProfile['primary_role']?.toString();
    if (!const {'sumber', 'pengolah', 'dlh', 'admin'}.contains(role)) {
      const snapshot = RoleSnapshot(error: 'Peran akun tidak valid.');
      RoleSnapshot.current = snapshot;
      return snapshot;
    }
    final profiles = <Map<String, dynamic>>[
      Map<String, dynamic>.from(ownProfile),
    ];

    if (role == 'sumber') {
      final submissions = (await _safeRows(
        () => client
            .from('submissions')
            .select('*')
            .eq('source_user_id', uid)
            .order('created_at', ascending: false),
        critical: true,
      )).map(_submission).toList();
      final ids = submissions
          .map((row) => row['id'])
          .whereType<String>()
          .toList();
      final transactions = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : await _safeRows(
              () => client
                  .from('transactions')
                  .select('*')
                  .inFilter('submission_id', ids),
              critical: true,
            );
      for (final transaction in transactions) {
        final path = transaction['weighing_evidence_path']?.toString();
        if (path != null && path.isNotEmpty) {
          try {
            transaction['evidence_url'] = await client.storage
                .from('weighing-evidence')
                .createSignedUrl(path, 3600);
          } catch (_) {
            transaction['evidence_url'] = null;
          }
        }
      }
      for (final submission in submissions) {
        final transaction = transactions
            .cast<Map<String, dynamic>>()
            .firstWhere(
              (row) => row['submission_id'] == submission['id'],
              orElse: () => <String, dynamic>{},
            );
        if (transaction['evidence_url'] != null) {
          submission['evidence_url'] = transaction['evidence_url'];
        }
      }
      final candidateRows = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : await _enrichCandidates(
              client,
              await _safeRows(
                () => client
                    .from('match_candidates')
                    .select('*')
                    .inFilter('submission_id', ids),
                critical: true,
              ),
            );
      final snapshot = RoleSnapshot(
        profiles: profiles,
        submissions: submissions,
        candidates: candidateRows,
        offers: ids.isEmpty
            ? const []
            : await _safeRows(
                () => client
                    .from('offers')
                    .select('*')
                    .inFilter('submission_id', ids),
                critical: true,
              ),
        transactions: transactions,
        redeems: await _safeRows(
          () => client.from('redeem_requests').select('*').eq('user_id', uid),
          critical: true,
        ),
      );
      RoleSnapshot.current = snapshot;
      return snapshot;
    }

    if (role == 'pengolah') {
      RoleSnapshot.currentProcessorId = uid;
      final processorRows = await _safeRows(
        () => client.from('processor_profiles').select('*').eq('id', uid),
        critical: true,
      );
      if (processorRows.isNotEmpty) {
        profiles.add(<String, dynamic>{
          ...processorRows.first,
          'identity': processorRows.first['display_name'] ?? uid,
          'primary_role': 'pengolah',
          'processor_status': processorRows.first['status'],
        });
      } else {
        // A role without an application is not an operational processor.
        // Keep the authenticated identity visible so the application form is
        // reachable, but force the dedicated pending state.
        final own = profiles.firstWhere(
          (row) => row['id'] == uid,
          orElse: () => <String, dynamic>{},
        );
        if (own.isNotEmpty) own['processor_status'] = 'pending';
      }
      final submissions = (await _safeRows(
        () => client
            .from('submissions')
            .select('*')
            .eq('selected_processor_id', uid),
        critical: true,
      )).map(_submission).toList();
      final selectedIds = submissions
          .where(
            (row) => [
              'accepted',
              'en_route',
              'weighed',
              'completed',
              'disputed',
            ].contains(row['status']),
          )
          .map((row) => row['id'])
          .whereType<String>()
          .toList();
      if (selectedIds.isNotEmpty) {
        final locations = await _safeRows(
          () => client
              .from('submission_locations')
              .select(
                'submission_id,precise_address,precise_latitude,precise_longitude',
              )
              .inFilter('submission_id', selectedIds),
          critical: true,
        );
        for (final submission in submissions) {
          final location = locations.firstWhere(
            (row) => row['submission_id'] == submission['id'],
            orElse: () => <String, dynamic>{},
          );
          if (location.isNotEmpty) submission.addAll(location);
        }
      }
      final snapshot = RoleSnapshot(
        profiles: profiles,
        offers: await _safeRows(
          () => client.from('offers').select('*').eq('processor_id', uid),
          critical: true,
        ),
        submissions: submissions,
        transactions: await _safeRows(
          () => client.from('transactions').select('*').eq('processor_id', uid),
          critical: true,
        ),
        capacities:
            (await _safeRows(
                  () => client
                      .from('processor_profiles')
                      .select('*')
                      .eq('id', uid),
                  critical: true,
                ))
                .map(
                  (row) => <String, dynamic>{
                    ...row,
                    'processor_id': row['id'],
                    'available_kg': row['available_capacity_kg'],
                    'total_kg': row['total_capacity_kg'],
                  },
                )
                .toList(),
      );
      RoleSnapshot.current = snapshot;
      return snapshot;
    }

    // Admin queue: merge processor rows into the profile shape. DLH does not
    // use this provider and therefore cannot read individual actors/locations.
    final processorRows = await _safeRows(
      () => client.from('processor_profiles').select('*'),
      critical: true,
    );
    for (final row in processorRows) {
      final profile = <String, dynamic>{
        ...row,
        'identity': row['display_name'] ?? row['name'] ?? row['id'],
        'primary_role': 'pengolah',
        'processor_status': row['status'],
      };
      final path = row['evidence_path']?.toString();
      if (path != null && path.isNotEmpty) {
        profile['evidence_url'] = await _signedProcessorEvidence(client, path);
      }
      profiles.add(profile);
    }
    final formulaRows = await _safeRows(
      () => client
          .from('formula_versions')
          .select('*')
          .eq('active', true)
          .limit(1),
      critical: true,
    );
    final snapshot = RoleSnapshot(
      profiles: profiles,
      submissions: (await _safeRows(
        () => client
            .from('submissions')
            .select('*')
            .order('created_at', ascending: false),
        critical: true,
      )).map(_submission).toList(),
      redeems: await _safeRows(
        () => client
            .from('redeem_requests')
            .select('*')
            .order('created_at', ascending: false),
        critical: true,
      ),
      audits: await _safeRows(
        () => client
            .from('audit_events')
            .select('*')
            .order('created_at', ascending: false),
        critical: true,
      ),
      transactions: await _signedAdminTransactions(client),
      content: await _safeRows(
        () => client.from('content').select('*').inFilter('status', [
          'submitted',
          'approved',
          'rejected',
        ]),
        critical: true,
      ),
      events: await _safeRows(
        () => client.from('events').select('*').inFilter('status', [
          'submitted',
          'approved',
          'rejected',
        ]),
        critical: true,
      ),
      formula: formulaRows.isEmpty ? const {} : formulaRows.first,
    );
    RoleSnapshot.current = snapshot;
    return snapshot;
  } catch (error) {
    RoleSnapshot.current = empty;
    return RoleSnapshot(error: 'Gagal memuat data peran: $error');
  }
}

Future<List<Map<String, dynamic>>> _signedAdminTransactions(
  SupabaseClient client,
) async {
  final rows = await _safeRows(
    () => client
        .from('transactions')
        .select('*')
        .order('created_at', ascending: false),
    critical: true,
  );
  for (final row in rows) {
    final path = row['weighing_evidence_path']?.toString();
    if (path == null || path.isEmpty) continue;
    try {
      row['evidence_url'] = await client.storage
          .from('weighing-evidence')
          .createSignedUrl(path, 3600);
    } catch (_) {
      row['evidence_url'] = null;
    }
  }
  return rows;
}
