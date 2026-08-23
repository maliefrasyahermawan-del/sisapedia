import 'package:flutter_test/flutter_test.dart';
import 'package:sisapedia/data/models/submission_model.dart';
import 'package:sisapedia/data/repositories/content_repository.dart';
import 'package:sisapedia/data/repositories/submission_repository.dart';

void main() {
  test('normal submission RPC consumes direct UUID payload once', () async {
    var calls = 0;
    final repository = SubmissionRepository(
      rpcInvoker: (name, params) async {
        calls++;
        expect(name, 'create_submission');
        expect(params['p_precise_address'], 'Jl. Sampangan');
        expect(params['p_administrative_area'], 'Banyumanik');
        return 'submission-uuid';
      },
    );
    final id = await repository.create(
      const SubmissionModel(
        id: '',
        uid: 'source-uuid',
        kategori: WasteCategory.organik,
        subtipe: 'Sisa Sayur',
        beratKg: 2,
        district: 'Banyumanik',
        address: 'Jl. Sampangan',
      ),
    );
    expect(id, 'submission-uuid');
    expect(calls, 1);
  });

  test(
    'normal content RPC consumes direct UUID payload without retry',
    () async {
      var calls = 0;
      final repository = ContentRepository(
        rpcInvoker: (name, params) async {
          calls++;
          expect(name, 'create_content_draft');
          return 'content-uuid';
        },
      );
      expect(
        await repository.createDraft(kind: 'article', title: 'A', body: 'B'),
        'content-uuid',
      );
      expect(calls, 1);
    },
  );
}
