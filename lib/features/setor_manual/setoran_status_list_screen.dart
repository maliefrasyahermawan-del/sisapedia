import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/submission_model.dart';

/// "Lihat Status Setoran Sampah" — list of the user's own submissions
/// (any category/source), each showing its live [SubmissionFlowStatus] so
/// Sumber can check progress without having kept the original progress
/// screen open. Tapping one reopens the same live tracker
/// ([SetorProgressScreen]) via the existing `/setor/sukses` route.
class SetoranStatusListScreen extends ConsumerWidget {
  const SetoranStatusListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Status Setoran Sampah')),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<SubmissionModel>>(
              stream: ref
                  .watch(submissionRepositoryProvider)
                  .watchUserSubmissions(uid, limit: 30),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const _EmptyState();
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _SubmissionTile(
                    submission: items[i],
                    onTap: () => context.push('/setor/sukses', extra: items[i]),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 42, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text('Status Setoran: Kosong',
                style: AppTextStyles.h3, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Belum ada aktivitas setor sampah. Yuk mulai setor dari Beranda.',
              style: AppTextStyles.captionMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({required this.submission, required this.onTap});

  final SubmissionModel submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final beratLabel =
        NumberFormat.decimalPattern('id_ID').format(submission.beratKg);
    final accentColor = submission.flowStatus.isSuccessOutcome
        ? AppColors.primary
        : submission.flowStatus.isFailureOutcome
            ? AppColors.error
            : AppColors.statusSetoran;
    final dateLabel = submission.createdAt != null
        ? DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(submission.createdAt!)
        : '-';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: submission.kategori == WasteCategory.organik
                    ? AppColors.organikSoft
                    : AppColors.anorganikSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                submission.kategori == WasteCategory.organik
                    ? Icons.eco_rounded
                    : Icons.recycling_rounded,
                color: submission.kategori == WasteCategory.organik
                    ? AppColors.organik
                    : AppColors.anorganik,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${submission.subtipe} · $beratLabel kg',
                      style: AppTextStyles.bodyBold),
                  const SizedBox(height: 2),
                  Text(dateLabel, style: AppTextStyles.captionMuted),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      submission.flowStatus.label,
                      style: AppTextStyles.captionMuted.copyWith(
                          color: accentColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
