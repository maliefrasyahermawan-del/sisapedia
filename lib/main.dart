import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/preview/preview_mode.dart';
import 'core/preview/preview_store.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreviewStore.initialize();
  if (!kPreviewMode &&
      _supabaseUrl.isNotEmpty &&
      _supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
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
