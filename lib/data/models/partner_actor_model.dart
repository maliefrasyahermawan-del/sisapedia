enum PartnerType { bankSampah, maggotBsf, pengepul, pengompos }

extension PartnerTypeX on PartnerType {
  String get label {
    switch (this) {
      case PartnerType.bankSampah:
        return 'Bank Sampah';
      case PartnerType.maggotBsf:
        return 'Maggot BSF';
      case PartnerType.pengepul:
        return 'Pengepul';
      case PartnerType.pengompos:
        return 'Pengompos';
    }
  }

  static PartnerType fromString(String value) {
    return PartnerType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PartnerType.bankSampah,
    );
  }
}

class PartnerActorModel {
  final String id;
  final String nama;
  final PartnerType tipe;
  final double lat;
  final double lng;
  final double kapasitasTersedia;
  final double kapasitasTotal;
  final List<String> kategoriDiterima;
  final String kecamatan;
  final String alamat;
  final bool active;
  final bool approved;
  final bool pickupAvailable;
  final double serviceRadiusKm;
  final double minimumPickupKg;
  final DateTime? pickupStart;
  final DateTime? pickupEnd;
  final Map<String, double> referenceValues;

  const PartnerActorModel({
    required this.id,
    required this.nama,
    required this.tipe,
    required this.lat,
    required this.lng,
    required this.kapasitasTersedia,
    required this.kapasitasTotal,
    this.kategoriDiterima = const [],
    this.kecamatan = '',
    this.alamat = '',
    this.active = true,
    this.approved = true,
    this.pickupAvailable = true,
    this.serviceRadiusKm = 10,
    this.minimumPickupKg = 1,
    this.pickupStart,
    this.pickupEnd,
    this.referenceValues = const {},
  });

  factory PartnerActorModel.fromMap(String id, Map<String, dynamic> map) {
    return PartnerActorModel(
      id: id,
      nama: map['nama'] as String? ?? '',
      tipe: PartnerTypeX.fromString(map['tipe'] as String? ?? 'bank_sampah'),
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      kapasitasTersedia: (map['kapasitas_tersedia'] as num?)?.toDouble() ?? 0,
      kapasitasTotal: (map['kapasitas_total'] as num?)?.toDouble() ?? 0,
      kategoriDiterima:
          (map['kategori_diterima'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      kecamatan: map['kecamatan'] as String? ?? '',
      alamat: map['alamat'] as String? ?? '',
      active: map['active'] as bool? ?? true,
      approved:
          (map['approved'] as bool?) ??
          (map['status'] == null || map['status'] == 'approved'),
      pickupAvailable: map['pickup_available'] as bool? ?? true,
      serviceRadiusKm: (map['service_radius_km'] as num?)?.toDouble() ?? 10,
      minimumPickupKg: (map['minimum_pickup_kg'] as num?)?.toDouble() ?? 1,
      pickupStart: _date(map['pickup_start']),
      pickupEnd: _date(map['pickup_end']),
      referenceValues:
          (map['reference_values'] as Map?)?.map(
            (key, value) =>
                MapEntry(key.toString(), (value as num?)?.toDouble() ?? 0),
          ) ??
          const {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'tipe': tipe.name,
      'lat': lat,
      'lng': lng,
      'kapasitas_tersedia': kapasitasTersedia,
      'kapasitas_total': kapasitasTotal,
      'kategori_diterima': kategoriDiterima,
      'kecamatan': kecamatan,
      'alamat': alamat,
      'active': active,
      'approved': approved,
      'pickup_available': pickupAvailable,
      'service_radius_km': serviceRadiusKm,
      'minimum_pickup_kg': minimumPickupKg,
      'pickup_start': pickupStart?.toUtc().toIso8601String(),
      'pickup_end': pickupEnd?.toUtc().toIso8601String(),
      'reference_values': referenceValues,
    };
  }
}

DateTime? _date(dynamic value) => value is DateTime
    ? value
    : value is String
    ? DateTime.tryParse(value)
    : null;
