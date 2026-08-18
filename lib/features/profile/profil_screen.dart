import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../auth/auth_controller.dart';

class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  static const _infoLinks = [
    (slug: 'panduan', label: 'Panduan'),
    (slug: 'faq', label: 'Pertanyaan Umum'),
    (slug: 'syarat', label: 'Syarat dan Ketentuan'),
    (slug: 'privasi', label: 'Kebijakan Privasi'),
    (slug: 'tentang', label: 'Tentang SisaPedia'),
  ];

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar akun?'),
        content: const Text('Kamu perlu masuk lagi untuk memakai SisaPedia.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    (profile?.name.isNotEmpty == true
                            ? profile!.name[0]
                            : '?')
                        .toUpperCase(),
                    style: AppTextStyles.h1.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile?.name ?? '-', style: AppTextStyles.h3),
                      const SizedBox(height: 2),
                      Text(profile?.levelTitle ?? 'Pejuang Kota Sirkular',
                          style: AppTextStyles.captionMuted),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat.decimalPattern('id_ID').format(profile?.poinSirkular ?? 0)} Poin Sirkular',
                        style: AppTextStyles.bodyBold
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('TENTANG', style: AppTextStyles.caption),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final link in _infoLinks) ...[
                  ListTile(
                    title: Text(link.label, style: AppTextStyles.body),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                    onTap: () => context.push('/profil/info/${link.slug}'),
                  ),
                  if (link != _infoLinks.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('LAINNYA', style: AppTextStyles.caption),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              title: const Text('Versi Aplikasi'),
              trailing: Text('1.0.0', style: AppTextStyles.captionMuted),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _confirmLogout(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              child: const Text('Keluar'),
            ),
          ),
        ],
      ),
    );
  }
}
