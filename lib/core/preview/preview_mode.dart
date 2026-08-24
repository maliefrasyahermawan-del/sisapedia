import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/repository_providers.dart';
import 'fake_repositories.dart';

/// Whether this build should run entirely on in-memory sample data instead
/// of Firebase/Groq. Build with:
///   flutter build apk --release --dart-define=PREVIEW_MODE=true
/// Lets reviewers install an APK and see every screen populated without
/// first setting up a Firebase project or Groq API key.
const bool kPreviewMode = bool.fromEnvironment('PREVIEW_MODE');

/// Riverpod overrides that swap every Firebase/Groq-backed provider for the
/// fakes in fake_repositories.dart. Applied to [ProviderScope] only when
/// [kPreviewMode] is true.
final previewModeOverrides = <Override>[
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  submissionRepositoryProvider.overrideWithValue(FakeSubmissionRepository()),
  pointsRepositoryProvider.overrideWithValue(FakePointsRepository()),
  partnerRepositoryProvider.overrideWithValue(FakePartnerRepository()),
  contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
  groqServiceProvider.overrideWithValue(FakeGroqService()),
  geminiVisionServiceProvider.overrideWithValue(FakeGeminiVisionService()),
];
