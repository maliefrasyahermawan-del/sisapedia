import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sisapedia/core/preview/fake_repositories.dart';
import 'package:sisapedia/core/providers/repository_providers.dart';
import 'package:sisapedia/core/session/session_mode.dart';
import 'package:sisapedia/features/auth/login_screen.dart';

void main() {
  testWidgets(
    'OTP requires send, validates six digits, and shows Preview code',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionModeProvider.overrideWith((ref) => SessionMode.demo),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.tap(find.text('Masuk dengan OTP nomor HP'));
      await tester.pumpAndSettle();
      expect(find.text('Verifikasi'), findsNothing);

      final phone = find.byType(TextFormField).last;
      await tester.enterText(phone, '123');
      await tester.tap(find.text('Kirim OTP'));
      await tester.pump();
      expect(
        find.textContaining('Masukkan nomor HP Indonesia yang valid'),
        findsOneWidget,
      );

      await tester.enterText(phone, '081234567890');
      await tester.tap(find.text('Kirim OTP'));
      await tester.pumpAndSettle();
      expect(find.text('Preview: gunakan kode 246810.'), findsOneWidget);
      expect(find.text('Verifikasi'), findsOneWidget);

      final token = find.byType(TextField).last;
      await tester.enterText(token, '123');
      await tester.tap(find.text('Verifikasi'));
      await tester.pump();
      expect(find.text('Kode OTP harus terdiri dari 6 digit.'), findsOneWidget);

      await tester.enterText(token, '246810');
      await tester.tap(find.text('Verifikasi'));
      await tester.pumpAndSettle();
      expect(find.text('OTP nomor HP'), findsNothing);
    },
  );

  testWidgets('normal mode does not expose the Preview OTP code', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionModeProvider.overrideWith((ref) => SessionMode.normal),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('Masuk dengan OTP nomor HP'));
    await tester.pumpAndSettle();
    final phone = find.byType(TextFormField).last;
    await tester.enterText(phone, '081234567890');
    await tester.tap(find.text('Kirim OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Preview: gunakan kode 246810.'), findsNothing);
  });
}
