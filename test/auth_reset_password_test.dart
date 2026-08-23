import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sisapedia/core/preview/fake_repositories.dart';
import 'package:sisapedia/core/providers/repository_providers.dart';
import 'package:sisapedia/features/auth/login_screen.dart';

void main() {
  test(
    'Preview reset request is deterministic and does not inspect accounts',
    () async {
      final repository = FakeAuthRepository();

      await repository.resetPasswordForEmail('  demo@example.com ');

      expect(repository.lastPasswordResetEmail, 'demo@example.com');
    },
  );

  testWidgets('forgot password validates email and confirms generically', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('Lupa kata sandi?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset kata sandi'), findsOneWidget);

    final emailField = find.byType(TextFormField).last;
    await tester.enterText(emailField, 'not-an-email');
    await tester.tap(find.text('Kirim tautan'));
    await tester.pump();
    expect(find.text('Masukkan email yang valid'), findsOneWidget);

    await tester.enterText(emailField, 'person@example.com');
    await tester.tap(find.text('Kirim tautan'));
    await tester.pumpAndSettle();

    expect(find.text('Reset kata sandi'), findsNothing);
    expect(
      find.text(
        'Jika akun dengan email tersebut ada, tautan reset kata sandi akan dikirim.',
      ),
      findsOneWidget,
    );
  });
}
