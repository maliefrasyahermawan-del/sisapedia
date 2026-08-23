import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/session/guest_gate.dart';
import '../../core/session/session_mode.dart';
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

const _subtipeIcons = {
  'Sisa Sayur & Buah': Icons.eco_rounded,
  'Sisa Makanan': Icons.restaurant_rounded,
  'Ampas Kopi': Icons.coffee_rounded,
  'Sampah Organik Dapur': Icons.kitchen_rounded,
  'Botol Plastik PET': Icons.local_drink_rounded,
  'Kardus & Kertas': Icons.inventory_2_rounded,
  'Logam & Kaleng': Icons.hardware_rounded,
  'Kaca': Icons.wine_bar_rounded,
  'Plastik Lainnya': Icons.shopping_bag_rounded,
};

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
    if (ref.read(sessionModeProvider) == SessionMode.guest) {
      await showGuestRegisterGate(context);
      return;
    }

    final uid = ref.read(currentUidProvider).valueOrNull;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      final submission = SubmissionModel(
        id: '',
        uid: uid,
        kategori: widget.kategori,
        subtipe: _subtipe!,
        beratKg: double.parse(_beratController.text.replaceAll(',', '.')),
        partnerId: _partner?.id,
        partnerName: _partner?.nama,
      );
      await ref.read(submissionRepositoryProvider).create(submission);
      if (mounted) {
        context.pushReplacement('/setor/sukses', extra: submission);
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
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (final option in subtipeOptions) ...[
                        _JenisSampahTile(
                          icon: _subtipeIcons[option] ??
                              Icons.delete_outline_rounded,
                          label: option,
                          accentColor: accentColor,
                          selected: _subtipe == option,
                          onTap: () => setState(() => _subtipe = option),
                        ),
                        if (option != subtipeOptions.last)
                          const Divider(height: 1, indent: 14, endIndent: 14),
                      ],
                    ],
                  ),
                ),
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

class _JenisSampahTile extends StatelessWidget {
  const _JenisSampahTile({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: selected
            ? accentColor.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? accentColor.withValues(alpha: 0.15)
                    : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? accentColor : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTextStyles.bodyBold)),
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: selected
                  ? ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.check_rounded, size: 15),
                      label: const Text('Dipilih'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: AppTextStyles.bodySmall
                            .copyWith(fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        textStyle: AppTextStyles.bodySmall
                            .copyWith(fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Pilih'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
