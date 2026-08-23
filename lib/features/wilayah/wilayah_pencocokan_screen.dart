import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/partner_actor_model.dart';

/// List-based alternative to the interactive map for picking a matching
/// partner: filter by kecamatan first (cheap), then render a plain list
/// instead of tiles/markers, so it renders fast even on low-end devices.
class WilayahPencocokanScreen extends ConsumerStatefulWidget {
  const WilayahPencocokanScreen({super.key});

  @override
  ConsumerState<WilayahPencocokanScreen> createState() =>
      _WilayahPencocokanScreenState();
}

class _WilayahPencocokanScreenState
    extends ConsumerState<WilayahPencocokanScreen> {
  String? _selectedKecamatan;
  String? _selectedPartnerId;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(partnersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Wilayah Pencocokan')),
      body: partnersAsync.when(
        data: (partners) {
          final kecamatanList =
              partners
                  .map((p) => p.kecamatan)
                  .where((k) => k.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          _selectedKecamatan ??= kecamatanList.isNotEmpty
              ? kecamatanList.first
              : null;

          final filtered = partners
              .where((p) => p.kecamatan == _selectedKecamatan)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Pilih wilayah di Semarang untuk melihat daftar bank sampah, '
                  'pengomposan, peternak maggot, dan pengepul terdekat.',
                  style: AppTextStyles.captionMuted,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: kecamatanList.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final kec = kecamatanList[i];
                    final selected = kec == _selectedKecamatan;
                    return ChoiceChip(
                      label: Text(kec),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _selectedKecamatan = kec;
                        _selectedPartnerId = null;
                      }),
                      selectedColor: AppColors.primaryLight,
                      labelStyle: AppTextStyles.bodySmall.copyWith(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Lokasi Tersedia di ${_selectedKecamatan ?? '-'}',
                  style: AppTextStyles.bodyBold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada mitra di wilayah ini.',
                          style: AppTextStyles.captionMuted,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final partner = filtered[i];
                          final selected = partner.id == _selectedPartnerId;
                          return _PartnerTile(
                            partner: partner,
                            selected: selected,
                            onTap: () =>
                                setState(() => _selectedPartnerId = partner.id),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedPartnerId == null || _submitting
                          ? null
                          : () => _ajukanPencocokan(filtered),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Ajukan Pencocokan'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'Gagal memuat daftar mitra.',
            style: AppTextStyles.captionMuted,
          ),
        ),
      ),
    );
  }

  Future<void> _ajukanPencocokan(List<PartnerActorModel> filtered) async {
    final uid = ref.read(currentUidProvider).valueOrNull;
    PartnerActorModel? partner;
    for (final p in filtered) {
      if (p.id == _selectedPartnerId) {
        partner = p;
        break;
      }
    }
    if (uid == null || partner == null) return;
    setState(() => _submitting = true);
    await ref
        .read(partnerRepositoryProvider)
        .requestMatch(partnerId: partner.id, uid: uid);
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pencocokan dengan ${partner.nama} diajukan.')),
    );
  }
}

class _PartnerTile extends StatelessWidget {
  const _PartnerTile({
    required this.partner,
    required this.selected,
    required this.onTap,
  });

  final PartnerActorModel partner;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(partner.nama, style: AppTextStyles.bodyBold),
                  const SizedBox(height: 2),
                  Text(
                    partner.alamat.isNotEmpty
                        ? partner.alamat
                        : partner.tipe.label,
                    style: AppTextStyles.captionMuted,
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
