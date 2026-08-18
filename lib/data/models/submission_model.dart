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
      source: (map['source'] as String?) == 'voice'
          ? SubmissionSource.voice
          : SubmissionSource.manual,
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
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
    };
  }
}
