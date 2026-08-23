enum WasteCategory { organik, anorganik }

extension WasteCategoryX on WasteCategory {
  String get label => this == WasteCategory.organik ? 'Organik' : 'Anorganik';

  static WasteCategory fromString(String value) {
    return value == 'anorganik'
        ? WasteCategory.anorganik
        : WasteCategory.organik;
  }

  String get value => name;
}

/// Shared transaction state machine. `verified` remains as a compatibility
/// alias for historical preview rows; new records use the lifecycle states.
enum SubmissionStatus {
  submitted,
  matching,
  offered,
  accepted,
  enRoute,
  weighed,
  completed,
  expired,
  rejected,
  cancelled,
  disputed,
  pending,
  verified,
}

extension SubmissionStatusX on SubmissionStatus {
  String get label {
    switch (this) {
      case SubmissionStatus.pending:
        return 'Menunggu';
      case SubmissionStatus.submitted:
      case SubmissionStatus.matching:
        return 'Mencari mitra';
      case SubmissionStatus.offered:
        return 'Menunggu respons';
      case SubmissionStatus.accepted:
        return 'Diterima';
      case SubmissionStatus.enRoute:
        return 'Dalam perjalanan';
      case SubmissionStatus.weighed:
        return 'Menunggu konfirmasi';
      case SubmissionStatus.completed:
      case SubmissionStatus.verified:
        return 'Terverifikasi';
      case SubmissionStatus.rejected:
        return 'Ditolak';
      case SubmissionStatus.expired:
        return 'Kedaluwarsa';
      case SubmissionStatus.cancelled:
        return 'Dibatalkan';
      case SubmissionStatus.disputed:
        return 'Sengketa';
    }
  }

  static SubmissionStatus fromString(String value) {
    final normalized = value == 'en_route' ? 'enRoute' : value;
    return SubmissionStatus.values.firstWhere(
      (e) => e.name == normalized,
      orElse: () => SubmissionStatus.pending,
    );
  }
}

enum SubmissionSource { manual, voice }

class SubmissionModel {
  final String id;
  final String uid;
  final WasteCategory kategori;
  final String subtipe;
  final double beratKg;
  final String? partnerId;
  final String? partnerName;
  final SubmissionStatus status;
  final SubmissionSource source;
  final DateTime? createdAt;
  final String? district;
  final String? address;
  final DateTime? pickupStart;
  final DateTime? pickupEnd;
  final String? sourcePhotoPath;
  final double? latitude;
  final double? longitude;

  const SubmissionModel({
    required this.id,
    required this.uid,
    required this.kategori,
    required this.subtipe,
    required this.beratKg,
    this.partnerId,
    this.partnerName,
    this.status = SubmissionStatus.pending,
    this.source = SubmissionSource.manual,
    this.createdAt,
    this.district,
    this.address,
    this.pickupStart,
    this.pickupEnd,
    this.sourcePhotoPath,
    this.latitude,
    this.longitude,
  });

  factory SubmissionModel.fromMap(String id, Map<String, dynamic> map) {
    return SubmissionModel(
      id: id,
      uid: map['uid'] as String? ?? '',
      kategori: WasteCategoryX.fromString(
        map['kategori'] as String? ?? 'organik',
      ),
      subtipe: map['subtipe'] as String? ?? '',
      beratKg: (map['berat_kg'] as num?)?.toDouble() ?? 0,
      partnerId: map['partner_id'] as String?,
      partnerName: map['partner_name'] as String?,
      status: SubmissionStatusX.fromString(
        map['status'] as String? ?? 'submitted',
      ),
      source: (map['source'] as String?) == 'voice'
          ? SubmissionSource.voice
          : SubmissionSource.manual,
      createdAt: _date(map['created_at']),
      district: map['district'] as String?,
      address: map['address'] as String?,
      pickupStart: _date(map['pickup_start']),
      pickupEnd: _date(map['pickup_end']),
      sourcePhotoPath: map['source_photo_path'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'kategori': kategori.value,
      'subtipe': subtipe,
      'berat_kg': beratKg,
      'partner_id': partnerId,
      'partner_name': partnerName,
      'status': status.name,
      'source': source.name,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'district': district,
      'address': address,
      'pickup_start': pickupStart?.toUtc().toIso8601String(),
      'pickup_end': pickupEnd?.toUtc().toIso8601String(),
      'source_photo_path': sourcePhotoPath,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  SubmissionModel copyWith({
    String? id,
    String? partnerId,
    String? partnerName,
    SubmissionStatus? status,
    double? beratKg,
    DateTime? createdAt,
    String? district,
    String? address,
    DateTime? pickupStart,
    DateTime? pickupEnd,
    String? sourcePhotoPath,
    double? latitude,
    double? longitude,
  }) => SubmissionModel(
    id: id ?? this.id,
    uid: uid,
    kategori: kategori,
    subtipe: subtipe,
    beratKg: beratKg ?? this.beratKg,
    partnerId: partnerId ?? this.partnerId,
    partnerName: partnerName ?? this.partnerName,
    status: status ?? this.status,
    source: source,
    createdAt: createdAt ?? this.createdAt,
    district: district ?? this.district,
    address: address ?? this.address,
    pickupStart: pickupStart ?? this.pickupStart,
    pickupEnd: pickupEnd ?? this.pickupEnd,
    sourcePhotoPath: sourcePhotoPath ?? this.sourcePhotoPath,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
  );
}

DateTime? _date(dynamic value) => value is DateTime
    ? value
    : value is String
    ? DateTime.tryParse(value)
    : null;
