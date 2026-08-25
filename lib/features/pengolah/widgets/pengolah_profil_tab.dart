import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/pengolah_mock.dart';

class PengolahProfilTab extends StatelessWidget {
  const PengolahProfilTab({super.key, required this.onKeluar});

  final VoidCallback onKeluar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text('Profil', style: AppTextStyles.h1),
        const SizedBox(height: 2),
        Text(pengolahNamaAkun, style: AppTextStyles.captionMuted),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.organikSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_outlined,
                    color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pengolahNamaAkun, style: AppTextStyles.h3),
                    const SizedBox(height: 2),
                    Text('Pengolah · Tembalang', style: AppTextStyles.captionMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _MenuTile(label: 'Data Kapasitas', onTap: () => _soon(context)),
              const Divider(height: 1),
              _MenuTile(label: 'Riwayat Transaksi', onTap: () => _soon(context)),
              const Divider(height: 1),
              _MenuTile(label: 'Pengaturan Akun', onTap: () => _soon(context)),
              const Divider(height: 1),
              _MenuTile(
                label: 'Keluar',
                labelColor: AppColors.error,
                onTap: onKeluar,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Segera hadir.')));
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.label, required this.onTap, this.labelColor});

  final String label;
  final VoidCallback onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          label,
          style: AppTextStyles.bodyBold.copyWith(color: labelColor),
        ),
      ),
    );
  }
}
