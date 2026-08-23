import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/role_snapshot_provider.dart';
import '../../core/providers/repository_providers.dart';

class AdminRoleScreen extends ConsumerWidget {
  const AdminRoleScreen({super.key, required this.tab});
  final int tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(roleSnapshotProvider)
        .when(
          data: (snapshot) {
            if (snapshot.error != null) {
              return Center(child: Text(snapshot.error!));
            }
            return switch (tab) {
              1 => const _Transactions(),
              2 => _Redeem(ref: ref),
              3 => const _Audit(),
              4 => const _AdminProfile(),
              _ => _Queue(ref: ref),
            };
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Data peran belum tersedia: $error')),
        );
  }
}

class _Queue extends StatelessWidget {
  const _Queue({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final pending = RoleSnapshot.current.profiles
        .where(
          (profile) =>
              profile['primary_role'] == 'pengolah' &&
              profile['processor_status'] == 'pending',
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Antrean verifikasi',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (pending.isEmpty) const Text('Tidak ada pengolah pending.'),
        ...pending.map(
          (profile) => Card(
            child: ListTile(
              title: Text(profile['identity']?.toString() ?? ''),
              subtitle: Text(
                '${profile['name'] ?? ''}\n'
                'Pin: ${profile['latitude'] ?? '-'}, ${profile['longitude'] ?? '-'} · '
                '${profile['evidence_url'] == null ? 'Bukti belum tersedia' : 'Bukti tersedia untuk ditinjau'}',
              ),
              isThreeLine: true,
              onTap: profile['evidence_url'] == null
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Bukti fasilitas'),
                        content: _EvidencePreview(
                          url: profile['evidence_url'].toString(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Tutup'),
                          ),
                        ],
                      ),
                    ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  try {
                    await ref
                        .read(partnerRepositoryProvider)
                        .reviewProcessor(
                          profile['id'].toString(),
                          approve: value == 'approve',
                          reason: value == 'approve'
                              ? 'Bukti diverifikasi'
                              : 'Bukti belum sesuai',
                        );
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Aksi gagal: $error')),
                      );
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'approve', child: Text('Setujui')),
                  PopupMenuItem(value: 'reject', child: Text('Tolak')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Transactions extends ConsumerWidget {
  const _Transactions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = RoleSnapshot.current.submissions
        .where((submission) => submission['status'] == 'disputed')
        .toList();
    final completed = RoleSnapshot.current.submissions
        .where((submission) => submission['status'] == 'completed')
        .length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Transaksi & sengketa',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text('$completed transaksi selesai'),
        const SizedBox(height: 8),
        if (disputes.isEmpty) const Text('Tidak ada sengketa aktif.'),
        ...disputes.map(
          (submission) => Card(
            child: ListTile(
              title: Text(submission['subtipe']?.toString() ?? ''),
              subtitle: Text(
                'Sengketa: ${submission['dispute_reason'] ?? 'tanpa alasan'}\n'
                '${_evidenceFor(submission['id']?.toString()) == null ? 'Bukti timbang tidak tersedia' : 'Bukti timbang tersedia'}',
              ),
              onTap: () {
                final url = _evidenceFor(submission['id']?.toString());
                if (url == null) return;
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Bukti timbang'),
                    content: _EvidencePreview(url: url),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                );
              },
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  double? correctedWeight;
                  final weight = TextEditingController(
                    text:
                        submission['actual_weight_kg']?.toString() ??
                        submission['berat_kg']?.toString() ??
                        '',
                  );
                  final reasonController = TextEditingController(
                    text: value == 'approve'
                        ? 'Bukti disetujui Admin'
                        : 'Bukti tidak sesuai',
                  );
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Selesaikan sengketa'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: weight,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Berat koreksi (kg, opsional)',
                            ),
                          ),
                          TextField(
                            controller: reasonController,
                            decoration: const InputDecoration(
                              labelText: 'Alasan keputusan',
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: Text(
                            value == 'approve' ? 'Setujui' : 'Batalkan',
                          ),
                        ),
                      ],
                    ),
                  );
                  correctedWeight = double.tryParse(weight.text);
                  final reason = reasonController.text.trim();
                  weight.dispose();
                  reasonController.dispose();
                  if (confirmed != true || reason.isEmpty) return;
                  try {
                    await ref
                        .read(submissionRepositoryProvider)
                        .resolveDispute(
                          submission['id'].toString(),
                          approve: value == 'approve',
                          reason: reason,
                          correctedWeightKg: correctedWeight,
                        );
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Aksi gagal: $error')),
                      );
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'approve',
                    child: Text('Setujui sengketa'),
                  ),
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text('Batalkan transaksi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _evidenceFor(String? submissionId) {
    if (submissionId == null) return null;
    final row = RoleSnapshot.current.transactions.firstWhere(
      (transaction) => transaction['submission_id']?.toString() == submissionId,
      orElse: () => const <String, dynamic>{},
    );
    final url = row['evidence_url']?.toString();
    return url == null || url.isEmpty ? null : url;
  }
}

class _EvidencePreview extends StatelessWidget {
  const _EvidencePreview({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            SelectableText('Bukti lokal gagal dimuat: $url'),
      );
    }
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => SelectableText('Bukti gagal dimuat: $url'),
      );
    }
    return SelectableText('Bukti simulasi tersimpan di: $url');
  }
}

class _Redeem extends StatelessWidget {
  const _Redeem({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final rows = RoleSnapshot.current.redeems;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Redeem', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (rows.isEmpty) const Text('Belum ada permintaan.'),
        ...rows.map(
          (row) => Card(
            child: ListTile(
              title: Text(row['description']?.toString() ?? ''),
              subtitle: Text('${row['status']} · ${row['points']} poin'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  try {
                    if (value == 'fulfilled') {
                      await ref
                          .read(pointsRepositoryProvider)
                          .fulfillRedeem(
                            row['id'].toString(),
                            reason: 'Bukti penyaluran diterima',
                          );
                    } else {
                      await ref
                          .read(pointsRepositoryProvider)
                          .reviewRedeem(
                            row['id'].toString(),
                            approve: value == 'approved',
                            reason: 'Diproses Admin',
                          );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Aksi gagal: $error')),
                      );
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'approved', child: Text('Setujui')),
                  PopupMenuItem(value: 'rejected', child: Text('Tolak')),
                  PopupMenuItem(
                    value: 'fulfilled',
                    child: Text('Tandai fulfilled'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Audit extends ConsumerWidget {
  const _Audit();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Audit immutable', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      ...[...RoleSnapshot.current.content, ...RoleSnapshot.current.events]
          .where((row) => row['status'] == 'submitted')
          .map(
            (row) => Card(
              child: ListTile(
                title: Text(row['title']?.toString() ?? 'Draft'),
                subtitle: const Text('Menunggu moderasi'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    try {
                      await ref
                          .read(contentRepositoryProvider)
                          .moderateDraft(
                            row['id'].toString(),
                            approve: value == 'approve',
                            reason: value == 'approve'
                                ? 'Konten sesuai panduan'
                                : 'Perlu perbaikan',
                          );
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Moderasi gagal: $error')),
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'approve', child: Text('Setujui')),
                    PopupMenuItem(value: 'reject', child: Text('Tolak')),
                  ],
                ),
              ),
            ),
          ),
      ...RoleSnapshot.current.audits.map(
        (audit) => ListTile(
          leading: const Icon(Icons.security),
          title: Text(audit['action']?.toString() ?? ''),
          subtitle: Text('${audit['entity_type']} · ${audit['entity_id']}'),
        ),
      ),
    ],
  );
}

class _AdminProfile extends StatelessWidget {
  const _AdminProfile();

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.all(20),
    children: [
      Text('Profil Admin'),
      ListTile(
        title: Text('Admin SisaPedia'),
        subtitle: Text(
          'Provisioned server-side · seluruh aksi sensitif diaudit',
        ),
      ),
    ],
  );
}
