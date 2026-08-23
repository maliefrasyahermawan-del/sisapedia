import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/services/waste_voice_parser.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/submission_model.dart';
import '../setor_manual/setor_form_screen.dart';
import '../../shared/widgets/app_card.dart';

/// Opens the "Setor Cerdas" voice-logging bottom sheet.
Future<void> showVoiceModal(BuildContext context, WidgetRef ref, String uid) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => VoiceModal(uid: uid),
  );
}

enum _VoiceState { listening, unclear, confirming }

class VoiceModal extends ConsumerStatefulWidget {
  const VoiceModal({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<VoiceModal> createState() => _VoiceModalState();
}

class _VoiceModalState extends ConsumerState<VoiceModal> {
  _VoiceState _state = _VoiceState.listening;
  String _transcript = '';
  int _elapsedSeconds = 0;
  Timer? _timer;
  List<ParsedWasteItem> _parsedItems = [];
  bool _permissionDenied = false;
  WasteCategory _editedCategory = WasteCategory.organik;
  final _editedSubtypeController = TextEditingController();
  final _editedWeightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _timer?.cancel();
    ref.read(speechServiceProvider).cancel();
    _editedSubtypeController.dispose();
    _editedWeightController.dispose();
    super.dispose();
  }

  void _setParsedItems(List<ParsedWasteItem> items) {
    _parsedItems = items;
    if (items.isNotEmpty) {
      final item = items.first;
      _editedCategory = item.kategori;
      _editedSubtypeController.text = item.subtipe;
      _editedWeightController.text = item.beratKg.toString();
    }
  }

  Future<void> _startListening() async {
    final speech = ref.read(speechServiceProvider);
    final granted = await speech.ensurePermission();
    if (!granted) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    final ready = await speech.init();
    if (!ready) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    await speech.startListening(
      onResult: (transcript, isFinal) {
        if (!mounted) return;
        setState(() => _transcript = transcript);
        if (isFinal) {
          _timer?.cancel();
          _processTranscript();
        }
      },
    );
  }

  Future<void> _onSelesaiBicara() async {
    await ref.read(speechServiceProvider).stopListening();
    _timer?.cancel();
    _processTranscript();
  }

  void _simulateUnclear() {
    ref.read(speechServiceProvider).cancel();
    _timer?.cancel();
    setState(() => _state = _VoiceState.unclear);
  }

  Future<void> _processTranscript() async {
    try {
      final extraction = await ref
          .read(sariGatewayProvider)
          .extractWaste(_transcript);
      if (extraction.needsClarification) {
        if (mounted) setState(() => _state = _VoiceState.unclear);
        return;
      }
      if (mounted) {
        setState(() {
          _setParsedItems([
            ParsedWasteItem(
              subtipe: extraction.subtype,
              kategori: extraction.category == 'anorganik'
                  ? WasteCategory.anorganik
                  : WasteCategory.organik,
              beratKg: extraction.weightKg,
            ),
          ]);
          _state = _VoiceState.confirming;
        });
      }
    } catch (_) {
      // Network/router failures never discard the user's transcript. Use the
      // deterministic local parser and keep the same editable confirmation.
      final fallback = ref.read(wasteVoiceParserProvider).parse(_transcript);
      if (mounted) {
        setState(() {
          _setParsedItems(fallback.items);
          _state = fallback.isClear
              ? _VoiceState.confirming
              : _VoiceState.unclear;
        });
      }
    }
  }

  void _retry() {
    setState(() {
      _transcript = '';
      _elapsedSeconds = 0;
      _parsedItems = [];
      _permissionDenied = false;
      _state = _VoiceState.listening;
    });
    _startListening();
  }

  Future<void> _submit() async {
    if (_parsedItems.isEmpty || !mounted) return;
    final weight = double.tryParse(
      _editedWeightController.text.replaceAll(',', '.'),
    );
    final subtype = _editedSubtypeController.text.trim();
    if (weight == null || weight <= 0 || subtype.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Periksa kategori, jenis, dan berat.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lengkapi lokasi pickup'),
        content: const Text(
          'Hasil suara sudah siap diedit. Lengkapi alamat, pin, dan jendela pickup di formulir Setor sebelum dikirim.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final category = _editedCategory.name;
    if (context.mounted) {
      context.pop();
      context.push(
        '/setor/$category',
        extra: WastePrefill(
          kategori: _editedCategory,
          subtipe: subtype,
          beratKg: weight,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (_state) {
            _VoiceState.listening =>
              _permissionDenied ? _buildPermissionDenied() : _buildListening(),
            _VoiceState.unclear => _buildUnclear(),
            _VoiceState.confirming => _buildConfirming(),
          },
        ),
      ),
    );
  }

  Widget _buildListening() {
    final mm = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return Column(
      key: const ValueKey('listening'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mic_rounded,
            color: AppColors.primary,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        Text('Sari', style: AppTextStyles.caption),
        Text('Sari sedang mendengarkan...', style: AppTextStyles.h3),
        const SizedBox(height: 8),
        Text('$mm:$ss', style: AppTextStyles.statValue),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _transcript.isEmpty
                ? 'Coba: "Saya setor 5 kilo botol plastik dan 2 kilo sisa sayur"'
                : _transcript,
            style: _transcript.isEmpty
                ? AppTextStyles.captionMuted
                : AppTextStyles.body,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _onSelesaiBicara,
            child: const Text('Selesai Bicara'),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _simulateUnclear,
          child: const Text('Simulasikan hasil tidak jelas'),
        ),
      ],
    );
  }

  Widget _buildPermissionDenied() {
    return Column(
      key: const ValueKey('permission'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mic_off_rounded, color: AppColors.warning, size: 48),
        const SizedBox(height: 12),
        Text('Izin mikrofon dibutuhkan', style: AppTextStyles.h3),
        const SizedBox(height: 4),
        Text(
          'Aktifkan izin mikrofon di pengaturan HP untuk pakai Setor Cerdas.',
          style: AppTextStyles.captionMuted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ),
      ],
    );
  }

  Widget _buildUnclear() {
    return Column(
      key: const ValueKey('unclear'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.sentiment_dissatisfied_rounded,
          color: AppColors.warning,
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          'Maaf, Sari kurang jelas dengar ucapanmu',
          style: AppTextStyles.h3,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Coba ucapkan lagi dengan jelas, contoh: "5 kilo botol plastik"',
          style: AppTextStyles.captionMuted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _retry,
            child: const Text('Coba Lagi'),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal, isi manual'),
        ),
      ],
    );
  }

  Widget _buildConfirming() {
    return Column(
      key: const ValueKey('confirming'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sari mencatat setoranmu', style: AppTextStyles.h3),
        const SizedBox(height: 4),
        Text('Periksa dulu sebelum dikirim', style: AppTextStyles.captionMuted),
        const SizedBox(height: 16),
        if (_parsedItems.isNotEmpty) ...[
          DropdownButtonFormField<WasteCategory>(
            initialValue: _editedCategory,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: const [
              DropdownMenuItem(
                value: WasteCategory.organik,
                child: Text('Organik'),
              ),
              DropdownMenuItem(
                value: WasteCategory.anorganik,
                child: Text('Anorganik'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _editedCategory = value);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _editedSubtypeController,
            decoration: const InputDecoration(labelText: 'Jenis/subtipe'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _editedWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Berat (kg)'),
          ),
          const SizedBox(height: 12),
        ],
        for (final item in _parsedItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(
                children: [
                  Icon(
                    item.kategori == WasteCategory.organik
                        ? Icons.compost_rounded
                        : Icons.recycling_rounded,
                    color: item.kategori == WasteCategory.organik
                        ? AppColors.organik
                        : AppColors.anorganik,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.subtipe, style: AppTextStyles.bodyBold),
                  ),
                  Text('${item.beratKg} kg', style: AppTextStyles.bodyBold),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submit,
            child: const Text('Lengkapi lokasi dan lanjutkan'),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: _retry, child: const Text('Ucapkan Ulang')),
      ],
    );
  }
}
