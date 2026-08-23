import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sisapedia/core/preview/fake_repositories.dart';
import 'package:sisapedia/core/preview/preview_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreviewStore.initialize();
  });

  test('Pengolah drafts and submits content; Admin moderates it', () async {
    final repo = FakeContentRepository();
    PreviewStore.role = 'pengolah';
    final id = await repo.createDraft(
      kind: 'article',
      title: 'Kompos',
      body: 'Panduan',
    );
    await repo.updateDraft(id: id, title: 'Kompos 2', body: 'Panduan baru');
    await repo.submitDraft(id);
    expect(PreviewStore.content.single['title'], 'Kompos 2');
    expect(PreviewStore.content.single['status'], 'submitted');
    PreviewStore.role = 'admin';
    await repo.moderateDraft(id, approve: true, reason: 'Sesuai panduan');
    expect(PreviewStore.content.single['status'], 'approved');
    final feed = await repo.watchArticles().firstWhere(
      (items) => items.any((item) => item.id == id),
    );
    expect(feed.any((item) => item.title == 'Kompos 2'), isTrue);
  });

  test('wrong roles cannot create or moderate content', () async {
    final repo = FakeContentRepository();
    await expectLater(
      repo.createDraft(kind: 'event', title: 'A', body: 'B'),
      throwsStateError,
    );
    PreviewStore.role = 'pengolah';
    final id = await repo.createDraft(kind: 'event', title: 'A', body: 'B');
    await repo.submitDraft(id);
    PreviewStore.role = 'sumber';
    await expectLater(
      repo.moderateDraft(id, approve: true, reason: 'x'),
      throwsStateError,
    );
  });
}
