import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/session/guest_gate.dart';
import '../../core/session/session_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
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
  const SetorFormScreen({super.key, required this.kategori, this.prefill});

  final WasteCategory kategori;
  final WastePrefill? prefill;

  @override
  ConsumerState<SetorFormScreen> createState() => _SetorFormScreenState();
}

class WastePrefill {
  const WastePrefill({
    required this.kategori,
    required this.subtipe,
    required this.beratKg,
  });
  final WasteCategory kategori;
  final String subtipe;
  final double beratKg;
}

class _SetorFormScreenState extends ConsumerState<SetorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _beratController = TextEditingController();
  final _districtController = TextEditingController(text: 'Banyumanik');
  final _addressController = TextEditingController(text: 'Pasar Sampangan');
  final _latitudeController = TextEditingController(text: '-7.023');
  final _longitudeController = TextEditingController(text: '110.407');
  XFile? _sourcePhoto;
  String? _subtipe;
  DateTimeRange? _pickupWindow;
  bool _submitting = false;

  bool get _isOrganik => widget.kategori == WasteCategory.organik;

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    if (prefill != null) {
      _subtipe = prefill.subtipe;
      _beratController.text = prefill.beratKg.toString();
    }
  }

  @override
  void dispose() {
    _beratController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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
    if (_pickupWindow == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jendela pickup terlebih dahulu.')),
      );
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
        district: _districtController.text.trim(),
        address: _addressController.text.trim(),
        pickupStart: _pickupWindow!.start,
        pickupEnd: _pickupWindow!.end,
        latitude: double.tryParse(_latitudeController.text),
        longitude: double.tryParse(_longitudeController.text),
        sourcePhotoPath: _sourcePhoto?.path,
      );
      final createdId = await ref
          .read(submissionRepositoryProvider)
          .create(submission);
      if (mounted) {
        context.pushReplacement('/setor/$createdId/kandidat');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtipeOptions = _isOrganik ? _organikSubtipe : _anorganikSubtipe;
    final accentColor = _isOrganik ? AppColors.organik : AppColors.anorganik;
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
                        color: _subtipe == option
                            ? accentColor
                            : AppColors.border,
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(hintText: 'Contoh: 2.5'),
                validator: (v) {
                  final parsed = double.tryParse(
                    (v ?? '').replaceAll(',', '.'),
                  );
                  if (parsed == null || parsed <= 0) {
                    return 'Masukkan berat yang valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Pin latitude',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Pin longitude',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final photo = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (photo != null && mounted) {
                    setState(() => _sourcePhoto = photo);
                  }
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _sourcePhoto == null
                      ? 'Tambah foto sumber (opsional)'
                      : 'Foto dipilih: ${_sourcePhoto!.name}',
                ),
              ),
              const SizedBox(height: 20),
              Text('Lokasi dan jadwal pickup', style: AppTextStyles.bodyBold),
              const SizedBox(height: 8),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(labelText: 'Kecamatan'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Kecamatan wajib diisi'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Alamat pickup'),
                maxLines: 2,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Alamat pickup wajib diisi'
                    : null,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 30)),
                    initialDateRange:
                        _pickupWindow ??
                        DateTimeRange(
                          start: now,
                          end: now.add(const Duration(days: 1)),
                        ),
                  );
                  if (picked != null && mounted) {
                    setState(() => _pickupWindow = picked);
                  }
                },
                icon: const Icon(Icons.schedule),
                label: Text(
                  _pickupWindow == null
                      ? 'Pilih jendela pickup'
                      : '${_pickupWindow!.start.day}/${_pickupWindow!.start.month}–${_pickupWindow!.end.day}/${_pickupWindow!.end.month}',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Mitra dipilih setelah pengajuan',
                style: AppTextStyles.bodyBold,
              ),
              const SizedBox(height: 8),
              const Text(
                'SisaPedia akan menghitung top-3 kandidat berdasarkan material, kapasitas, jarak, dan minimum pickup.',
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
