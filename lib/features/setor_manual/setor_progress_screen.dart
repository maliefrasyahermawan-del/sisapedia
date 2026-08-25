import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/submission_model.dart';

/// Replaces the old static "estimasi poin" success screen (26 Agustus 2026)
/// — submitting no longer credits points right away. Instead this screen
/// streams the submission doc live and walks through the whole
/// Sumber<->Pengolah exchange: waiting for confirmation, delivery contact
/// info, arrival, verification, and finally either a points+QR receipt or
/// one of the negotiation outcomes. See [SubmissionFlowStatus] for the
/// full state machine.
class SetorProgressScreen extends ConsumerWidget {
  const SetorProgressScreen({super.key, required this.initial});

  final SubmissionModel initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(submissionRepositoryProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Progress Setoran')),
      body: StreamBuilder<SubmissionModel?>(
        stream: repo.watchSubmission(initial.id),
        initialData: initial,
        builder: (context, snapshot) {
          final submission = snapshot.data ?? initial;
          return _ProgressBody(submission: submission);
        },
      ),
    );
  }
}

/// 4 fixed checkpoints shown in `_StageTimeline` — deliberately short/generic
/// labels distinct from `SubmissionFlowStatus.label` (which is precise but
/// too long to fit under a stage dot, e.g. "Sedang Diverifikasi Pengolah").
const _stageLabels = ['Menunggu', 'Disetujui', 'Diverifikasi', 'Selesai'];

/// Maps every [SubmissionFlowStatus] onto one of the 4 [_stageLabels] —
/// `diterimaPengolah`/`sedangDiverifikasi` both count as "Diverifikasi"
/// (Pengolah is still comparing declared vs actual waste), and every
/// terminal outcome (success or not) counts as "Selesai".
int _stageIndexFor(SubmissionFlowStatus status) {
  switch (status) {
    case SubmissionFlowStatus.menungguKonfirmasi:
      return 0;
    case SubmissionFlowStatus.dikonfirmasi:
      return 1;
    case SubmissionFlowStatus.diterimaPengolah:
    case SubmissionFlowStatus.sedangDiverifikasi:
      return 2;
    case SubmissionFlowStatus.disetujui:
    case SubmissionFlowStatus.selesaiPoinMinimal:
    case SubmissionFlowStatus.ditolakPengolah:
      return 3;
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.submission});

  final SubmissionModel submission;

  @override
  Widget build(BuildContext context) {
    final flow = submission.flowStatus;
    final accentColor =
        submission.kategori == WasteCategory.organik ? AppColors.organik : AppColors.anorganik;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SummaryCard(submission: submission, accentColor: accentColor),
        const SizedBox(height: 20),
        _StageTimeline(current: flow),
        const SizedBox(height: 20),
        if (flow == SubmissionFlowStatus.menungguKonfirmasi)
          const _WaitingCard()
        else if (flow == SubmissionFlowStatus.dikonfirmasi)
          _ConfirmedCard(submission: submission)
        else if (flow == SubmissionFlowStatus.diterimaPengolah ||
            flow == SubmissionFlowStatus.sedangDiverifikasi)
          const _VerifyingCard()
        else if (flow.isSuccessOutcome)
          _SuccessCard(submission: submission)
        else if (flow.isPartialOutcome)
          _PartialCard(submission: submission)
        else if (flow.isFailureOutcome)
          _FailureCard(submission: submission),
        const SizedBox(height: 24),
        if (flow.isTerminal)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/beranda'),
              child: const Text('Kembali ke Beranda'),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.submission, required this.accentColor});

  final SubmissionModel submission;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final beratLabel =
        NumberFormat.decimalPattern('id_ID').format(submission.beratKg);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              submission.kategori == WasteCategory.organik
                  ? Icons.eco_rounded
                  : Icons.recycling_rounded,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(submission.subtipe, style: AppTextStyles.bodyBold),
                const SizedBox(height: 2),
                Text('$beratLabel kg · ${submission.kategori.label}',
                    style: AppTextStyles.captionMuted),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              submission.flowStatus.label,
              style: AppTextStyles.captionMuted
                  .copyWith(color: accentColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageTimeline extends StatelessWidget {
  const _StageTimeline({required this.current});

  final SubmissionFlowStatus current;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _stageIndexFor(current);
    final lastStepColor = current.isFailureOutcome
        ? AppColors.error
        : current.isPartialOutcome
            ? AppColors.warning
            : AppColors.primary;
    return Row(
      children: [
        for (var i = 0; i < _stageLabels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i > currentIndex
                        ? AppColors.background
                        : (i == 3 ? lastStepColor : AppColors.primary),
                    border: Border.all(
                      color: i > currentIndex
                          ? AppColors.border
                          : (i == 3 ? lastStepColor : AppColors.primary),
                      width: 2,
                    ),
                  ),
                  child: i < currentIndex
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : (i == currentIndex && i == 3
                          ? Icon(
                              current.isFailureOutcome
                                  ? Icons.close_rounded
                                  : Icons.check_rounded,
                              color: Colors.white,
                              size: 14)
                          : null),
                ),
                const SizedBox(height: 6),
                Text(
                  _stageLabels[i],
                  textAlign: TextAlign.center,
                  style: AppTextStyles.captionMuted.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          if (i != _stageLabels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i < currentIndex ? AppColors.primary : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard();

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.hourglass_top_rounded,
      iconColor: AppColors.warning,
      title: 'Menunggu Konfirmasi Pengolah',
      body: 'Permintaan setoranmu sudah terkirim. Kamu akan diberi tahu '
          'begitu Pengolah menerima atau menolaknya.',
    );
  }
}

class _ConfirmedCard extends StatelessWidget {
  const _ConfirmedCard({required this.submission});

  final SubmissionModel submission;

  String get _deliveryInstruction {
    switch (submission.deliveryMode) {
      case DeliveryMode.cod:
        return 'Hubungi Pengolah untuk menyepakati waktu & lokasi ketemu langsung (COD).';
      case DeliveryMode.antarLangsung:
        return 'Antar sampahmu langsung ke lokasi Pengolah sesuai jadwal yang kamu isi.';
      case DeliveryMode.requestPengolah:
        return 'Pengolah akan datang menjemput sesuai jadwal yang kamu isi.';
      case null:
        return 'Koordinasikan pengiriman dengan Pengolah lewat kontak di bawah.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoCard(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.primary,
          title: 'Permintaan Disetujui',
          body: _deliveryInstruction,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
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
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(submission.pengolahNama ?? '-',
                        style: AppTextStyles.bodyBold),
                    const SizedBox(height: 2),
                    Text(
                      submission.pengolahTelepon ?? 'Nomor tidak tersedia',
                      style: AppTextStyles.captionMuted,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.call_outlined, color: AppColors.textMuted),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerifyingCard extends StatelessWidget {
  const _VerifyingCard();

  @override
  Widget build(BuildContext context) {
    return const _InfoCard(
      icon: Icons.fact_check_outlined,
      iconColor: AppColors.anorganik,
      title: 'Sedang Diverifikasi Pengolah',
      body: 'Sampahmu sudah diterima secara fisik dan sedang dicocokkan '
          'dengan data yang kamu input.',
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.submission});

  final SubmissionModel submission;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.primary, size: 40),
          const SizedBox(height: 8),
          Text('Setor Berhasil!', style: AppTextStyles.h2),
          const SizedBox(height: 4),
          Text(
            '+${submission.finalPoin ?? 0}',
            style: AppTextStyles.h1
                .copyWith(color: AppColors.primary, fontSize: 36),
          ),
          Text('POIN SIRKULAR DITAMBAHKAN',
              style: AppTextStyles.caption.copyWith(letterSpacing: 0.4)),
          const SizedBox(height: 16),
          if (submission.qrPayload != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: submission.qrPayload!,
                size: 160,
                backgroundColor: Colors.white,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Bukti setor berhasil — tunjukkan kalau diminta.',
            style: AppTextStyles.captionMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.submission});

  final SubmissionModel submission;

  @override
  Widget build(BuildContext context) {
    return const _InfoCard(
      icon: Icons.cancel_rounded,
      iconColor: AppColors.error,
      title: 'Ditolak Pengolah',
      body: 'Pengolah tidak bisa menerima permintaan setoran ini.',
    );
  }
}

/// Shown when Pengolah found a mismatch during verification — reads as
/// "not a successful setor", but Sumber still keeps a few points since the
/// waste already physically left their hands (no QR, unlike [_SuccessCard]).
class _PartialCard extends StatelessWidget {
  const _PartialCard({required this.submission});

  final SubmissionModel submission;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 40),
          const SizedBox(height: 8),
          Text('Setor Tidak Berhasil', style: AppTextStyles.h2),
          const SizedBox(height: 6),
          if (submission.catatanVerifikasi != null)
            Text(
              submission.catatanVerifikasi!,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 14),
          Text(
            '+${submission.finalPoin ?? 0}',
            style: AppTextStyles.h1
                .copyWith(color: AppColors.warning, fontSize: 32),
          ),
          Text('POIN MINIMAL — SAMPAH SUDAH DIBERIKAN',
              style: AppTextStyles.caption.copyWith(letterSpacing: 0.3),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyBold),
                const SizedBox(height: 4),
                Text(body, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
