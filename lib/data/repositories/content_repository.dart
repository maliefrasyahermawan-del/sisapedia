import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/article_model.dart';
import '../models/movement_event_model.dart';

abstract class ContentRepositoryBase {
  Stream<List<ArticleModel>> watchArticles();

  Stream<List<MovementEventModel>> watchMovementEvents();

  Future<void> joinEvent({required String eventId, required String uid});
}

class ContentRepository implements ContentRepositoryBase {
  ContentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ArticleModel>> watchArticles() {
    return _firestore
        .collection('articles')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ArticleModel.fromMap(d.id, d.data()))
            .toList());
  }

  @override
  Stream<List<MovementEventModel>> watchMovementEvents() {
    return _firestore
        .collection('movement_events')
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MovementEventModel.fromMap(d.id, d.data()))
            .toList());
  }

  @override
  Future<void> joinEvent({required String eventId, required String uid}) {
    return _firestore
        .collection('movement_events')
        .doc(eventId)
        .collection('participants')
        .doc(uid)
        .set({'joined_at': FieldValue.serverTimestamp()});
  }
}
