import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/article_model.dart';
import '../../data/models/movement_event_model.dart';
import '../../data/models/partner_actor_model.dart';
import '../../data/models/points_transaction_model.dart';
import '../../data/models/submission_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/points_repository.dart';
import '../../data/repositories/submission_repository.dart';
import '../providers/repository_providers.dart';
import '../services/groq_service.dart';

/// Whether this build should run entirely on in-memory sample data instead
/// of Firebase/Groq. Build with:
///   flutter build apk --release --dart-define=PREVIEW_MODE=true
/// Lets reviewers install an APK and see every screen populated without
/// first setting up a Firebase project or Groq API key.
const bool kPreviewMode = bool.fromEnvironment('PREVIEW_MODE');

const _previewUid = 'preview-uid';

DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));

final _fakeUser = UserModel(
  uid: _previewUid,
  name: 'Budi Santoso',
  email: 'budi@example.com',
  poinSirkular: 1240,
  levelTitle: 'Pejuang Kota Sirkular',
  createdAt: _daysAgo(120),
);

final _sampleSubmissions = <SubmissionModel>[
  SubmissionModel(
    id: 's1',
    uid: _previewUid,
    kategori: WasteCategory.organik,
    subtipe: 'Sampah Organik Dapur',
    beratKg: 2.4,
    partnerId: 'p1',
    partnerName: 'Bank Sampah Melati Bersih',
    status: SubmissionStatus.verified,
    createdAt: _daysAgo(1),
  ),
  SubmissionModel(
    id: 's2',
    uid: _previewUid,
    kategori: WasteCategory.anorganik,
    subtipe: 'Botol Plastik PET',
    beratKg: 1.1,
    partnerId: 'p3',
    partnerName: 'Pengepul Jaya',
    status: SubmissionStatus.pending,
    createdAt: _daysAgo(0),
  ),
  SubmissionModel(
    id: 's3',
    uid: _previewUid,
    kategori: WasteCategory.organik,
    subtipe: 'Sisa Sayur & Buah',
    beratKg: 3.2,
    partnerId: 'p1',
    partnerName: 'Bank Sampah Melati Bersih',
    status: SubmissionStatus.verified,
    createdAt: _daysAgo(9),
  ),
  SubmissionModel(
    id: 's4',
    uid: _previewUid,
    kategori: WasteCategory.anorganik,
    subtipe: 'Kardus & Kertas',
    beratKg: 1.8,
    partnerId: 'p3',
    partnerName: 'Pengepul Jaya',
    status: SubmissionStatus.verified,
    createdAt: _daysAgo(16),
  ),
  SubmissionModel(
    id: 's5',
    uid: _previewUid,
    kategori: WasteCategory.organik,
    subtipe: 'Ampas Kopi',
    beratKg: 0.8,
    status: SubmissionStatus.verified,
    createdAt: _daysAgo(35),
  ),
  SubmissionModel(
    id: 's6',
    uid: _previewUid,
    kategori: WasteCategory.anorganik,
    subtipe: 'Logam & Kaleng',
    beratKg: 1.4,
    status: SubmissionStatus.verified,
    createdAt: _daysAgo(48),
  ),
  SubmissionModel(
    id: 's7',
    uid: _previewUid,
    kategori: WasteCategory.organik,
    subtipe: 'Sisa Sayur & Buah',
    beratKg: 2.9,
    status: SubmissionStatus.verified,
    createdAt: _daysAgo(64),
  ),
  SubmissionModel(
    id: 's8',
    uid: _previewUid,
    kategori: WasteCategory.anorganik,
    subtipe: 'Botol Plastik PET',
    beratKg: 2.2,
    status: SubmissionStatus.verified,
    createdAt: _daysAgo(80),
  ),
  SubmissionModel(
    id: 's9',
    uid: _previewUid,
    kategori: WasteCategory.organik,
    subtipe: 'Sisa Makanan',
    beratKg: 1.6,
    status: SubmissionStatus.verified,
    createdAt: _daysAgo(101),
  ),
  SubmissionModel(
    id: 's10',
    uid: _previewUid,
    kategori: WasteCategory.anorganik,
    subtipe: 'Kardus & Kertas',
    beratKg: 1.0,
    status: SubmissionStatus.verified,
    createdAt: _daysAgo(118),
  ),
];

final _samplePartners = <PartnerActorModel>[
  const PartnerActorModel(
    id: 'p1',
    nama: 'Bank Sampah Melati Bersih',
    tipe: PartnerType.bankSampah,
    lat: -6.9932,
    lng: 110.4203,
    kapasitasTersedia: 120,
    kapasitasTotal: 150,
    kategoriDiterima: ['Organik', 'Kertas', 'Plastik'],
  ),
  const PartnerActorModel(
    id: 'p2',
    nama: 'Maggot BSF Barokah',
    tipe: PartnerType.maggotBsf,
    lat: -6.9851,
    lng: 110.4381,
    kapasitasTersedia: 80,
    kapasitasTotal: 100,
    kategoriDiterima: ['Organik'],
  ),
  const PartnerActorModel(
    id: 'p3',
    nama: 'Pengepul Jaya',
    tipe: PartnerType.pengepul,
    lat: -7.0051,
    lng: 110.4092,
    kapasitasTersedia: 200,
    kapasitasTotal: 300,
    kategoriDiterima: ['Plastik', 'Logam', 'Kertas'],
  ),
  const PartnerActorModel(
    id: 'p4',
    nama: 'Kompos Tandur Ijo',
    tipe: PartnerType.pengompos,
    lat: -6.9781,
    lng: 110.4489,
    kapasitasTersedia: 60,
    kapasitasTotal: 100,
    kategoriDiterima: ['Organik'],
  ),
];

final _sampleArticles = <ArticleModel>[
  const ArticleModel(
    id: 'a1',
    title: 'Sampah Plastik',
    summary:
        'Sampah plastik selalu jadi masalah utama pencemaran lingkungan yang butuh ratusan tahun untuk terurai...',
    readTimeMinutes: 5,
  ),
  const ArticleModel(
    id: 'a2',
    title: 'Food Waste & Food Loss',
    summary:
        'Tahukah kamu 1/3 dari makanan yang diproduksi berakhir jadi sampah? Yuk kurangi mulai dari dapur sendiri.',
    readTimeMinutes: 4,
  ),
  const ArticleModel(
    id: 'a3',
    title: '5 Cara Memilah Sampah Dapur',
    summary:
        'Memilah sampah dapur ternyata gampang kalau tahu caranya. Ini 5 langkah praktis buat mulai hari ini.',
    readTimeMinutes: 4,
  ),
];

final _sampleEvents = <MovementEventModel>[
  MovementEventModel(
    id: 'e1',
    title: 'Panen Maggot Bersama Warga',
    organizer: 'Bank Sampah Melati Bersih',
    date: DateTime.now().add(const Duration(days: 6)),
    location: 'Balai RW 04 Tembalang',
  ),
  MovementEventModel(
    id: 'e2',
    title: 'Sedekah Sampah RW 04',
    organizer: 'Maggot BSF Barokah',
    date: DateTime.now().add(const Duration(days: 12)),
    location: 'Balai RW 04',
  ),
];

final _samplePointsTransactions = <PointsTransactionModel>[
  PointsTransactionModel(
    id: 't1',
    uid: _previewUid,
    jenis: PointsTransactionType.earn,
    jumlah: 48,
    deskripsi: 'Sampah Organik Dapur · 2,4 kg',
    createdAt: _daysAgo(1),
  ),
  PointsTransactionModel(
    id: 't2',
    uid: _previewUid,
    jenis: PointsTransactionType.earn,
    jumlah: 36,
    deskripsi: 'Sisa Sayur & Buah · 3,2 kg',
    createdAt: _daysAgo(9),
  ),
  PointsTransactionModel(
    id: 't3',
    uid: _previewUid,
    jenis: PointsTransactionType.redeem,
    jumlah: 300,
    deskripsi: 'Voucher Kompos Organik',
    status: PointsTransactionStatus.pendingRedeem,
    createdAt: _daysAgo(20),
  ),
];

class FakeAuthRepository implements AuthRepositoryBase {
  @override
  Stream<String?> get uidChanges => Stream.value(_previewUid);

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Stream<UserModel?> watchProfile(String uid) => Stream.value(_fakeUser);

  @override
  Future<UserModel?> getProfile(String uid) async => _fakeUser;
}

class FakeSubmissionRepository implements SubmissionRepositoryBase {
  final List<SubmissionModel> _items = List.of(_sampleSubmissions);

  @override
  Future<void> create(SubmissionModel submission) async {
    _items.insert(
      0,
      SubmissionModel(
        id: 'local-${_items.length}',
        uid: submission.uid,
        kategori: submission.kategori,
        subtipe: submission.subtipe,
        beratKg: submission.beratKg,
        partnerId: submission.partnerId,
        partnerName: submission.partnerName,
        status: SubmissionStatus.pending,
        source: submission.source,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Stream<List<SubmissionModel>> watchUserSubmissions(String uid,
      {int limit = 20}) {
    return Stream.value(
      _items.where((s) => s.uid == uid).take(limit).toList(),
    );
  }

  @override
  Stream<List<SubmissionModel>> watchVerifiedSubmissions({String? uid}) {
    return Stream.value(_items
        .where((s) =>
            s.status == SubmissionStatus.verified &&
            (uid == null || s.uid == uid))
        .toList());
  }
}

class FakePointsRepository implements PointsRepositoryBase {
  final List<PointsTransactionModel> _items = List.of(_samplePointsTransactions);

  @override
  Stream<List<PointsTransactionModel>> watchUserTransactions(String uid,
      {int limit = 20}) {
    return Stream.value(
      _items.where((t) => t.uid == uid).take(limit).toList(),
    );
  }

  @override
  Future<void> requestRedeem({
    required String uid,
    required int jumlah,
    required String deskripsi,
  }) async {
    _items.insert(
      0,
      PointsTransactionModel(
        id: 'local-${_items.length}',
        uid: uid,
        jenis: PointsTransactionType.redeem,
        jumlah: jumlah,
        deskripsi: deskripsi,
        status: PointsTransactionStatus.pendingRedeem,
        createdAt: DateTime.now(),
      ),
    );
  }
}

class FakePartnerRepository implements PartnerRepositoryBase {
  @override
  Stream<List<PartnerActorModel>> watchPartners() =>
      Stream.value(_samplePartners);

  @override
  Future<void> requestMatch({
    required String partnerId,
    required String uid,
  }) async {}
}

class FakeContentRepository implements ContentRepositoryBase {
  @override
  Stream<List<ArticleModel>> watchArticles() => Stream.value(_sampleArticles);

  @override
  Stream<List<MovementEventModel>> watchMovementEvents() =>
      Stream.value(_sampleEvents);

  @override
  Future<void> joinEvent({required String eventId, required String uid}) async {}
}

class FakeGroqService extends GroqService {
  @override
  bool get isConfigured => true;

  @override
  Future<String> generateInsight(String dataSummary) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return 'Setoran organikmu naik dibanding bulan lalu, didorong oleh sisa sayur & buah. '
        'Coba setor ampas kopi juga, poin bonusnya sedang tinggi minggu ini.';
  }
}

/// Riverpod overrides that swap every Firebase/Groq-backed provider for the
/// fakes above. Applied to [ProviderScope] only when [kPreviewMode] is true.
final previewModeOverrides = <Override>[
  authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
  submissionRepositoryProvider.overrideWithValue(FakeSubmissionRepository()),
  pointsRepositoryProvider.overrideWithValue(FakePointsRepository()),
  partnerRepositoryProvider.overrideWithValue(FakePartnerRepository()),
  contentRepositoryProvider.overrideWithValue(FakeContentRepository()),
  groqServiceProvider.overrideWithValue(FakeGroqService()),
];
