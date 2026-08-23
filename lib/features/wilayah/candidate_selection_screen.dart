import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/role_snapshot_provider.dart';

class CandidateSelectionScreen extends ConsumerWidget {
  const CandidateSelectionScreen({super.key, required this.submissionId});
  final String submissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(roleSnapshotProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            body: Center(child: Text('Kandidat belum tersedia: $error')),
          ),
          data: (_) => _content(context, ref),
        );
  }

  Widget _content(BuildContext context, WidgetRef ref) {
    final submission = RoleSnapshot.current.submissions.firstWhere(
      (row) => row['id']?.toString() == submissionId,
      orElse: () => const <String, dynamic>{},
    );
    final organic = submission['kategori'] == 'organik';
    final candidates =
        RoleSnapshot.current.candidates
            .where((row) => row['submission_id']?.toString() == submissionId)
            .toList()
          ..sort((a, b) => (a['rank'] as num).compareTo(b['rank'] as num));
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih kandidat pickup')),
      body: candidates.isEmpty
          ? const Center(
              child: Text(
                'Kandidat belum tersedia. Coba lagi setelah data dimuat.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  organic
                      ? 'Organik: kompatibilitas 50% · jarak invers 30% · kapasitas 20%. Hard filter: approved, radius, kapasitas, minimum pickup.'
                      : 'Anorganik: material 40% · nilai referensi 30% · minimum volume 30%. Hard filter: approved, radius, kapasitas, minimum pickup.',
                ),
                const SizedBox(height: 12),
                ...candidates.map(
                  (row) => Card(
                    child: ListTile(
                      title: Text(
                        '#${row['rank']} · ${row['processor_name'] ?? 'Mitra terverifikasi'}',
                      ),
                      subtitle: Text(
                        '${organic ? 'Kompatibilitas' : 'Material'} ${row['compatibility_score']} · '
                        'Jarak ${row['approximate_distance_km'] ?? 'perkiraan'} km · '
                        'Kapasitas ${row['available_capacity_kg'] ?? '-'} / ${row['total_capacity_kg'] ?? '-'} kg\n'
                        '${organic ? 'Jarak invers' : 'Nilai referensi'} ${organic ? row['distance_score'] : row['reference_value_score']} · '
                        'Minimum ${row['minimum_volume_score'] ?? '-'} · Total ${row['total_score']}\n'
                        'Pickup ${row['pickup_available'] == false ? 'tidak tersedia' : 'tersedia'} · '
                        'minimum ${row['minimum_pickup_kg'] ?? '-'} kg',
                      ),
                      isThreeLine: true,
                      trailing: FilledButton(
                        onPressed: () async {
                          await ref
                              .read(submissionRepositoryProvider)
                              .selectCandidate(
                                submissionId,
                                row['processor_id'].toString(),
                              );
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Pilih'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
