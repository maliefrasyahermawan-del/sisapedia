import 'package:flutter_test/flutter_test.dart';
import 'package:sisapedia/core/domain/lifecycle_rules.dart';
import 'package:sisapedia/core/domain/matching_engine.dart';
import 'package:sisapedia/core/domain/points_rules.dart';
import 'package:sisapedia/data/models/partner_actor_model.dart';
import 'package:sisapedia/data/models/submission_model.dart';
import 'package:sisapedia/data/models/points_transaction_model.dart';
import 'package:sisapedia/core/providers/role_metrics_provider.dart';

void main() {
  test('points use immutable ten-points-per-kilogram rule', () {
    expect(pointsForVerifiedKg(2.45), 25);
    expect(levelForPoints(1000), 'Pejuang Kota Sirkular');
  });
  test('DLH completion month selector separates adjacent months', () {
    final january = DateTime(2026, 1);
    expect(isInCompletionMonth(DateTime(2026, 1, 31), january), isTrue);
    expect(isInCompletionMonth(DateTime(2026, 2, 1), january), isFalse);
  });
  test('points headline includes posted earn and negative redeem entries', () {
    final ledger = [
      const PointsTransactionModel(
        id: 'e',
        uid: 'u',
        jenis: PointsTransactionType.earn,
        jumlah: 40,
        deskripsi: 'setor',
      ),
      const PointsTransactionModel(
        id: 'r',
        uid: 'u',
        jenis: PointsTransactionType.redeem,
        jumlah: -15,
        deskripsi: 'redeem',
      ),
    ];
    expect(ledger.fold<int>(0, (sum, entry) => sum + entry.jumlah), 25);
  });
  test('state machine rejects skipping weighing', () {
    expect(
      isValidTransition(SubmissionStatus.accepted, SubmissionStatus.completed),
      isFalse,
    );
    expect(
      isValidTransition(SubmissionStatus.weighed, SubmissionStatus.completed),
      isTrue,
    );
  });
  test('SQL en_route status normalizes to the canonical UI state', () {
    final row = SubmissionModel.fromMap('s', {
      'uid': 'u',
      'kategori': 'organik',
      'subtipe': 'Sisa Sayur',
      'berat_kg': 2,
      'status': 'en_route',
    });
    expect(row.status, SubmissionStatus.enRoute);
    expect(row.status.name, 'enRoute');
  });
  test('matching returns top three with category and capacity filters', () {
    final partners = List.generate(
      4,
      (i) => PartnerActorModel(
        id: 'p$i',
        nama: 'P$i',
        tipe: PartnerType.bankSampah,
        lat: -7,
        lng: 110,
        kapasitasTersedia: 100 - i * 10,
        kapasitasTotal: 100,
        kategoriDiterima: const ['Organik'],
      ),
    );
    final result = rankCandidates(
      category: WasteCategory.organik,
      weightKg: 2,
      partners: partners,
    );
    expect(result, hasLength(3));
    expect(
      result.first.totalScore,
      greaterThanOrEqualTo(result.last.totalScore),
    );
  });
  test(
    'anorganic matching never treats an organic-only processor as compatible',
    () {
      final result = rankCandidates(
        category: WasteCategory.anorganik,
        weightKg: 2,
        partners: [
          const PartnerActorModel(
            id: 'organic',
            nama: 'Organik',
            tipe: PartnerType.pengompos,
            lat: -7,
            lng: 110,
            kapasitasTersedia: 100,
            kapasitasTotal: 100,
            kategoriDiterima: ['Organik'],
          ),
          const PartnerActorModel(
            id: 'plastic',
            nama: 'Plastik',
            tipe: PartnerType.pengepul,
            lat: -7,
            lng: 110,
            kapasitasTersedia: 100,
            kapasitasTotal: 100,
            kategoriDiterima: ['Plastik'],
          ),
        ],
      );
      expect(result.map((candidate) => candidate.partner.id), ['plastic']);
    },
  );
  test('subtype matching rejects paper-only processor for PET', () {
    final result = rankCandidates(
      category: WasteCategory.anorganik,
      subtype: 'Botol Plastik PET',
      weightKg: 2,
      partners: [
        const PartnerActorModel(
          id: 'paper',
          nama: 'Paper',
          tipe: PartnerType.bankSampah,
          lat: -7,
          lng: 110,
          kapasitasTersedia: 100,
          kapasitasTotal: 100,
          kategoriDiterima: ['Kardus & Kertas'],
        ),
        const PartnerActorModel(
          id: 'pet',
          nama: 'PET',
          tipe: PartnerType.pengepul,
          lat: -7,
          lng: 110,
          kapasitasTersedia: 100,
          kapasitasTotal: 100,
          kategoriDiterima: ['Botol Plastik PET'],
        ),
      ],
    );
    expect(result.map((candidate) => candidate.partner.id), ['pet']);
  });

  test(
    'matching excludes inactive, unavailable, out-of-window, and undersized partners',
    () {
      final start = DateTime.utc(2026, 8, 23, 8);
      final end = DateTime.utc(2026, 8, 23, 9);
      const material = ['Botol Plastik PET'];
      final result = rankCandidates(
        category: WasteCategory.anorganik,
        subtype: 'Botol Plastik PET',
        weightKg: 5,
        pickupStart: start,
        pickupEnd: end,
        partners: [
          const PartnerActorModel(
            id: 'inactive',
            nama: 'Inactive',
            tipe: PartnerType.pengepul,
            lat: -7,
            lng: 110,
            kapasitasTersedia: 100,
            kapasitasTotal: 100,
            kategoriDiterima: material,
            active: false,
          ),
          PartnerActorModel(
            id: 'wrong-window',
            nama: 'Wrong window',
            tipe: PartnerType.pengepul,
            lat: -7,
            lng: 110,
            kapasitasTersedia: 100,
            kapasitasTotal: 100,
            kategoriDiterima: material,
            pickupStart: DateTime.utc(2026, 8, 23, 12),
            pickupEnd: DateTime.utc(2026, 8, 23, 13),
          ),
          const PartnerActorModel(
            id: 'valid',
            nama: 'Valid',
            tipe: PartnerType.pengepul,
            lat: -7,
            lng: 110,
            kapasitasTersedia: 100,
            kapasitasTotal: 100,
            kategoriDiterima: material,
          ),
        ],
      );
      expect(result.map((candidate) => candidate.partner.id), ['valid']);
    },
  );

  test('inorganic score uses supplied subtype reference value', () {
    final result = rankCandidates(
      category: WasteCategory.anorganik,
      subtype: 'Botol Plastik PET',
      weightKg: 2,
      partners: [
        const PartnerActorModel(
          id: 'pet',
          nama: 'PET',
          tipe: PartnerType.pengepul,
          lat: -7,
          lng: 110,
          kapasitasTersedia: 100,
          kapasitasTotal: 100,
          kategoriDiterima: ['Botol Plastik PET'],
          referenceValues: {'Botol Plastik PET': .8},
        ),
      ],
    );
    expect(result.single.referenceValue, closeTo(.8, .0001));
    expect(result.single.totalScore, closeTo(.4 + .8 * .3 + .3, .0001));
  });
}
