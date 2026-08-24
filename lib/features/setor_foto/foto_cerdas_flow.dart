import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/image_source_sheet.dart';
import 'foto_konfirmasi_screen.dart';

/// Entry point for "Mode Foto Cerdas" from the Setor Cerdas mode sheet:
/// captures + analyzes a photo, then navigates to the confirmation screen.
Future<void> startFotoCerdasFlow(
  BuildContext context,
  WidgetRef ref,
  String uid,
) async {
  final args = await captureAndAnalyzePhoto(context, ref, uid);
  if (args == null || !context.mounted) return;
  context.push('/setor/foto-konfirmasi', extra: args);
}

/// Picks an image source, takes/picks the photo, and runs it through Gemini
/// Vision. Returns `null` (after showing a snackbar) if the user cancels or
/// analysis fails — callers decide how to navigate on success, which lets
/// "Ambil Ulang Foto" on the confirmation screen use `pushReplacement`
/// instead of juggling pop-then-push ordering.
Future<FotoDeteksiArgs?> captureAndAnalyzePhoto(
  BuildContext context,
  WidgetRef ref,
  String uid,
) async {
  final source =
      await showImageSourceSheet(context, title: 'Ambil Foto Sampah');
  if (source == null || !context.mounted) return null;

  final picker = ImagePicker();
  final XFile? photo;
  try {
    photo = await picker.pickImage(source: source, imageQuality: 85);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto: $e')),
      );
    }
    return null;
  }
  if (photo == null || !context.mounted) return null;

  final bytes = await photo.readAsBytes();
  if (!context.mounted) return null;

  _showAnalyzingDialog(context);
  try {
    final result = await ref.read(geminiVisionServiceProvider).analyze(bytes);
    if (!context.mounted) return null;
    Navigator.of(context, rootNavigator: true).pop(); // close loading dialog
    return FotoDeteksiArgs(
      uid: uid,
      imagePath: photo.path,
      imageBytes: bytes,
      result: result,
    );
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deteksi foto gagal: $e')),
      );
    }
    return null;
  }
}

void _showAnalyzingDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 16),
          Text('Menganalisis foto...', style: AppTextStyles.body),
        ],
      ),
    ),
  );
}
