import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/repository_providers.dart';
import 'fake_repositories.dart';
import '../session/session_mode.dart';
import '../services/sari_gateway_service.dart';

/// Whether this build should run entirely on local sample data instead
/// of Supabase. Build with:
///   flutter build apk --release --dart-define=PREVIEW_MODE=true
/// Lets reviewers install an APK and see every screen populated without
/// first setting up a Supabase project or router key.
const bool kPreviewMode = bool.fromEnvironment(
  'PREVIEW_MODE',
  defaultValue: true,
);

/// Riverpod overrides that swap every Supabase-backed provider for the fakes in
/// fake_repositories.dart. Sari is live-first with the same fake as fallback.
/// Applied to [ProviderScope] only when [kPreviewMode] is true.
final previewModeOverrides = <Override>[
  sessionModeProvider.overrideWith((ref) => SessionMode.demo),
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  submissionRepositoryProvider.overrideWithValue(FakeSubmissionRepository()),
  pointsRepositoryProvider.overrideWithValue(FakePointsRepository()),
  partnerRepositoryProvider.overrideWithValue(FakePartnerRepository()),
  contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
  // Preview stays fully local when no token/network is available, but tries
  // OmniRoute first so the jury APK can demonstrate live Sari responses.
  sariGatewayProvider.overrideWithValue(
    OmniRouteSariGatewayService(fallback: FakeSariGatewayService()),
  ),
];
