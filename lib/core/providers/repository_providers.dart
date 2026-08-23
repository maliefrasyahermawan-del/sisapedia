import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/points_repository.dart';
import '../../data/repositories/submission_repository.dart';
import '../preview/fake_repositories.dart';
import '../services/sari_gateway_service.dart';
import '../services/speech_service.dart';
import '../services/waste_voice_parser.dart';
import '../session/session_mode.dart';

bool _isDemo(Ref ref) => ref.watch(sessionModeProvider) == SessionMode.demo;

final authRepositoryProvider = Provider<AuthRepositoryBase>(
  (ref) => _isDemo(ref) ? FakeAuthRepository() : AuthRepository(),
);
final submissionRepositoryProvider = Provider<SubmissionRepositoryBase>(
  (ref) => _isDemo(ref) ? FakeSubmissionRepository() : SubmissionRepository(),
);
final pointsRepositoryProvider = Provider<PointsRepositoryBase>(
  (ref) => _isDemo(ref) ? FakePointsRepository() : PointsRepository(),
);
final partnerRepositoryProvider = Provider<PartnerRepositoryBase>(
  (ref) => _isDemo(ref) ? FakePartnerRepository() : PartnerRepository(),
);
final contentRepositoryProvider = Provider<ContentRepositoryBase>(
  (ref) => _isDemo(ref) ? FakeContentRepository() : ContentRepository(),
);

final sariGatewayProvider = Provider<SariGatewayService>(
  (ref) => _isDemo(ref) ? FakeSariGatewayService() : SariGatewayService(),
);
final speechServiceProvider = Provider<SpeechService>((ref) => SpeechService());
final wasteVoiceParserProvider = Provider<WasteVoiceParser>(
  (ref) => RegexWasteVoiceParser(),
);

/// Emits the signed-in user's uid, null when signed out. Kept as a plain
/// String (not the raw Supabase User) so preview builds can override it
/// with fake data without needing a backend initialized.
final currentUidProvider = StreamProvider<String?>((ref) {
  return ref.watch(authRepositoryProvider).uidChanges;
});

/// Emits the current user's profile row, kept in sync with
/// [currentUidProvider]. Guests (no real account) get a fixed local profile.
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  if (ref.watch(sessionModeProvider) == SessionMode.guest) {
    return Stream.value(guestUserModel);
  }
  final uid = ref.watch(currentUidProvider).valueOrNull;
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(uid);
});
