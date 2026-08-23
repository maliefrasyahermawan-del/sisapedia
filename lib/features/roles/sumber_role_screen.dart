import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/role_snapshot_provider.dart';
import '../../core/session/session_mode.dart';
import '../../data/models/submission_model.dart';

class SumberRoleScreen extends ConsumerWidget {
  const SumberRoleScreen({super.key, required this.tab});
  final int tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The snapshot supplies signed private evidence URLs in normal mode and
    // keeps the confirmation controls reactive when a weighing is recorded.
    final snapshot = ref.watch(roleSnapshotProvider);
    final uid = ref.watch(currentUidProvider).valueOrNull ?? kGuestUid;
    if (snapshot.valueOrNull?.error != null) {
      return Center(child: Text(snapshot.valueOrNull!.error!));
    }
    return switch (tab) {
      1 => _History(uid: uid),
      2 => _ActionCard(
        title: 'Sari siap membantu',
        body:
            'Jelaskan sampahmu dalam bahasa sehari-hari. Hasil AI selalu perlu kamu konfirmasi.',
        label: 'Buka Sari',
        onTap: () => context.push('/sari-chat'),
      ),
      3 => _Points(uid: uid),
      4 => _SumberProfile(uid: uid),
      _ => _Home(uid: uid),
    };
  }
}

class _Home extends ConsumerWidget {
  const _Home({required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissions = ref.watch(userSubmissionsProvider(uid));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Halo, Bu Siti', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Setoran organik dan anorganikmu tercatat di satu alur yang transparan.',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                title: 'Setor organik',
                body: 'Sisa dapur, sayur, buah',
                label: 'Mulai',
                onTap: () => context.push('/setor/organik'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                title: 'Setor anorganik',
                body: 'Plastik, kertas, logam',
                label: 'Mulai',
                onTap: () => context.push('/setor/anorganik'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ActionCard(
          title: 'Wilayah matching',
          body: 'Top-3 kandidat dengan skor, jarak perkiraan, dan kapasitas.',
          label: 'Lihat kandidat',
          onTap: () => context.push('/wilayah-pencocokan'),
        ),
        const SizedBox(height: 16),
        submissions.when(
          data: (items) => _Recent(items: items),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Data offline belum siap: $e'),
        ),
      ],
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userSubmissionsProvider(uid));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Riwayat setoran',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        state.when(
          data: (items) => _Recent(items: items, expanded: true, ref: ref),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Gagal memuat riwayat: $e'),
        ),
      ],
    );
  }
}

class _Points extends ConsumerWidget {
  const _Points({required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userPointsTransactionsProvider(uid));
    final redeems =
        ref.watch(roleSnapshotProvider).valueOrNull?.redeems ?? const [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Poin Sirkular', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        state.when(
          data: (items) => Column(
            children: [
              Text(
                '${items.fold<int>(0, (sum, e) => sum + e.jumlah)} poin tercatat',
              ),
              const SizedBox(height: 16),
              ...items.map(
                (e) => ListTile(
                  leading: Icon(
                    e.jenis.name == 'earn' ? Icons.add_circle : Icons.redeem,
                  ),
                  title: Text(e.deskripsi),
                  trailing: Text('${e.jumlah}'),
                ),
              ),
              if (redeems.isNotEmpty) ...[
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Riwayat redeem'),
                ),
                ...redeems.map(
                  (row) => ListTile(
                    dense: true,
                    title: Text(row['description']?.toString() ?? 'Redeem'),
                    subtitle: Text('${row['points'] ?? 0} poin'),
                    trailing: Text(row['status']?.toString() ?? 'submitted'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () async {
                  final amount = TextEditingController(text: '100');
                  final description = TextEditingController(
                    text: 'Voucher kompos organik',
                  );
                  final submit = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Ajukan redeem'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: amount,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Poin',
                            ),
                          ),
                          TextField(
                            controller: description,
                            decoration: const InputDecoration(
                              labelText: 'Hadiah',
                            ),
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
                          child: const Text('Kirim'),
                        ),
                      ],
                    ),
                  );
                  final points = int.tryParse(amount.text);
                  if (submit == true && points != null && points > 0) {
                    try {
                      await ref
                          .read(pointsRepositoryProvider)
                          .requestRedeem(
                            uid: uid,
                            jumlah: points,
                            deskripsi: description.text,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Permintaan redeem dikirim.'),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Redeem gagal: $error')),
                        );
                      }
                    }
                  }
                  amount.dispose();
                  description.dispose();
                },
                icon: const Icon(Icons.redeem),
                label: const Text('Ajukan redeem'),
              ),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Gagal memuat ledger: $e'),
        ),
      ],
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.items, this.expanded = false, this.ref});
  final List<SubmissionModel> items;
  final bool expanded;
  final WidgetRef? ref;
  @override
  Widget build(BuildContext context) {
    final rows = expanded ? items : items.take(3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aktivitas terbaru',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        ...rows.map((s) {
          final evidenceUrl = RoleSnapshot.current.submissions
              .firstWhere(
                (row) => row['id'] == s.id,
                orElse: () => const <String, dynamic>{},
              )['evidence_url']
              ?.toString();
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              s.kategori == WasteCategory.organik
                  ? Icons.compost_rounded
                  : Icons.recycling,
            ),
            title: Text(s.subtipe),
            subtitle: Text('${s.beratKg} kg · ${s.status.label}'),
            trailing:
                [
                      SubmissionStatus.weighed,
                      SubmissionStatus.disputed,
                    ].contains(s.status) &&
                    ref != null
                ? Wrap(
                    children: [
                      if (evidenceUrl != null && evidenceUrl.isNotEmpty)
                        IconButton(
                          tooltip: 'Lihat bukti timbang',
                          icon: const Icon(Icons.photo_outlined),
                          onPressed: () => _showEvidence(context, evidenceUrl),
                        ),
                      if (s.status == SubmissionStatus.weighed) ...[
                        IconButton(
                          tooltip: 'Konfirmasi berat',
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () => ref!
                              .read(submissionRepositoryProvider)
                              .confirmWeight(s.id),
                        ),
                        IconButton(
                          tooltip: 'Ajukan sengketa',
                          icon: const Icon(Icons.report_problem_outlined),
                          onPressed: () =>
                              _showDisputeDialog(context, ref!, s.id),
                        ),
                      ],
                    ],
                  )
                : [
                        SubmissionStatus.submitted,
                        SubmissionStatus.matching,
                        SubmissionStatus.offered,
                        SubmissionStatus.accepted,
                      ].contains(s.status) &&
                      ref != null
                ? IconButton(
                    tooltip: 'Batalkan setoran',
                    icon: const Icon(Icons.cancel_outlined),
                    onPressed: () => _showCancelDialog(context, ref!, s.id),
                  )
                : Text(s.partnerName ?? 'Mencari mitra'),
          );
        }),
      ],
    );
  }
}

Future<void> _showEvidence(BuildContext context, String url) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Bukti timbang'),
      content: url.startsWith('assets/')
          ? Image.asset(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Text('Bukti lokal tidak dapat dimuat.'),
            )
          : url.startsWith('http')
          ? Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Text('Bukti tidak dapat dimuat.'),
            )
          : SelectableText('Bukti simulasi tersimpan di: $url'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
}

Future<void> _showCancelDialog(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final reason = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Batalkan setoran?'),
      content: TextField(
        controller: reason,
        decoration: const InputDecoration(labelText: 'Alasan wajib'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Tutup'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Batalkan'),
        ),
      ],
    ),
  );
  if (ok == true && reason.text.trim().isNotEmpty) {
    try {
      await ref
          .read(submissionRepositoryProvider)
          .cancelSubmission(id, reason.text.trim());
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Pembatalan gagal: $error')));
      }
    }
  }
  reason.dispose();
}

Future<void> _showDisputeDialog(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final reason = TextEditingController();
  final submit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Ajukan sengketa'),
      content: TextField(
        controller: reason,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Alasan wajib'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Kirim'),
        ),
      ],
    ),
  );
  if (submit == true && reason.text.trim().isNotEmpty) {
    try {
      await ref
          .read(submissionRepositoryProvider)
          .disputeWeight(id, reason.text.trim());
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sengketa gagal: $error')));
      }
    }
  }
  reason.dispose();
}

class _SumberProfile extends ConsumerWidget {
  const _SumberProfile({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Profil Sumber', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(profile?.name ?? 'Bu Siti'),
          subtitle: Text(
            profile?.email.isNotEmpty == true
                ? profile!.email
                : 'Preview Mode · $uid',
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.notifications_none),
          title: const Text('Notifikasi'),
          subtitle: const Text('Status pickup, poin, dan event terbaru'),
          onTap: () => context.push('/notifikasi'),
        ),
        ListTile(
          leading: const Icon(Icons.phone_android),
          title: const Text('Hubungkan nomor telepon'),
          subtitle: const Text('OTP dikirim ke nomor yang kamu masukkan'),
          onTap: () => _linkPhone(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: const Text('Panduan SisaPedia'),
          onTap: () => context.push('/profil/info/panduan'),
        ),
      ],
    );
  }
}

Future<void> _linkPhone(BuildContext context, WidgetRef ref) async {
  final phone = TextEditingController();
  try {
    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hubungkan nomor'),
        content: TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Nomor telepon'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kirim OTP'),
          ),
        ],
      ),
    );
    if (send != true || phone.text.trim().isEmpty) return;
    try {
      await ref.read(authRepositoryProvider).linkPhone(phone.text.trim());
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OTP tidak terkirim: $error')));
      }
      return;
    }
    if (!context.mounted) return;
    final token = TextEditingController();
    try {
      final verify = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Masukkan OTP'),
          content: TextField(
            controller: token,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Kode OTP'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Verifikasi'),
            ),
          ],
        ),
      );
      if (verify != true) return;
      await ref
          .read(authRepositoryProvider)
          .verifyLinkedPhoneOtp(
            phone: phone.text.trim(),
            token: token.text.trim(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nomor berhasil dihubungkan.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OTP gagal: $error')));
      }
    } finally {
      token.dispose();
    }
  } finally {
    phone.dispose();
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.body,
    required this.label,
    required this.onTap,
  });
  final String title, body, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(body),
          const SizedBox(height: 10),
          FilledButton(onPressed: onTap, child: Text(label)),
        ],
      ),
    ),
  );
}
