import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';

/// How the current session is authenticated: a real Firebase account, a
/// guest browsing without an account, a local demo/testing account
/// pre-filled with mock data (role Sumber), or a local demo/testing account
/// for role Pengolah (`pengolahDemo`) — entirely separate UI/data from the
/// Sumber app, does not touch any Sumber repository/provider.
enum SessionMode { normal, guest, demo, pengolahDemo }

final sessionModeProvider =
    StateProvider<SessionMode>((ref) => SessionMode.normal);

/// Synthetic id used for guests so uid-scoped screens/providers can work
/// without a real Firebase user. Firestore queries against this id simply
/// return no results.
const kGuestUid = 'guest-local';

const guestUserModel = UserModel(
  uid: kGuestUid,
  name: 'Tamu',
  email: '',
  levelTitle: 'Tamu',
);
