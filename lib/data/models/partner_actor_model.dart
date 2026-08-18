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

  const PartnerActorModel({
    required this.id,
    required this.nama,
    required this.tipe,
    required this.lat,
    required this.lng,
    required this.kapasitasTersedia,
    required this.kapasitasTotal,
    this.kategoriDiterima = const [],
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
      kategoriDiterima: (map['kategori_diterima'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
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
    };
  }
}
