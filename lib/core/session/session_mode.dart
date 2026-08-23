import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../preview/preview_store.dart';

/// How the current session is authenticated: a real Supabase account, a
/// guest browsing without an account, or a local demo/testing account
/// pre-filled with mock data.
enum SessionMode { normal, guest, demo }

final sessionModeProvider = StateProvider<SessionMode>(
  (ref) => SessionMode.normal,
);

final previewRoleProvider = StateProvider<String>((ref) => PreviewStore.role);

/// Synthetic id used for guests so uid-scoped screens/providers can work
/// without a real backend user. Normal-mode queries scope to this id.
const kGuestUid = 'guest-local';

/// Identity used by role repositories/UI. Preview IDs are intentionally
/// confined to demo mode; normal mode always uses Supabase auth.uid.
String processorIdentity({
  required SessionMode mode,
  String? authenticatedUid,
}) => mode == SessionMode.demo ? 'preview-pengolah' : (authenticatedUid ?? '');

const guestUserModel = UserModel(
  uid: kGuestUid,
  name: 'Tamu',
  email: '',
  levelTitle: 'Tamu',
  primaryRole: 'sumber',
);
