import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/submission_model.dart';

abstract class SubmissionRepositoryBase {
  /// Returns the created submission's id, so callers can navigate to a
  /// realtime tracker for it right away.
  Future<String> create(SubmissionModel submission);

  /// Realtime single-submission stream, used by the progress tracker screen.
  Stream<SubmissionModel?> watchSubmission(String id);

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
  Future<String> create(SubmissionModel submission) async {
    final doc = await _ref.add(submission.toMap());
    return doc.id;
  }

  @override
  Stream<SubmissionModel?> watchSubmission(String id) {
    return _ref.doc(id).snapshots().map(
        (doc) => doc.exists ? SubmissionModel.fromMap(doc.id, doc.data()!) : null);
  }

  @override
  Stream<List<SubmissionModel>> watchUserSubmissions(String uid,
      {int limit = 20}) {
    // Single `where` + client-side sort/limit (not `.orderBy()` +
    // `.limit()` server-side) — combining an equality filter with
    // `orderBy` on a different field needs a composite Firestore index
    // that doesn't exist on a fresh project until manually created.
    return _ref.where('uid', isEqualTo: uid).snapshots().map((snap) {
      final items = snap.docs
          .map((d) => SubmissionModel.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items.take(limit).toList();
    });
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
