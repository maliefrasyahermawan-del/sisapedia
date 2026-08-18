import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/points_repository.dart';
import '../../data/repositories/submission_repository.dart';
import '../services/groq_service.dart';
import '../services/speech_service.dart';
import '../services/waste_voice_parser.dart';

final authRepositoryProvider =
    Provider<AuthRepositoryBase>((ref) => AuthRepository());
final submissionRepositoryProvider =
    Provider<SubmissionRepositoryBase>((ref) => SubmissionRepository());
final pointsRepositoryProvider =
    Provider<PointsRepositoryBase>((ref) => PointsRepository());
final partnerRepositoryProvider =
    Provider<PartnerRepositoryBase>((ref) => PartnerRepository());
final contentRepositoryProvider =
    Provider<ContentRepositoryBase>((ref) => ContentRepository());

final groqServiceProvider = Provider<GroqService>((ref) => GroqService());
final speechServiceProvider = Provider<SpeechService>((ref) => SpeechService());
final wasteVoiceParserProvider =
    Provider<WasteVoiceParser>((ref) => RegexWasteVoiceParser());

/// Emits the signed-in user's uid, null when signed out. Kept as a plain
/// String (not the raw Firebase User) so preview builds can override it
/// with fake data without needing Firebase initialized.
final currentUidProvider = StreamProvider<String?>((ref) {
  return ref.watch(authRepositoryProvider).uidChanges;
});

/// Emits the current user's Firestore profile document, kept in sync with
/// [currentUidProvider].
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(currentUidProvider).valueOrNull;
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(uid);
});
