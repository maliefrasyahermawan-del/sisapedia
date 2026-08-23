import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sisapedia/core/preview/preview_store.dart';

void main() {
  test(
    'Preview store reset reseeds both branches and emits a revision',
    () async {
      SharedPreferences.setMockInitialValues({});
      await PreviewStore.initialize();
      PreviewStore.role = 'admin';
      final revision = expectLater(PreviewStore.changes, emits(isA<int>()));
      await PreviewStore.reset();
      await revision;
      expect(PreviewStore.role, 'sumber');
      expect(
        PreviewStore.submissions.map((row) => row['kategori']),
        containsAll(<String>['organik', 'anorganik']),
      );
      expect(
        PreviewStore.profiles.map((row) => row['name']),
        containsAll(<String>[
          'Bu Siti',
          'Pak Bambang',
          'DLH Semarang',
          'Admin SisaPedia',
        ]),
      );
    },
  );

  test('Preview state survives repository-style reinitialization', () async {
    SharedPreferences.setMockInitialValues({});
    await PreviewStore.initialize();
    PreviewStore.role = 'pengolah';
    PreviewStore.submissions.first['status'] = 'accepted';
    await PreviewStore.save();
    await PreviewStore.initialize();
    expect(PreviewStore.role, 'pengolah');
    expect(PreviewStore.submissions.first['status'], 'accepted');
  });

  test(
    'content drafts and the canonical audit collection survive restart',
    () async {
      SharedPreferences.setMockInitialValues({});
      await PreviewStore.initialize();
      PreviewStore.content.add({'id': 'draft-1', 'status': 'draft'});
      PreviewStore.audits.add({'id': 'audit-1', 'action': 'test'});
      await PreviewStore.save();
      await PreviewStore.initialize();
      expect(PreviewStore.content.single['id'], 'draft-1');
      expect(PreviewStore.audits.any((row) => row['id'] == 'audit-1'), isTrue);
    },
  );
}
