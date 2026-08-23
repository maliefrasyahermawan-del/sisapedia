import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sisapedia/core/preview/fake_repositories.dart';
import 'package:sisapedia/core/preview/preview_store.dart';
import 'package:sisapedia/data/models/submission_model.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreviewStore.initialize();
  });

  test('organic offer completes only after en-route and evidence', () async {
    final repository = FakeSubmissionRepository();
    await repository.create(
      const SubmissionModel(
        id: 'new-organic',
        uid: 'preview-sumber',
        kategori: WasteCategory.organik,
        subtipe: 'Sisa dapur',
        beratKg: 2,
        district: 'Banyumanik',
        address: 'Pasar Sampangan',
      ),
    );
    final id = PreviewStore.submissions.first['id'].toString();
    await repository.selectCandidate(id, 'preview-pengolah');
    final offer = PreviewStore.offers
        .firstWhere((row) => row['submission_id'] == id)['id']
        .toString();
    PreviewStore.role = 'pengolah';
    final beforeCapacity =
        (PreviewStore.capacities.firstWhere(
                  (row) => row['processor_id'] == 'preview-pengolah',
                )['available_kg']
                as num)
            .toDouble();
    await repository.acceptOffer(offer);
    expect(
      (PreviewStore.capacities.firstWhere(
                (row) => row['processor_id'] == 'preview-pengolah',
              )['available_kg']
              as num)
          .toDouble(),
      lessThan(beforeCapacity),
    );
    await repository.setEnRoute(id);
    await repository.recordWeight(id, 2.2, 'preview://scale/$id.jpg');
    PreviewStore.role = 'sumber';
    await repository.confirmWeight(id);
    expect(PreviewStore.submissions.first['status'], 'completed');
    expect(
      (PreviewStore.capacities.firstWhere(
                (row) => row['processor_id'] == 'preview-pengolah',
              )['available_kg']
              as num)
          .toDouble(),
      closeTo(beforeCapacity, 0.001),
    );
    expect(
      PreviewStore.points.where(
        (row) => row['transaction_id'] == 'transaction-$id',
      ),
      hasLength(1),
    );
    await expectLater(repository.confirmWeight(id), throwsStateError);
    expect(
      PreviewStore.points.where(
        (row) => row['transaction_id'] == 'transaction-$id',
      ),
      hasLength(1),
    );
  });

  test(
    'creation returns an id and stores ranked candidates for that id',
    () async {
      final repository = FakeSubmissionRepository();
      final id = await repository.create(
        const SubmissionModel(
          id: 'ignored-by-server',
          uid: 'preview-sumber',
          kategori: WasteCategory.organik,
          subtipe: 'Sisa dapur',
          beratKg: 2,
        ),
      );
      expect(id, isNotEmpty);
      final candidates = PreviewStore.candidates
          .where((row) => row['submission_id'] == id)
          .toList();
      expect(candidates, hasLength(3));
      expect(candidates.map((row) => row['rank']), [1, 2, 3]);
    },
  );

  test('rejecting an offer falls back to the next ranked processor', () async {
    final repository = FakeSubmissionRepository();
    final id = await repository.create(
      const SubmissionModel(
        id: 'ignored',
        uid: 'preview-sumber',
        kategori: WasteCategory.anorganik,
        subtipe: 'Botol Plastik PET',
        beratKg: 1,
      ),
    );
    await repository.selectCandidate(id, 'preview-pengolah');
    final selectedRank = PreviewStore.candidates.firstWhere(
      (row) =>
          row['submission_id'] == id &&
          row['processor_id'] == 'preview-pengolah',
    )['rank'];
    final offer = PreviewStore.offers
        .firstWhere((row) => row['submission_id'] == id)['id']
        .toString();
    expect(
      PreviewStore.offers.firstWhere(
        (row) => row['id'] == offer,
      )['candidate_rank'],
      selectedRank,
    );
    PreviewStore.role = 'pengolah';
    await repository.rejectOffer(offer, 'Slot penuh');
    final next = PreviewStore.offers
        .where(
          (row) => row['submission_id'] == id && row['status'] == 'pending',
        )
        .toList();
    expect(next, hasLength(1));
    expect(next.single['processor_id'], 'preview-pengolah');
    expect(next.single['candidate_processor_id'], 'preview-pengolah-2');
    expect(next.single['candidate_rank'], greaterThan(selectedRank));
  });

  test(
    'inorganic flow rejects missing evidence and supports dispute',
    () async {
      final repository = FakeSubmissionRepository();
      await repository.create(
        const SubmissionModel(
          id: 'new-inorganic',
          uid: 'preview-sumber',
          kategori: WasteCategory.anorganik,
          subtipe: 'Botol Plastik PET',
          beratKg: 1.5,
        ),
      );
      final id = PreviewStore.submissions.first['id'].toString();
      await repository.selectCandidate(id, 'preview-pengolah');
      final offer = PreviewStore.offers
          .firstWhere((row) => row['submission_id'] == id)['id']
          .toString();
      PreviewStore.role = 'pengolah';
      await repository.acceptOffer(offer);
      await repository.setEnRoute(id);
      await expectLater(
        repository.recordWeight(id, 1.4, ''),
        throwsArgumentError,
      );
      await repository.recordWeight(id, 1.4, 'preview://scale/$id.jpg');
      PreviewStore.role = 'sumber';
      await repository.disputeWeight(id, 'Berat berbeda dari catatan sumber');
      expect(PreviewStore.submissions.first['status'], 'disputed');
      PreviewStore.role = 'admin';
      await repository.resolveDispute(
        id,
        approve: true,
        reason: 'Bukti sesuai',
      );
      expect(PreviewStore.submissions.first['status'], 'completed');
    },
  );

  test(
    'pending processor cannot self-approve through preview workflow',
    () async {
      PreviewStore.profiles.add({
        'id': 'pending-processor',
        'primary_role': 'pengolah',
        'processor_status': 'pending',
      });
      await PreviewStore.save();
      final row = PreviewStore.profiles.firstWhere(
        (profile) => profile['id'] == 'pending-processor',
      );
      expect(row['processor_status'], 'pending');
      await expectLater(
        FakePartnerRepository().reviewProcessor(
          'pending-processor',
          approve: true,
          reason: 'Unauthorized',
        ),
        throwsStateError,
      );
      PreviewStore.role = 'admin';
      await FakePartnerRepository().reviewProcessor(
        'pending-processor',
        approve: true,
        reason: 'Admin review',
      );
      expect(row['processor_status'], 'approved');
      expect(
        PreviewStore.audits.any(
          (audit) => audit['action'] == 'processor_review',
        ),
        isTrue,
      );
    },
  );

  test(
    'Preview actors cannot perform another role\'s lifecycle action',
    () async {
      final repository = FakeSubmissionRepository();
      final id = await repository.create(
        const SubmissionModel(
          id: 'auth-check',
          uid: 'preview-sumber',
          kategori: WasteCategory.organik,
          subtipe: 'Sisa dapur',
          beratKg: 1,
        ),
      );
      PreviewStore.role = 'pengolah';
      await expectLater(
        repository.cancelSubmission(id, 'Tidak jadi'),
        throwsStateError,
      );
      await expectLater(repository.confirmWeight(id), throwsStateError);
    },
  );

  test(
    'offer reasons, cancellation, capacity and notifications are enforced',
    () async {
      final repository = FakeSubmissionRepository();
      final id = await repository.create(
        const SubmissionModel(
          id: 'cancel-check',
          uid: 'preview-sumber',
          kategori: WasteCategory.organik,
          subtipe: 'Sisa dapur',
          beratKg: 2,
        ),
      );
      await repository.selectCandidate(id, 'preview-pengolah');
      final offer = PreviewStore.offers.firstWhere(
        (row) => row['submission_id'] == id,
      );
      PreviewStore.role = 'pengolah';
      await expectLater(
        repository.rejectOffer(offer['id'].toString(), ''),
        throwsArgumentError,
      );
      final before =
          (PreviewStore.capacities.firstWhere(
                    (row) => row['processor_id'] == 'preview-pengolah',
                  )['available_kg']
                  as num)
              .toDouble();
      await repository.acceptOffer(offer['id'].toString());
      final reserved =
          (PreviewStore.capacities.firstWhere(
                    (row) => row['processor_id'] == 'preview-pengolah',
                  )['available_kg']
                  as num)
              .toDouble();
      expect(reserved, lessThan(before));
      PreviewStore.role = 'sumber';
      await expectLater(
        repository.cancelSubmission(id, ''),
        throwsArgumentError,
      );
      await repository.cancelSubmission(id, 'Jadwal berubah');
      expect(PreviewStore.submissions.first['status'], 'cancelled');
      final after =
          (PreviewStore.capacities.firstWhere(
                    (row) => row['processor_id'] == 'preview-pengolah',
                  )['available_kg']
                  as num)
              .toDouble();
      expect(after, closeTo(before, .001));
      expect(
        PreviewStore.notifications.any(
          (row) => row['title'] == 'Pickup dibatalkan',
        ),
        isTrue,
      );
    },
  );

  test(
    'pre-acceptance cancellation uses a deterministic default reason',
    () async {
      final repository = FakeSubmissionRepository();
      final id = await repository.create(
        const SubmissionModel(
          id: 'preaccept-cancel',
          uid: 'preview-sumber',
          kategori: WasteCategory.anorganik,
          subtipe: 'Botol Plastik PET',
          beratKg: 1,
        ),
      );
      await repository.cancelSubmission(id, '');
      final row = PreviewStore.submissions.firstWhere(
        (item) => item['id'] == id,
      );
      expect(row['status'], 'cancelled');
      expect(row['cancellation_reason'], 'Dibatalkan sebelum pickup');
    },
  );
}
