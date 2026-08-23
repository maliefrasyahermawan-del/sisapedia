import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/geo/semarang_boundary.dart';
import '../../data/models/partner_actor_model.dart';
import 'actor_detail_sheet.dart';

const _semarangCenter = LatLng(-6.9932, 110.4203);

final _semarangBoundaryPoints = [
  for (final p in semarangBoundaryLatLng) LatLng(p[0], p[1]),
];

Color _colorFor(PartnerType type) {
  switch (type) {
    case PartnerType.bankSampah:
      return AppColors.primary;
    case PartnerType.maggotBsf:
      return const Color(0xFFB45309);
    case PartnerType.pengepul:
      return AppColors.anorganik;
    case PartnerType.pengompos:
      return const Color(0xFF7C3AED);
  }
}

IconData _iconFor(PartnerType type) {
  switch (type) {
    case PartnerType.bankSampah:
      return Icons.storefront_rounded;
    case PartnerType.maggotBsf:
      return Icons.bug_report_rounded;
    case PartnerType.pengepul:
      return Icons.local_shipping_rounded;
    case PartnerType.pengompos:
      return Icons.compost_rounded;
  }
}

class PetaScreen extends ConsumerStatefulWidget {
  const PetaScreen({super.key});

  @override
  ConsumerState<PetaScreen> createState() => _PetaScreenState();
}

class _PetaScreenState extends ConsumerState<PetaScreen> {
  PartnerType? _filter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(partnersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Peta Pencocokan')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari aktor sirkular...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'Semua',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final type in PartnerType.values) ...[
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: type.label,
                    selected: _filter == type,
                    onTap: () => setState(() => _filter = type),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: partnersAsync.when(
              data: (partners) {
                final filtered = partners.where((p) {
                  final matchesFilter = _filter == null || p.tipe == _filter;
                  final matchesQuery =
                      _query.isEmpty || p.nama.toLowerCase().contains(_query);
                  return matchesFilter && matchesQuery;
                }).toList();

                return FlutterMap(
                  options: const MapOptions(
                    initialCenter: _semarangCenter,
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sisapedia.app',
                    ),
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: _semarangBoundaryPoints,
                          color: Colors.transparent,
                          borderColor: const Color(0xFFDC2626),
                          borderStrokeWidth: 2.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (final partner in filtered)
                          Marker(
                            point: LatLng(partner.lat, partner.lng),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () => showActorDetailSheet(
                                context,
                                partner,
                                onAjukanPencocokan: () =>
                                    _ajukanPencocokan(partner),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _colorFor(partner.tipe),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _iconFor(partner.tipe),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Text(
                  'Gagal memuat peta mitra.',
                  style: AppTextStyles.captionMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ajukanPencocokan(PartnerActorModel partner) async {
    final uid = ref.read(currentUidProvider).valueOrNull;
    if (uid == null) return;
    await ref
        .read(partnerRepositoryProvider)
        .requestMatch(partnerId: partner.id, uid: uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pencocokan dengan ${partner.nama} diajukan.')),
      );
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryLight,
      labelStyle: AppTextStyles.bodySmall.copyWith(
        color: selected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    );
  }
}
