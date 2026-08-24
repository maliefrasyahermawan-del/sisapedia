import 'package:cloud_firestore/cloud_firestore.dart';

enum WasteCategory { organik, anorganik }

extension WasteCategoryX on WasteCategory {
  String get label => this == WasteCategory.organik ? 'Organik' : 'Anorganik';

  static WasteCategory fromString(String value) {
    return value == 'anorganik' ? WasteCategory.anorganik : WasteCategory.organik;
  }

  String get value => name;
}

enum SubmissionStatus { pending, verified, rejected }

extension SubmissionStatusX on SubmissionStatus {
  String get label {
    switch (this) {
      case SubmissionStatus.pending:
        return 'Menunggu';
      case SubmissionStatus.verified:
        return 'Terverifikasi';
      case SubmissionStatus.rejected:
        return 'Ditolak';
    }
  }

  static SubmissionStatus fromString(String value) {
    return SubmissionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SubmissionStatus.pending,
    );
  }
}

enum SubmissionSource { manual, voice, foto }

enum DeliveryMode { cod, antarLangsung, requestPengolah }

extension DeliveryModeX on DeliveryMode {
  String get label {
    switch (this) {
      case DeliveryMode.cod:
        return 'COD (Ketemu Langsung)';
      case DeliveryMode.antarLangsung:
        return 'Antar Langsung';
      case DeliveryMode.requestPengolah:
        return 'Request Pengolah Datang';
    }
  }

  static DeliveryMode? fromString(String? value) {
    if (value == null) return null;
    for (final mode in DeliveryMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}

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

  /// Photo evidence of the waste — either taken specifically as bukti
  /// (manual flow) or the same photo used for AI detection (foto flow).
  final String? fotoUrl;

  /// Pickup/delivery address, entered manually each time (the app doesn't
  /// store a saved address on the user's profile yet). Meaning depends on
  /// [deliveryMode] — pickup address, drop-off destination, or COD meeting
  /// point.
  final String? alamat;
  final DateTime? tanggalPengantaran;
  final String? waktuPengantaran;
  final String? catatan;
  final DeliveryMode? deliveryMode;

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
    this.fotoUrl,
    this.alamat,
    this.tanggalPengantaran,
    this.waktuPengantaran,
    this.catatan,
    this.deliveryMode,
  });

  factory SubmissionModel.fromMap(String id, Map<String, dynamic> map) {
    return SubmissionModel(
      id: id,
      uid: map['uid'] as String? ?? '',
      kategori: WasteCategoryX.fromString(map['kategori'] as String? ?? 'organik'),
      subtipe: map['subtipe'] as String? ?? '',
      beratKg: (map['berat_kg'] as num?)?.toDouble() ?? 0,
      partnerId: map['partner_id'] as String?,
      partnerName: map['partner_name'] as String?,
      status: SubmissionStatusX.fromString(map['status'] as String? ?? 'pending'),
      source: SubmissionSource.values.firstWhere(
        (e) => e.name == (map['source'] as String? ?? 'manual'),
        orElse: () => SubmissionSource.manual,
      ),
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
      fotoUrl: map['foto_url'] as String?,
      alamat: map['alamat'] as String?,
      tanggalPengantaran:
          (map['tanggal_pengantaran'] as Timestamp?)?.toDate(),
      waktuPengantaran: map['waktu_pengantaran'] as String?,
      catatan: map['catatan'] as String?,
      deliveryMode: DeliveryModeX.fromString(map['delivery_mode'] as String?),
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
      'created_at': FieldValue.serverTimestamp(),
      'foto_url': fotoUrl,
      'alamat': alamat,
      'tanggal_pengantaran': tanggalPengantaran != null
          ? Timestamp.fromDate(tanggalPengantaran!)
          : null,
      'waktu_pengantaran': waktuPengantaran,
      'catatan': catatan,
      'delivery_mode': deliveryMode?.name,
    };
  }
}
