import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/points_transaction_model.dart';

abstract class PointsRepositoryBase {
  Stream<List<PointsTransactionModel>> watchUserTransactions(String uid,
      {int limit = 20});

  /// Records a redeem request. This does NOT move real money — it only logs
  /// the request for manual admin follow-up, matching the app's UI-only
  /// e-wallet cash-out flow.
  Future<void> requestRedeem({
    required String uid,
    required int jumlah,
    required String deskripsi,
  });
}

class PointsRepository implements PointsRepositoryBase {
  PointsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('points_transactions');

  @override
  Stream<List<PointsTransactionModel>> watchUserTransactions(String uid,
      {int limit = 20}) {
    return _ref
        .where('uid', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PointsTransactionModel.fromMap(d.id, d.data()))
            .toList());
  }

  @override
  Future<void> requestRedeem({
    required String uid,
    required int jumlah,
    required String deskripsi,
  }) {
    final tx = PointsTransactionModel(
      id: '',
      uid: uid,
      jenis: PointsTransactionType.redeem,
      jumlah: jumlah,
      deskripsi: deskripsi,
      status: PointsTransactionStatus.pendingRedeem,
    );
    return _ref.add(tx.toMap());
  }
}
