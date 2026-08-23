import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sisapedia/features/auth/login_screen.dart';
import 'package:sisapedia/features/roles/role_shell_screen.dart';
import 'package:sisapedia/core/preview/preview_store.dart';
import 'package:sisapedia/core/session/session_mode.dart';
import 'package:sisapedia/data/models/submission_model.dart';
import 'package:sisapedia/features/setor_manual/setor_form_screen.dart';

void main() {
  testWidgets('LoginScreen renders the sign-in form', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('Preview role shell exposes distinct role navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await PreviewStore.initialize();
    final container = ProviderContainer();
    container.read(sessionModeProvider.notifier).state = SessionMode.demo;
    container.read(previewRoleProvider.notifier).state = 'pengolah';
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RoleShellScreen()),
      ),
    );
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Permintaan'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Kapasitas'), findsOneWidget);
    await tester.tap(find.text('Pickup'));
    await tester.pump();
    expect(find.text('Pickup'), findsWidgets);
    container.dispose();
  });

  testWidgets('Preview role switcher reaches Sumber profile tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await PreviewStore.initialize();
    final container = ProviderContainer();
    container.read(sessionModeProvider.notifier).state = SessionMode.demo;
    container.read(previewRoleProvider.notifier).state = 'sumber';
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RoleShellScreen()),
      ),
    );
    await tester.tap(find.byTooltip('Ganti peran Preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin SisaPedia'));
    await tester.pumpAndSettle();
    expect(find.text('Antrean verifikasi'), findsOneWidget);
    await tester.tap(find.byTooltip('Ganti peran Preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sumber · Bu Siti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pump();
    expect(find.text('Profil Sumber'), findsOneWidget);
    container.dispose();
  });

  testWidgets('Sari typed edits are carried into the manual form prefill', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await PreviewStore.initialize();
    final container = ProviderContainer();
    container.read(sessionModeProvider.notifier).state = SessionMode.demo;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SetorFormScreen(
            kategori: WasteCategory.anorganik,
            prefill: WastePrefill(
              kategori: WasteCategory.anorganik,
              subtipe: 'Botol Plastik PET',
              beratKg: 4.5,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Botol Plastik PET'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    container.dispose();
  });
}
