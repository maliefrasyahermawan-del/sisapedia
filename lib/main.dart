import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/preview/preview_mode.dart';
import 'core/session/testing_accounts.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // PREVIEW_MODE builds run entirely on in-memory sample data (see
  // core/preview/preview_mode.dart) and never touch Firebase, so a real
  // project isn't required just to review the UI.
  if (!kPreviewMode) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // The "Akun Testing"/"Akun Pengolah (Testing)" buttons sign into a real,
    // shared Firebase identity now (see testing_accounts.dart) so two
    // devices can sync live — but `sessionModeProvider` is still in-memory
    // and always resets to `normal` on a fresh app start. Firebase's own
    // login session persists across restarts by default, so without this
    // check a device that last used a testing account would silently come
    // back signed into that shared identity while the UI thinks it's a
    // logged-out `normal` session — sign it out here so testing accounts
    // keep the "resets every restart" behavior they've always had, while
    // real registered accounts keep their normal persisted login.
    final current = FirebaseAuth.instance.currentUser;
    if (current != null &&
        (current.email == kTestingSumberAccount.email ||
            current.email == kTestingPengolahAccount.email)) {
      await FirebaseAuth.instance.signOut();
    }
  }

  await initializeDateFormatting('id_ID', null);
  runApp(
    ProviderScope(
      overrides: kPreviewMode ? previewModeOverrides : const [],
      child: const SisaPediaApp(),
    ),
  );
}
