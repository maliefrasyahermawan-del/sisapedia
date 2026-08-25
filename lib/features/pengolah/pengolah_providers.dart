import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/services/submission_flow_service.dart';
import '../../data/models/submission_model.dart';

/// Shared live counts for the Pengolah shell — used by both the Beranda
/// bell/quick-menu and the Dashboard stat cards, so the two stay in sync
/// without duplicating the Firestore query in each widget file.
///
/// New submissions waiting for any Pengolah to accept (global queue, only
/// one Pengolah testing account exists in this demo).
final pengolahIncomingQueueCountProvider = StreamProvider<int>((ref) {
  return ref
      .watch(submissionFlowServiceProvider)
      .watchIncomingQueue()
      .map((items) => items.length);
});

/// Submissions this Pengolah has already received but hasn't finished
/// verifying yet — a universal "stuff waiting on you" number that fits any
/// kind of processor (bank sampah, pengepul, pengomposan, dst), unlike a
/// facility-specific stat like a maggot pen's fill level.
final pengolahMenungguVerifikasiCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUidProvider).valueOrNull;
  if (uid == null) return Stream.value(0);
  return ref.watch(submissionFlowServiceProvider).watchPengolahAktif(uid).map(
        (items) => items
            .where((s) =>
                s.flowStatus == SubmissionFlowStatus.diterimaPengolah ||
                s.flowStatus == SubmissionFlowStatus.sedangDiverifikasi)
            .length,
      );
});
