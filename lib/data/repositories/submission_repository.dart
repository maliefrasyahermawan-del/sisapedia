import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/submission_model.dart';

abstract class SubmissionRepositoryBase {
  Future<void> create(SubmissionModel submission);

  Stream<List<SubmissionModel>> watchUserSubmissions(String uid, {int limit = 20});

  /// Verified submissions for dashboard aggregation. Pass [uid] for the
  /// personal "Saya" view, or omit it for the city-wide "Kota" view.
  Stream<List<SubmissionModel>> watchVerifiedSubmissions({String? uid});
}

class SubmissionRepository implements SubmissionRepositoryBase {
  SubmissionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('submissions');

  @override
  Future<void> create(SubmissionModel submission) {
    return _ref.add(submission.toMap());
  }

  @override
  Stream<List<SubmissionModel>> watchUserSubmissions(String uid,
      {int limit = 20}) {
    return _ref
        .where('uid', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SubmissionModel.fromMap(d.id, d.data()))
            .toList());
  }

  @override
  Stream<List<SubmissionModel>> watchVerifiedSubmissions({String? uid}) {
    Query<Map<String, dynamic>> query =
        _ref.where('status', isEqualTo: SubmissionStatus.verified.name);
    if (uid != null) {
      query = query.where('uid', isEqualTo: uid);
    }
    return query.snapshots().map((snap) => snap.docs
        .map((d) => SubmissionModel.fromMap(d.id, d.data()))
        .toList());
  }
}
