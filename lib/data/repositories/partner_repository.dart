import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/partner_actor_model.dart';

abstract class PartnerRepositoryBase {
  Stream<List<PartnerActorModel>> watchPartners();

  Future<void> requestMatch({required String partnerId, required String uid});
}

class PartnerRepository implements PartnerRepositoryBase {
  PartnerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('partners');

  @override
  Stream<List<PartnerActorModel>> watchPartners() {
    return _ref.snapshots().map((snap) => snap.docs
        .map((d) => PartnerActorModel.fromMap(d.id, d.data()))
        .toList());
  }

  @override
  Future<void> requestMatch({
    required String partnerId,
    required String uid,
  }) {
    return _firestore.collection('match_requests').add({
      'partner_id': partnerId,
      'uid': uid,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
