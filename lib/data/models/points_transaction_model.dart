import 'package:cloud_firestore/cloud_firestore.dart';

enum PointsTransactionType { earn, redeem }

enum PointsTransactionStatus { completed, pendingRedeem }

extension PointsTransactionStatusX on PointsTransactionStatus {
  String get label {
    switch (this) {
      case PointsTransactionStatus.completed:
        return 'Selesai';
      case PointsTransactionStatus.pendingRedeem:
        return 'Diproses admin';
    }
  }
}

class PointsTransactionModel {
  final String id;
  final String uid;
  final PointsTransactionType jenis;
  final int jumlah;
  final String deskripsi;
  final PointsTransactionStatus status;
  final DateTime? createdAt;

  const PointsTransactionModel({
    required this.id,
    required this.uid,
    required this.jenis,
    required this.jumlah,
    required this.deskripsi,
    this.status = PointsTransactionStatus.completed,
    this.createdAt,
  });

  factory PointsTransactionModel.fromMap(String id, Map<String, dynamic> map) {
    return PointsTransactionModel(
      id: id,
      uid: map['uid'] as String? ?? '',
      jenis: (map['jenis'] as String?) == 'redeem'
          ? PointsTransactionType.redeem
          : PointsTransactionType.earn,
      jumlah: (map['jumlah'] as num?)?.toInt() ?? 0,
      deskripsi: map['deskripsi'] as String? ?? '',
      status: (map['status'] as String?) == 'pending_redeem'
          ? PointsTransactionStatus.pendingRedeem
          : PointsTransactionStatus.completed,
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'jenis': jenis.name,
      'jumlah': jumlah,
      'deskripsi': deskripsi,
      'status': status == PointsTransactionStatus.pendingRedeem
          ? 'pending_redeem'
          : 'completed',
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
