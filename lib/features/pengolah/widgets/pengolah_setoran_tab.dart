import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/preview/preview_mode.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/services/submission_flow_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/submission_model.dart';
import '../data/pengolah_mock.dart';
import 'pengolah_submission_detail_screen.dart';

/// `kPreviewMode` (fully offline compiled builds, no Firebase) keeps the
/// original static mock list below. Everywhere else, this streams the real
/// Sumber<->Pengolah exchange from Firestore — see
/// `core/services/submission_flow_service.dart`.
class PengolahSetoranTab extends ConsumerWidget {
  const PengolahSetoranTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kPreviewMode) return const _OfflineSetoranList();

    final uid = ref.watch(currentUidProvider).valueOrNull;
    if (uid == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final flow = ref.watch(submissionFlowServiceProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text('Setoran Masuk', style: AppTextStyles.h1),
        const SizedBox(height: 2),
        Text('Kelola konfirmasi setoran dari mitra sumber',
            style: AppTextStyles.captionMuted),
        const SizedBox(height: 18),
        Text('Perlu Dikonfirmasi', style: AppTextStyles.h3),
        const SizedBox(height: 10),
        StreamBuilder<List<SubmissionModel>>(
          stream: flow.watchIncomingQueue(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const [];
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (items.isEmpty) {
              return _EmptyHint('Belum ada setoran baru.');
            }
            return Column(
              children: [
                for (final item in items) ...[
                  _SubmissionCard(submission: item),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text('Sedang Diproses', style: AppTextStyles.h3),
        const SizedBox(height: 10),
        StreamBuilder<List<SubmissionModel>>(
          stream: flow.watchPengolahAktif(uid),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const [];
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (items.isEmpty) {
              return _EmptyHint('Tidak ada setoran yang sedang diproses.');
            }
            return Column(
              children: [
                for (final item in items) ...[
                  _SubmissionCard(submission: item),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: AppTextStyles.captionMuted, textAlign: TextAlign.center),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.submission});

  final SubmissionModel submission;

  @override
  Widget build(BuildContext context) {
    final beratLabel =
        NumberFormat.decimalPattern('id_ID').format(submission.beratKg);
    final accentColor = submission.kategori == WasteCategory.organik
        ? AppColors.organik
        : AppColors.anorganik;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            PengolahSubmissionDetailScreen(submissionId: submission.id),
      )),
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
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                submission.kategori == WasteCategory.organik
                    ? Icons.eco_rounded
                    : Icons.recycling_rounded,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(submission.namaSumber ?? 'Sumber',
                      style: AppTextStyles.bodyBold),
                  const SizedBox(height: 2),
                  Text('${submission.subtipe} · $beratLabel kg',
                      style: AppTextStyles.captionMuted),
                  const SizedBox(height: 4),
                  Text(
                    submission.flowStatus.label,
                    style: AppTextStyles.captionMuted
                        .copyWith(color: accentColor, fontWeight: FontWeight.w700),
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

class _OfflineSetoranList extends StatelessWidget {
  const _OfflineSetoranList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text('Setoran Masuk', style: AppTextStyles.h1),
        const SizedBox(height: 2),
        Text('Kelola konfirmasi setoran dari mitra sumber',
            style: AppTextStyles.captionMuted),
        const SizedBox(height: 18),
        Text('Perlu Dikonfirmasi', style: AppTextStyles.h3),
        const SizedBox(height: 10),
        for (final sub in pengolahSubmissions) ...[
          _OfflineSubmissionCard(submission: sub),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _OfflineSubmissionCard extends StatelessWidget {
  const _OfflineSubmissionCard({required this.submission});

  final PengolahSubmission submission;

  void _respond(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: submission.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(submission.nama, style: AppTextStyles.bodyBold),
                    const SizedBox(height: 2),
                    Text(submission.ringkas, style: AppTextStyles.captionMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionPill(
                  label: 'Terima',
                  background: AppColors.primary,
                  foreground: Colors.white,
                  onTap: () =>
                      _respond(context, 'Setoran ${submission.nama} diterima.'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionPill(
                  label: 'Tolak',
                  background: const Color(0xFFF1F2EF),
                  foreground: AppColors.textSecondary,
                  onTap: () =>
                      _respond(context, 'Setoran ${submission.nama} ditolak.'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.captionMuted
              .copyWith(color: foreground, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
