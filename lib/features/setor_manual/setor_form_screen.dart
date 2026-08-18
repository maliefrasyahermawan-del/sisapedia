import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/partner_actor_model.dart';
import '../../data/models/submission_model.dart';

const _organikSubtipe = [
  'Sisa Sayur & Buah',
  'Sisa Makanan',
  'Ampas Kopi',
  'Sampah Organik Dapur',
];

const _anorganikSubtipe = [
  'Botol Plastik PET',
  'Kardus & Kertas',
  'Logam & Kaleng',
  'Kaca',
  'Plastik Lainnya',
];

class SetorFormScreen extends ConsumerStatefulWidget {
  const SetorFormScreen({super.key, required this.kategori});

  final WasteCategory kategori;

  @override
  ConsumerState<SetorFormScreen> createState() => _SetorFormScreenState();
}

class _SetorFormScreenState extends ConsumerState<SetorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _beratController = TextEditingController();
  String? _subtipe;
  PartnerActorModel? _partner;
  bool _submitting = false;

  bool get _isOrganik => widget.kategori == WasteCategory.organik;

  @override
  void dispose() {
    _beratController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _subtipe == null) {
      if (_subtipe == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih jenis sampah dulu ya.')),
        );
      }
      return;
    }
    final uid = ref.read(currentUidProvider).valueOrNull;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(submissionRepositoryProvider).create(SubmissionModel(
            id: '',
            uid: uid,
            kategori: widget.kategori,
            subtipe: _subtipe!,
            beratKg: double.parse(_beratController.text.replaceAll(',', '.')),
            partnerId: _partner?.id,
            partnerName: _partner?.nama,
          ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setoran berhasil diajukan.')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtipeOptions = _isOrganik ? _organikSubtipe : _anorganikSubtipe;
    final accentColor = _isOrganik ? AppColors.organik : AppColors.anorganik;
    final partnersAsync = ref.watch(partnersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isOrganik ? 'Setor Organik' : 'Setor Anorganik'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jenis Sampah', style: AppTextStyles.bodyBold),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in subtipeOptions)
                    ChoiceChip(
                      label: Text(option),
                      selected: _subtipe == option,
                      selectedColor: accentColor.withValues(alpha: 0.15),
                      labelStyle: AppTextStyles.bodySmall.copyWith(
                        color: _subtipe == option
                            ? accentColor
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color:
                            _subtipe == option ? accentColor : AppColors.border,
                      ),
                      onSelected: (_) => setState(() => _subtipe = option),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Berat (kg)', style: AppTextStyles.bodyBold),
              const SizedBox(height: 8),
              TextFormField(
                controller: _beratController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'Contoh: 2.5'),
                validator: (v) {
                  final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) {
                    return 'Masukkan berat yang valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text('Setor ke (opsional)', style: AppTextStyles.bodyBold),
              const SizedBox(height: 8),
              partnersAsync.when(
                data: (partners) {
                  if (partners.isEmpty) {
                    return Text('Belum ada mitra terdaftar di sekitarmu.',
                        style: AppTextStyles.captionMuted);
                  }
                  return DropdownButtonFormField<PartnerActorModel>(
                    initialValue: _partner,
                    isExpanded: true,
                    hint: const Text('Pilih mitra pengolah'),
                    items: [
                      for (final p in partners)
                        DropdownMenuItem(value: p, child: Text(p.nama)),
                    ],
                    onChanged: (v) => setState(() => _partner = v),
                  );
                },
                loading: () =>
                    const LinearProgressIndicator(minHeight: 2),
                error: (_, _) => Text('Gagal memuat daftar mitra.',
                    style: AppTextStyles.captionMuted),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Ajukan Setoran'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
