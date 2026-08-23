import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Shown when a guest tries to do something that requires a real account
/// (e.g. submitting a setoran). Redirects to registration on confirm.
Future<void> showGuestRegisterGate(BuildContext context) {
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.lock_person_rounded,
        color: AppColors.primary,
        size: 32,
      ),
      title: Text('Anda Belum Terdaftar', style: AppTextStyles.h3),
      content: Text(
        'Daftar akun untuk bisa menyetor sampah dan mengumpulkan poin.',
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Nanti Dulu'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            dialogContext.go('/register');
          },
          child: const Text('Daftar Sekarang'),
        ),
      ],
    ),
  );
}
