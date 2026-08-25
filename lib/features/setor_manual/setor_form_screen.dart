import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/preview/preview_mode.dart';
import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/services/photo_upload_service.dart';
import '../../core/session/guest_gate.dart';
import '../../core/session/session_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/partner_actor_model.dart';
import '../../data/models/submission_model.dart';
import '../../shared/widgets/image_source_sheet.dart';
import '../../shared/widgets/section_header.dart';
import 'widgets/foto_bukti_field.dart';
import 'widgets/pengantaran_section.dart';

/// Main jenis sampah -> at least 5 specific sub-jenis each, so users pick a
/// precise item instead of a vague catch-all category.
const _organikJenis = {
  'Sisa Sayur & Buah': [
    'Sisa Sayuran',
    'Kulit Buah',
    'Buah Busuk',
    'Batang & Daun Sayur',
    'Sisa Salad',
  ],
  'Sisa Makanan': [
    'Nasi Sisa',
    'Lauk Sisa',
    'Roti Basi',
    'Mie/Pasta Sisa',
    'Sisa Gorengan',
  ],
  'Ampas Kopi': [
    'Ampas Kopi Giling',
    'Ampas Kopi Saring',
    'Ampas Kopi Tubruk',
    'Ampas Kopi Instan',
    'Kantong Teh Bekas',
  ],
  'Sampah Organik Dapur': [
    'Kulit Telur',
    'Kulit Bawang',
    'Tulang Ikan/Ayam',
    'Ampas Kelapa',
    'Sisa Sayur Mentah',
  ],
};

const _anorganikJenis = {
  'Botol Plastik PET': [
    'Botol Air Mineral',
    'Botol Soda',
    'Botol Jus',
    'Botol Minyak Goreng',
    'Botol Sirup Plastik',
  ],
  'Kardus & Kertas': [
    'Kardus Bekas',
    'Kertas HVS',
    'Koran Bekas',
    'Kertas Karton',
    'Kertas Majalah',
  ],
  'Logam & Kaleng': [
    'Kaleng Minuman',
    'Kaleng Makanan',
    'Tutup Botol Logam',
    'Kawat & Kabel',
    'Panci/Wajan Rusak',
  ],
  'Kaca': [
    'Botol Kecap',
    'Botol ABC',
    'Botol Bir',
    'Botol Cuka Kaca',
    'Botol Saus Sambal',
  ],
  'Plastik Lainnya': [
    'Kantong Plastik',
    'Sedotan Plastik',
    'Kemasan Sachet',
    'Ember/Baskom Plastik',
    'Mainan Plastik Rusak',
  ],
};

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
  final _alamatController = TextEditingController();
  final _catatanController = TextEditingController();
  String? _mainJenis;
  String? _subtipe;
  PartnerActorModel? _partner;
  String? _fotoBuktiPath;
  DeliveryMode? _deliveryMode;
  DateTime? _tanggalPengantaran;
  String? _waktuPengantaran;
  bool _submitting = false;
  String? _fotoError;

  bool get _isOrganik => widget.kategori == WasteCategory.organik;

  @override
  void dispose() {
    _beratController.dispose();
    _alamatController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _pickJenis(String mainLabel, Color accentColor) async {
    final options = (_isOrganik ? _organikJenis : _anorganikJenis)[mainLabel]!;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_subtipeIcons[mainLabel] ?? Icons.delete_outline_rounded,
                      color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text('Sub Jenis $mainLabel', style: AppTextStyles.h2),
                ],
              ),
              const SizedBox(height: 4),
              Text('Pilih yang paling sesuai',
                  style: AppTextStyles.captionMuted),
              const SizedBox(height: 12),
              for (final option in options) ...[
                InkWell(
                  onTap: () => Navigator.of(sheetContext).pop(option),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 13),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(option, style: AppTextStyles.body),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.textMuted, size: 20),
                      ],
                    ),
                  ),
                ),
                if (option != options.last)
                  const Divider(height: 1),
              ],
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _mainJenis = mainLabel;
        _subtipe = picked;
      });
    }
  }

  Future<void> _pickFotoBukti() async {
    final source = await showImageSourceSheet(context,
        title: 'Foto Bukti Sampah');
    if (source == null || !mounted) return;
    final photo = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (photo == null) return;
    setState(() {
      _fotoBuktiPath = photo.path;
      _fotoError = null;
    });
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _fotoError =
        _fotoBuktiPath == null ? 'Foto bukti sampah wajib diisi' : null);
    if (_subtipe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jenis sampah dulu ya.')),
      );
    }
    if (!formOk || _subtipe == null || _fotoBuktiPath == null) return;

    if (ref.read(sessionModeProvider) == SessionMode.guest) {
      await showGuestRegisterGate(context);
      return;
    }

    final uid = ref.read(currentUidProvider).valueOrNull;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      final photo = XFile(_fotoBuktiPath!);
      final bytes = await photo.readAsBytes();
      final isDemo = kPreviewMode ||
          ref.read(sessionModeProvider) == SessionMode.demo;
      final fotoUrl = await uploadSubmissionPhoto(
        uid: uid,
        bytes: bytes,
        useFake: isDemo,
      );

      final namaSumber = ref.read(userProfileProvider).valueOrNull?.name;
      final submission = SubmissionModel(
        id: '',
        uid: uid,
        namaSumber: namaSumber,
        kategori: widget.kategori,
        subtipe: _subtipe!,
        beratKg: double.parse(_beratController.text.replaceAll(',', '.')),
        partnerId: _partner?.id,
        partnerName: _partner?.nama,
        fotoUrl: fotoUrl,
        alamat: _alamatController.text.trim(),
        tanggalPengantaran: _tanggalPengantaran,
        waktuPengantaran: _waktuPengantaran,
        catatan: _catatanController.text.trim().isEmpty
            ? null
            : _catatanController.text.trim(),
        deliveryMode: _deliveryMode,
      );
      final id = await ref.read(submissionRepositoryProvider).create(submission);
      if (mounted) {
        context.pushReplacement('/setor/sukses',
            extra: submission.copyWith(id: id));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jenisMap = _isOrganik ? _organikJenis : _anorganikJenis;
    final mainOptions = jenisMap.keys.toList();
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
                      for (final option in mainOptions) ...[
                        _JenisSampahTile(
                          icon: _subtipeIcons[option] ??
                              Icons.delete_outline_rounded,
                          label: option,
                          selectedSubtipe:
                              _mainJenis == option ? _subtipe : null,
                          accentColor: accentColor,
                          selected: _mainJenis == option,
                          onTap: () => _pickJenis(option, accentColor),
                        ),
                        if (option != mainOptions.last)
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
              const SizedBox(height: 20),
              const SectionHeader(
                title: 'Foto Bukti Sampah',
                subtitle: 'Buat verifikasi mitra pengolah',
              ),
              const SizedBox(height: 12),
              FotoBuktiField(
                imagePath: _fotoBuktiPath,
                onPick: _pickFotoBukti,
                errorText: _fotoError,
              ),
              if (_fotoError != null) ...[
                const SizedBox(height: 6),
                Text(_fotoError!,
                    style: AppTextStyles.captionMuted
                        .copyWith(color: AppColors.error)),
              ],
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
    required this.selectedSubtipe,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? selectedSubtipe;
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodyBold),
                  if (selectedSubtipe != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      selectedSubtipe!,
                      style: AppTextStyles.captionMuted
                          .copyWith(color: accentColor),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: selected
                  ? ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.check_rounded, size: 15),
                      label: const Text('Ubah'),
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
