import '../../data/models/partner_actor_model.dart';
import '../../data/models/submission_model.dart';

class MatchCandidate {
  const MatchCandidate({
    required this.partner,
    required this.compatibility,
    required this.distance,
    required this.capacity,
    required this.referenceValue,
    required this.minimumVolume,
    required this.totalScore,
  });
  final PartnerActorModel partner;
  final double compatibility,
      distance,
      capacity,
      referenceValue,
      minimumVolume,
      totalScore;
}

/// Deterministic, explainable matching used by Preview and mirrored by SQL.
List<MatchCandidate> rankCandidates({
  required WasteCategory category,
  required double weightKg,
  required Iterable<PartnerActorModel> partners,
  String? subtype,
  double? sourceLat,
  double? sourceLng,
  DateTime? pickupStart,
  DateTime? pickupEnd,
}) {
  final list =
      partners
          .where(
            (p) =>
                p.active &&
                p.approved &&
                p.pickupAvailable &&
                p.kapasitasTersedia >= weightKg &&
                weightKg >= p.minimumPickupKg &&
                _withinRadius(p, sourceLat, sourceLng) &&
                _pickupOverlaps(p, pickupStart, pickupEnd) &&
                _supports(p, category, subtype),
          )
          .map((p) {
            final compatibility = 1.0;
            final distance = _distanceScore(sourceLat, sourceLng, p.lat, p.lng);
            final capacity =
                (p.kapasitasTersedia /
                        (p.kapasitasTotal <= 0 ? 1 : p.kapasitasTotal))
                    .clamp(0.0, 1.0);
            final reference = category == WasteCategory.anorganik
                ? _referenceValue(p, subtype)
                : 0.0;
            final minimum = weightKg >= p.minimumPickupKg ? 1.0 : 0.0;
            final total = category == WasteCategory.organik
                ? compatibility * .5 + distance * .3 + capacity * .2
                : compatibility * .4 + reference * .3 + minimum * .3;
            return MatchCandidate(
              partner: p,
              compatibility: compatibility,
              distance: distance,
              capacity: capacity,
              referenceValue: reference,
              minimumVolume: minimum,
              totalScore: total,
            );
          })
          .toList()
        ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
  return list.take(3).toList();
}

bool _supports(
  PartnerActorModel partner,
  WasteCategory category,
  String? subtype,
) {
  final targetCategory = category == WasteCategory.organik
      ? 'organik'
      : 'anorganik';
  return partner.kategoriDiterima.any((material) {
    final normalized = _normalize(material);
    if (subtype != null && subtype.trim().isNotEmpty) {
      return normalized == _normalize(subtype);
    }
    if (normalized == targetCategory) return true;
    if (category == WasteCategory.organik) {
      return const {
        'kompos',
        'sisamakanan',
        'sayur',
        'buah',
      }.contains(normalized);
    }
    return const {
      'plastik',
      'botolplastikpet',
      'kertas',
      'kardus',
      'logam',
      'kaleng',
      'botol',
    }.contains(normalized);
  });
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

double _referenceValue(PartnerActorModel partner, String? subtype) {
  final normalized = _normalize(subtype ?? '');
  for (final entry in partner.referenceValues.entries) {
    if (_normalize(entry.key) == normalized) return entry.value;
  }
  return 0;
}

bool _withinRadius(PartnerActorModel partner, double? lat, double? lng) {
  if (lat == null || lng == null) return true;
  final distance =
      ((lat - partner.lat).abs() + (lng - partner.lng).abs()) * 111;
  return distance <= partner.serviceRadiusKm;
}

bool _pickupOverlaps(
  PartnerActorModel partner,
  DateTime? sourceStart,
  DateTime? sourceEnd,
) {
  if (sourceStart == null ||
      sourceEnd == null ||
      partner.pickupStart == null ||
      partner.pickupEnd == null) {
    return true;
  }
  return !sourceEnd.isBefore(partner.pickupStart!) &&
      !sourceStart.isAfter(partner.pickupEnd!);
}

double _distanceScore(
  double? lat,
  double? lng,
  double targetLat,
  double targetLng,
) {
  if (lat == null || lng == null) return .5;
  final distance = ((lat - targetLat).abs() + (lng - targetLng).abs()) * 111;
  return (1 - distance / 25).clamp(0.0, 1.0);
}
