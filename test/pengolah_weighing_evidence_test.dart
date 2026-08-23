import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sisapedia/core/providers/role_snapshot_provider.dart';
import 'package:sisapedia/core/session/session_mode.dart';
import 'package:sisapedia/features/roles/pengolah_role_screen.dart';

void main() {
  testWidgets('Preview weighing dialog offers gallery and sample evidence', (
    tester,
  ) async {
    const snapshot = RoleSnapshot(
      profiles: [
        {'primary_role': 'pengolah', 'processor_status': 'approved'},
      ],
      submissions: [
        {
          'id': 'weighing-1',
          'partner_id': 'preview-pengolah',
          'status': 'accepted',
          'subtipe': 'Botol Plastik PET',
          'berat_kg': 1.5,
        },
      ],
    );
    RoleSnapshot.current = snapshot;
    RoleSnapshot.currentProcessorId = 'preview-pengolah';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionModeProvider.overrideWith((ref) => SessionMode.demo),
          roleSnapshotProvider.overrideWith((ref) => Stream.value(snapshot)),
        ],
        child: const MaterialApp(home: PengolahRoleScreen(tab: 2)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catat timbang'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih foto timbangan (wajib)'), findsOneWidget);
    expect(find.text('Gunakan contoh bukti timbang'), findsOneWidget);

    await tester.tap(find.text('Gunakan contoh bukti timbang'));
    await tester.pump();
    expect(find.text('Bukti dipilih: scale-evidence.png'), findsOneWidget);
  });
}
