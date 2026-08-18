import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/services/waste_voice_parser.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/submission_model.dart';
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
  bool _submitting = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _timer?.cancel();
    ref.read(speechServiceProvider).cancel();
    super.dispose();
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

  void _processTranscript() {
    final parser = ref.read(wasteVoiceParserProvider);
    final result = parser.parse(_transcript);
    setState(() {
      if (result.isClear) {
        _parsedItems = result.items;
        _state = _VoiceState.confirming;
      } else {
        _state = _VoiceState.unclear;
      }
    });
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
    setState(() => _submitting = true);
    final repo = ref.read(submissionRepositoryProvider);
    for (final item in _parsedItems) {
      await repo.create(SubmissionModel(
        id: '',
        uid: widget.uid,
        kategori: item.kategori,
        subtipe: item.subtipe,
        beratKg: item.beratKg,
        source: SubmissionSource.voice,
      ));
    }
    if (mounted) Navigator.of(context).pop();
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
          child: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 36),
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
        const Icon(Icons.sentiment_dissatisfied_rounded,
            color: AppColors.warning, size: 48),
        const SizedBox(height: 12),
        Text('Maaf, Sari kurang jelas dengar ucapanmu',
            style: AppTextStyles.h3, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          'Coba ucapkan lagi dengan jelas, contoh: "5 kilo botol plastik"',
          style: AppTextStyles.captionMuted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: _retry, child: const Text('Coba Lagi')),
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
                  Expanded(child: Text(item.subtipe, style: AppTextStyles.bodyBold)),
                  Text('${item.beratKg} kg', style: AppTextStyles.bodyBold),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
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
                : const Text('Kirim Setoran'),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: _retry, child: const Text('Ucapkan Ulang')),
      ],
    );
  }
}
