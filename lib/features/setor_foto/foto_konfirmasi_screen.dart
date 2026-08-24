import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/preview/preview_mode.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/services/photo_upload_service.dart';
import '../../core/session/guest_gate.dart';
import '../../core/session/session_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/submission_model.dart';
import '../../data/models/waste_detection_result.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_header.dart';
import '../setor_manual/widgets/pengantaran_section.dart';
import 'foto_cerdas_flow.dart';

/// Bundles the args passed via go_router's `extra` to `/setor/foto-konfirmasi`.
class FotoDeteksiArgs {
  const FotoDeteksiArgs({
    required this.uid,
    required this.imagePath,
    required this.imageBytes,
    required this.result,
  });

  final String uid;
  final String imagePath;
  final List<int> imageBytes;
  final WasteDetectionResult result;
}

/// Shown after Gemini Vision returns a detection — nothing is saved until
/// the user reviews/corrects every field here and taps "Konfirmasi &
/// Simpan". Weight is always a manual entry: a photo alone isn't a
/// reliable scale, so the AI is never asked for it (see
/// [WasteDetectionResult]'s doc comment).
class FotoKonfirmasiScreen extends ConsumerStatefulWidget {
  const FotoKonfirmasiScreen({
    super.key,
    required this.uid,
    required this.imagePath,
    required this.imageBytes,
    required this.result,
  });

  final String uid;
  final String imagePath;
  final List<int> imageBytes;
  final WasteDetectionResult result;

  @override
  ConsumerState<FotoKonfirmasiScreen> createState() =>
      _FotoKonfirmasiScreenState();
}

class _FotoKonfirmasiScreenState extends ConsumerState<FotoKonfirmasiScreen> {
  final _formKey = GlobalKey<FormState>();
  late WasteCategory _kategori;
  late final TextEditingController _jenisController;
  late final TextEditingController _subJenisController;
  final _beratController = TextEditingController();
  final _alamatController = TextEditingController();
  final _catatanController = TextEditingController();
  DeliveryMode? _deliveryMode;
  DateTime? _tanggalPengantaran;
  String? _waktuPengantaran;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _kategori = widget.result.kategori;
    _jenisController = TextEditingController(text: widget.result.jenisMaterial);
    _subJenisController = TextEditingController(text: widget.result.subJenis);
  }

  @override
  void dispose() {
    _jenisController.dispose();
    _subJenisController.dispose();
    _beratController.dispose();
    _alamatController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (ref.read(sessionModeProvider) == SessionMode.guest) {
      await showGuestRegisterGate(context);
      return;
    }

    setState(() => _submitting = true);
    try {
      final isDemo = kPreviewMode ||
          ref.read(sessionModeProvider) == SessionMode.demo;
      final fotoUrl = await uploadSubmissionPhoto(
        uid: widget.uid,
        bytes: widget.imageBytes,
        useFake: isDemo,
      );

      final submission = SubmissionModel(
        id: '',
        uid: widget.uid,
        kategori: _kategori,
        subtipe: _subJenisController.text.trim(),
        beratKg: double.parse(_beratController.text.replaceAll(',', '.')),
        source: SubmissionSource.foto,
        fotoUrl: fotoUrl,
        alamat: _alamatController.text.trim(),
        tanggalPengantaran: _tanggalPengantaran,
        waktuPengantaran: _waktuPengantaran,
        catatan: _catatanController.text.trim().isEmpty
            ? null
            : _catatanController.text.trim(),
        deliveryMode: _deliveryMode,
      );
      await ref.read(submissionRepositoryProvider).create(submission);
      if (mounted) {
        context.pushReplacement('/setor/sukses', extra: submission);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _retakePhoto() async {
    final args = await captureAndAnalyzePhoto(context, ref, widget.uid);
    if (args == null || !mounted) return;
    context.pushReplacement('/setor/foto-konfirmasi', extra: args);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor =
        _kategori == WasteCategory.organik ? AppColors.organik : AppColors.anorganik;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Validasi Hasil AI')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(
                      File(widget.imagePath),
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _ConfidenceBadge(confidence: widget.result.confidence),
                  ),
                ],
              ),
              if (widget.result.confidence == WasteConfidence.rendah) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Deteksi kurang yakin, mohon periksa ulang sebelum menyimpan.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              const SectionHeader(
                title: 'Hasil Deteksi AI',
                subtitle: 'Koreksi kalau ada yang kurang tepat',
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kategori', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _KategoriPill(
                            label: 'Organik',
                            icon: Icons.eco_rounded,
                            color: AppColors.organik,
                            selected: _kategori == WasteCategory.organik,
                            onTap: () => setState(
                                () => _kategori = WasteCategory.organik),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _KategoriPill(
                            label: 'Anorganik',
                            icon: Icons.recycling_rounded,
                            color: AppColors.anorganik,
                            selected: _kategori == WasteCategory.anorganik,
                            onTap: () => setState(
                                () => _kategori = WasteCategory.anorganik),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('Jenis Material', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _jenisController,
                      decoration:
                          const InputDecoration(hintText: 'Contoh: Plastik'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Jenis material wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text('Sub-jenis', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _subJenisController,
                      decoration: const InputDecoration(
                          hintText: 'Contoh: Botol Plastik PET'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Sub-jenis wajib diisi'
                          : null,
                    ),
                    if (widget.result.estimasiJumlah != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.numbers_rounded,
                              size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'AI memperkirakan ${widget.result.estimasiJumlah} item di foto ini.',
                            style: AppTextStyles.captionMuted,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Berat Sampah'),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'AI tidak menebak berat dari foto — timbang dan isi berat aslinya di sini.',
                            style: AppTextStyles.captionMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _beratController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Contoh: 2.5',
                        suffixText: 'kg',
                      ),
                      validator: (v) {
                        final parsed =
                            double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (parsed == null || parsed <= 0) {
                          return 'Masukkan berat yang valid';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PengantaranSection(
                mode: _deliveryMode,
                onModeChanged: (v) => setState(() => _deliveryMode = v),
                alamatController: _alamatController,
                catatanController: _catatanController,
                tanggal: _tanggalPengantaran,
                onTanggalChanged: (v) =>
                    setState(() => _tanggalPengantaran = v),
                waktu: _waktuPengantaran,
                onWaktuChanged: (v) => setState(() => _waktuPengantaran = v),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Konfirmasi & Simpan'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : _retakePhoto,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Ambil Ulang Foto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KategoriPill extends StatelessWidget {
  const _KategoriPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodyBold.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final WasteConfidence confidence;

  Color get _color {
    switch (confidence) {
      case WasteConfidence.tinggi:
        return AppColors.success;
      case WasteConfidence.sedang:
        return AppColors.warning;
      case WasteConfidence.rendah:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'Keyakinan AI: ${confidence.label}',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
