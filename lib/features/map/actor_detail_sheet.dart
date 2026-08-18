import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/partner_actor_model.dart';

Future<void> showActorDetailSheet(
  BuildContext context,
  PartnerActorModel partner, {
  required Future<void> Function() onAjukanPencocokan,
}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final percentAvailable = partner.kapasitasTotal > 0
          ? (partner.kapasitasTersedia / partner.kapasitasTotal).clamp(0, 1)
          : 0.0;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(partner.nama, style: AppTextStyles.h2),
              const SizedBox(height: 2),
              Text(partner.tipe.label, style: AppTextStyles.captionMuted),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: percentAvailable.toDouble(),
                        minHeight: 8,
                        backgroundColor: AppColors.border,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${partner.kapasitasTersedia.toStringAsFixed(0)}/'
                    '${partner.kapasitasTotal.toStringAsFixed(0)} kg',
                    style: AppTextStyles.captionMuted,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Kapasitas tersedia', style: AppTextStyles.captionMuted),
              if (partner.kategoriDiterima.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Menerima', style: AppTextStyles.bodyBold),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final kategori in partner.kategoriDiterima)
                      Chip(
                        label: Text(kategori),
                        labelStyle: AppTextStyles.bodySmall,
                        backgroundColor: AppColors.primaryLight,
                        side: BorderSide.none,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await onAjukanPencocokan();
                  },
                  child: const Text('Ajukan Pencocokan'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
