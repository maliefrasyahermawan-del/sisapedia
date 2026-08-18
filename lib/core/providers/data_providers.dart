import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/article_model.dart';
import '../../data/models/movement_event_model.dart';
import '../../data/models/partner_actor_model.dart';
import '../../data/models/points_transaction_model.dart';
import '../../data/models/submission_model.dart';
import 'repository_providers.dart';

final userSubmissionsProvider =
    StreamProvider.family<List<SubmissionModel>, String>((ref, uid) {
  return ref.watch(submissionRepositoryProvider).watchUserSubmissions(uid);
});

/// `uid == null` aggregates the whole city ("Kota" dashboard scope), a
/// non-null uid scopes to that user's own verified submissions ("Saya").
final dashboardSubmissionsProvider =
    StreamProvider.family<List<SubmissionModel>, String?>((ref, uid) {
  return ref
      .watch(submissionRepositoryProvider)
      .watchVerifiedSubmissions(uid: uid);
});

final userPointsTransactionsProvider =
    StreamProvider.family<List<PointsTransactionModel>, String>((ref, uid) {
  return ref.watch(pointsRepositoryProvider).watchUserTransactions(uid);
});

final articlesProvider = StreamProvider<List<ArticleModel>>((ref) {
  return ref.watch(contentRepositoryProvider).watchArticles();
});

final movementEventsProvider = StreamProvider<List<MovementEventModel>>((ref) {
  return ref.watch(contentRepositoryProvider).watchMovementEvents();
});

final partnersProvider = StreamProvider<List<PartnerActorModel>>((ref) {
  return ref.watch(partnerRepositoryProvider).watchPartners();
});

/// Generates the "Insight AI Sari" sentence from a pre-built data summary.
/// Keyed by the summary string so the same stats don't trigger repeat calls.
final aiInsightProvider =
    FutureProvider.family<String, String>((ref, dataSummary) {
  return ref.watch(groqServiceProvider).generateInsight(dataSummary);
});
