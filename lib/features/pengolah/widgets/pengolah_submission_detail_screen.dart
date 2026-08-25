import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/services/submission_flow_service.dart';
import '../../../core/session/testing_accounts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/submission_model.dart';

/// Live detail screen for one submission, driven entirely by
/// [SubmissionModel.flowStatus] — same doc a Sumber device is watching on
/// its own progress screen, so actions taken here (accept, mark received,
/// approve/dispute) show up there in real time. Reached only from the
/// connected (non-`kPreviewMode`) Pengolah Setoran tab.
class PengolahSubmissionDetailScreen extends ConsumerWidget {
  const PengolahSubmissionDetailScreen({super.key, required this.submissionId});

  final String submissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(submissionRepositoryProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Informasi Setoran'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<SubmissionModel?>(
        stream: repo.watchSubmission(submissionId),
        builder: (context, snapshot) {
          final submission = snapshot.data;
          if (submission == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _DetailBody(submission: submission);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.submission});

  final SubmissionModel submission;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _acting = false;
  bool _showDisputeForm = false;
  final _catatanController = TextEditingController();

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? doneMessage}) async {
    setState(() => _acting = true);
    try {
      await action();
      if (mounted && doneMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(doneMessage)));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final flow = ref.read(submissionFlowServiceProvider);
    final beratLabel = NumberFormat.decimalPattern('id_ID').format(s.beratKg);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: s.kategori == WasteCategory.organik
                    ? AppColors.organikSoft
                    : AppColors.anorganikSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                s.kategori == WasteCategory.organik
                    ? Icons.eco_rounded
                    : Icons.recycling_rounded,
                color: s.kategori == WasteCategory.organik
                    ? AppColors.organik
                    : AppColors.anorganik,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.namaSumber ?? 'Sumber', style: AppTextStyles.h3),
                  const SizedBox(height: 2),
                  Text('${s.subtipe} · $beratLabel kg',
                      style: AppTextStyles.captionMuted),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            s.flowStatus.label,
            style: AppTextStyles.captionMuted
                .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 18),
        if (s.alamat != null && s.alamat!.isNotEmpty)
          _InfoRow(
            icon: Icons.place_outlined,
            label: 'Alamat',
            value: s.alamat!,
          ),
        if (s.deliveryMode != null) ...[
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.local_shipping_outlined,
            label: 'Mode Pengiriman',
            value: s.deliveryMode!.label,
          ),
        ],
        if (s.catatan != null && s.catatan!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.notes_rounded,
            label: 'Catatan Sumber',
            value: s.catatan!,
          ),
        ],
        const SizedBox(height: 20),
        Text('Detail yang Disetor', style: AppTextStyles.h3),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.subtipe, style: AppTextStyles.bodyBold),
                Text('$beratLabel kg',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildActions(s, flow),
      ],
    );
  }

  Widget _buildActions(SubmissionModel s, SubmissionFlowService flow) {
    switch (s.flowStatus) {
      case SubmissionFlowStatus.menungguKonfirmasi:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _acting
                    ? null
                    : () => _run(
                          () => flow.confirmByPengolah(
                            submissionId: s.id,
                            pengolahUid: ref.read(currentUidProvider).valueOrNull ?? '',
                            pengolahNama: kTestingPengolahAccount.displayName,
                            pengolahTelepon: kTestingPengolahAccount.telepon,
                          ),
                          doneMessage: 'Permintaan diterima.',
                        ),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Terima'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _acting
                    ? null
                    : () => _run(
                          () => flow.rejectByPengolah(
                            submissionId: s.id,
                            pengolahNama: kTestingPengolahAccount.displayName,
                          ),
                          doneMessage: 'Permintaan ditolak.',
                        ),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary),
                child: const Text('Tolak'),
              ),
            ),
          ],
        );

      case SubmissionFlowStatus.dikonfirmasi:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _acting
                ? null
                : () => _run(
                      () => flow.markDiterimaPengolah(s.id),
                      doneMessage: 'Ditandai sudah diterima, lanjut verifikasi.',
                    ),
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('Tandai Sudah Diterima'),
          ),
        );

      case SubmissionFlowStatus.diterimaPengolah:
        return const _InfoBanner(text: 'Menyiapkan verifikasi...');

      case SubmissionFlowStatus.sedangDiverifikasi:
        if (_showDisputeForm) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Catatan ketidaksesuaian', style: AppTextStyles.caption),
              const SizedBox(height: 6),
              TextField(
                controller: _catatanController,
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: 'Contoh: berat aktual lebih ringan dari input'),
              ),
              const SizedBox(height: 6),
              Text(
                'Sumber tetap dapat poin minimal karena sampah sudah '
                'diberikan — ini bukan pembatalan.',
                style: AppTextStyles.captionMuted,
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _acting
                    ? null
                    : () {
                        if (_catatanController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Catatan wajib diisi.')),
                          );
                          return;
                        }
                        _run(
                          () => flow.rejectVerifikasi(
                            submissionId: s.id,
                            catatan: _catatanController.text.trim(),
                          ),
                          doneMessage: 'Ketidaksesuaian dikirim, poin minimal diberikan.',
                        );
                      },
                child: const Text('Kirim Ketidaksesuaian'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _acting
                    ? null
                    : () => setState(() => _showDisputeForm = false),
                child: const Text('Batal'),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _acting
                    ? null
                    : () => _run(
                          () => flow.approveVerifikasi(s.id),
                          doneMessage: 'Setoran disetujui, poin ditambahkan.',
                        ),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Sesuai, Setujui'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _acting ? null : () => setState(() => _showDisputeForm = true),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Tidak Sesuai'),
              ),
            ),
          ],
        );

      case SubmissionFlowStatus.disetujui:
      case SubmissionFlowStatus.selesaiPoinMinimal:
        return _InfoBanner(
            text: 'Selesai — ${s.finalPoin ?? 0} poin ditambahkan ke Sumber.');

      case SubmissionFlowStatus.ditolakPengolah:
        return const _InfoBanner(text: 'Permintaan ini sudah ditolak.');
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.captionMuted),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
    );
  }
}
