import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/submission_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';

const kWaktuPengantaranOptions = ['08:00–12:00', '12:00–15:00', '15:00–17:00'];

class _ModeCopy {
  const _ModeCopy(this.sectionTitle, this.sectionSubtitle, this.hint, this.label);
  final String sectionTitle;
  final String sectionSubtitle;
  final String hint;
  final String label;
}

const _modeCopy = {
  DeliveryMode.requestPengolah: _ModeCopy(
    'Informasi Tempat Tinggal',
    'Lokasi penjemputan sampah',
    'Contoh: Jl. Merdeka No. 10, RT 02/RW 05, Kel. Sukamaju, Kec. Tembalang',
    'Alamat Penjemputan',
  ),
  DeliveryMode.antarLangsung: _ModeCopy(
    'Lokasi Antar',
    'Alamat mitra pengolah/pengepul tujuan',
    'Contoh: Bank Sampah Melati Bersih, Jl. Sirojudin No. 8, Tembalang',
    'Alamat Tujuan',
  ),
  DeliveryMode.cod: _ModeCopy(
    'Lokasi Ketemuan (COD)',
    'Titik temu yang disepakati bareng mitra',
    'Contoh: Indomaret Jl. Setiabudi, atau titik temu lainnya',
    'Lokasi Ketemuan',
  ),
};

/// Shared "Mode Pengiriman" + address + schedule + notes block used by both
/// the manual and foto Setor flows, so a setoran always carries pickup
/// logistics regardless of how it was captured.
class PengantaranSection extends StatelessWidget {
  const PengantaranSection({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.alamatController,
    required this.catatanController,
    required this.tanggal,
    required this.onTanggalChanged,
    required this.waktu,
    required this.onWaktuChanged,
  });

  final DeliveryMode? mode;
  final ValueChanged<DeliveryMode> onModeChanged;
  final TextEditingController alamatController;
  final TextEditingController catatanController;
  final DateTime? tanggal;
  final ValueChanged<DateTime> onTanggalChanged;
  final String? waktu;
  final ValueChanged<String?> onWaktuChanged;

  Future<void> _pickTanggal(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: tanggal ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) onTanggalChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final copy = _modeCopy[mode ?? DeliveryMode.requestPengolah]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Mode Pengiriman',
          subtitle: 'Gimana sampahnya bakal sampai ke mitra pengolah',
        ),
        const SizedBox(height: 12),
        FormField<DeliveryMode>(
          initialValue: mode,
          validator: (_) => mode == null ? 'Pilih mode pengiriman' : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DeliveryModeCard(
                icon: Icons.local_shipping_rounded,
                title: DeliveryMode.requestPengolah.label,
                subtitle: 'Mitra jemput langsung ke tempatmu',
                selected: mode == DeliveryMode.requestPengolah,
                onTap: () {
                  onModeChanged(DeliveryMode.requestPengolah);
                  field.didChange(DeliveryMode.requestPengolah);
                },
              ),
              const SizedBox(height: 10),
              _DeliveryModeCard(
                icon: Icons.directions_walk_rounded,
                title: DeliveryMode.antarLangsung.label,
                subtitle: 'Kamu antar sendiri ke pengepul/mitra',
                selected: mode == DeliveryMode.antarLangsung,
                onTap: () {
                  onModeChanged(DeliveryMode.antarLangsung);
                  field.didChange(DeliveryMode.antarLangsung);
                },
              ),
              const SizedBox(height: 10),
              _DeliveryModeCard(
                icon: Icons.handshake_rounded,
                title: DeliveryMode.cod.label,
                subtitle: 'Janjian ketemu langsung sama mitra',
                selected: mode == DeliveryMode.cod,
                onTap: () {
                  onModeChanged(DeliveryMode.cod);
                  field.didChange(DeliveryMode.cod);
                },
              ),
              if (field.errorText != null) ...[
                const SizedBox(height: 6),
                Text(field.errorText!,
                    style: AppTextStyles.captionMuted
                        .copyWith(color: AppColors.error)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(
          title: copy.sectionTitle,
          subtitle: copy.sectionSubtitle,
        ),
        const SizedBox(height: 12),
        AppCard(
          child: TextFormField(
            controller: alamatController,
            maxLines: 3,
            decoration: InputDecoration(hintText: copy.hint),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? '${copy.label} wajib diisi'
                : null,
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Informasi Pengantaran'),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tanggal', style: AppTextStyles.bodyBold),
              const SizedBox(height: 8),
              FormField<DateTime>(
                initialValue: tanggal,
                validator: (_) => tanggal == null ? 'Pilih tanggal' : null,
                builder: (field) => InkWell(
                  onTap: () async {
                    await _pickTanggal(context);
                    field.didChange(tanggal);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      suffixIcon: const Icon(Icons.calendar_today_rounded,
                          size: 18, color: AppColors.textMuted),
                      errorText: field.errorText,
                    ),
                    child: Text(
                      tanggal == null
                          ? 'Pilih tanggal'
                          : DateFormat('d MMMM yyyy', 'id_ID').format(tanggal!),
                      style: tanggal == null
                          ? AppTextStyles.body
                              .copyWith(color: AppColors.textMuted)
                          : AppTextStyles.body,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Waktu', style: AppTextStyles.bodyBold),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: waktu,
                hint: const Text('Pilih slot waktu'),
                items: [
                  for (final w in kWaktuPengantaranOptions)
                    DropdownMenuItem(value: w, child: Text(w)),
                ],
                onChanged: onWaktuChanged,
                validator: (v) => v == null ? 'Pilih waktu' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text('Informasi Tambahan', style: AppTextStyles.h3),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text('Opsional', style: AppTextStyles.captionMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: TextFormField(
            controller: catatanController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Pesan atau catatan tambahan buat mitra pengolah',
            ),
          ),
        ),
      ],
    );
  }
}

class _DeliveryModeCard extends StatelessWidget {
  const _DeliveryModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 20,
                  color: selected ? Colors.white : AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyBold),
                  Text(subtitle, style: AppTextStyles.captionMuted),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
