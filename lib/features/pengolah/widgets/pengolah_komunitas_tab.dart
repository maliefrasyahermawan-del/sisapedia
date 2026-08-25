import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/pengolah_mock.dart';
import 'pengolah_create_post_screen.dart';

class PengolahKomunitasTab extends StatelessWidget {
  const PengolahKomunitasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text('Komunitas', style: AppTextStyles.h1),
        const SizedBox(height: 2),
        Text('Event & edukasi antar mitra pengolah',
            style: AppTextStyles.captionMuted),
        const SizedBox(height: 16),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PengolahCreatePostScreen(),
            )),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('+ Buat Event / Postingan'),
          ),
        ),
        const SizedBox(height: 18),
        Text('Event Mendatang', style: AppTextStyles.h3),
        const SizedBox(height: 10),
        for (final ev in pengolahEvents) ...[
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 90,
                  color: const Color(0xFFEAF2FE),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined,
                      color: Color(0xFF7A93B8), size: 28),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ev.title, style: AppTextStyles.bodyBold),
                      const SizedBox(height: 2),
                      Text(ev.meta, style: AppTextStyles.captionMuted),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Text('Blog Edukasi', style: AppTextStyles.h3),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.organikSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('5 Cara Memilah Sampah Dapur',
                        style: AppTextStyles.bodyBold),
                    const SizedBox(height: 4),
                    Text('4 menit baca · 128 dibaca',
                        style: AppTextStyles.captionMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
