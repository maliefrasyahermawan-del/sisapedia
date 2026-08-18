import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/preview/preview_mode.dart';
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
  }

  await initializeDateFormatting('id_ID', null);
  runApp(
    ProviderScope(
      overrides: kPreviewMode ? previewModeOverrides : const [],
      child: const SisaPediaApp(),
    ),
  );
}
