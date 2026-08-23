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
import '../services/sari_gateway_service.dart';
import '../domain/lifecycle_rules.dart';
import '../domain/matching_engine.dart';
import 'preview_store.dart';

/// In-memory fake repositories backed by sample data, shared by both the
/// compile-time preview build (see [kPreviewMode] in preview_mode.dart) and
/// the runtime "Masuk sebagai Akun Testing" demo login.
const _previewUid = 'preview-sumber';

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
  // Submissions from other warga across Kota Semarang, so the "Kota
  // Semarang" dashboard scope (all verified submissions) reads visibly
  // larger and trends differently than the "Saya" scope (previewUid only).
  ...List.generate(42, (i) {
    final isOrganik = i % 3 != 0;
    final daysBack = (i * 4) % 175;
    return SubmissionModel(
      id: 'city-$i',
      uid: 'warga-${i % 9}',
      kategori: isOrganik ? WasteCategory.organik : WasteCategory.anorganik,
      subtipe: isOrganik
          ? const [
              'Sisa Sayur & Buah',
              'Sampah Organik Dapur',
              'Ampas Kopi',
              'Sisa Makanan',
            ][i % 4]
          : const ['Botol Plastik PET', 'Kardus & Kertas', 'Logam & Kaleng'][i %
                3],
      beratKg: 1.5 + (i % 6) * 0.9,
      partnerId: isOrganik ? 'p1' : 'p3',
      partnerName: isOrganik ? 'Bank Sampah Melati Bersih' : 'Pengepul Jaya',
      status: SubmissionStatus.verified,
      createdAt: _daysAgo(daysBack),
    );
  }),
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
    kategoriDiterima: [
      'Sisa Sayur & Buah',
      'Sampah Organik Dapur',
      'Ampas Kopi',
      'Sisa Makanan',
      'Kardus & Kertas',
      'Botol Plastik PET',
    ],
    kecamatan: 'Tembalang',
    alamat: 'Jl. Sirojudin No. 8, Tembalang',
  ),
  const PartnerActorModel(
    id: 'p2',
    nama: 'Maggot BSF Barokah',
    tipe: PartnerType.maggotBsf,
    lat: -6.9851,
    lng: 110.4381,
    kapasitasTersedia: 80,
    kapasitasTotal: 100,
    kategoriDiterima: [
      'Sisa Sayur & Buah',
      'Sampah Organik Dapur',
      'Ampas Kopi',
      'Sisa Makanan',
    ],
    kecamatan: 'Tembalang',
    alamat: 'Jl. Ngresep Timur V, Tembalang',
  ),
  const PartnerActorModel(
    id: 'p3',
    nama: 'Pengepul Jaya',
    tipe: PartnerType.pengepul,
    lat: -7.0051,
    lng: 110.4092,
    kapasitasTersedia: 200,
    kapasitasTotal: 300,
    kategoriDiterima: [
      'Botol Plastik PET',
      'Logam & Kaleng',
      'Kardus & Kertas',
    ],
    kecamatan: 'Semarang Selatan',
    alamat: 'Jl. MT Haryono No. 45, Semarang Selatan',
  ),
  const PartnerActorModel(
    id: 'p4',
    nama: 'Kompos Tandur Ijo',
    tipe: PartnerType.pengompos,
    lat: -6.9781,
    lng: 110.4489,
    kapasitasTersedia: 60,
    kapasitasTotal: 100,
    kategoriDiterima: ['Sisa Sayur & Buah', 'Sisa Makanan', 'Ampas Kopi'],
    kecamatan: 'Semarang Tengah',
    alamat: 'Jl. Pandanaran No. 12, Semarang Tengah',
  ),
  const PartnerActorModel(
    id: 'p5',
    nama: 'Bank Sampah Sejahtera',
    tipe: PartnerType.bankSampah,
    lat: -6.9847,
    lng: 110.4108,
    kapasitasTersedia: 90,
    kapasitasTotal: 120,
    kategoriDiterima: ['Sampah Organik Dapur', 'Botol Plastik PET'],
    kecamatan: 'Semarang Tengah',
    alamat: 'Jl. Gajahmada No. 21, Semarang Tengah',
  ),
  const PartnerActorModel(
    id: 'p6',
    nama: 'Pengepul Makmur Logam',
    tipe: PartnerType.pengepul,
    lat: -7.0102,
    lng: 110.4210,
    kapasitasTersedia: 150,
    kapasitasTotal: 250,
    kategoriDiterima: ['Logam & Kaleng', 'Botol Plastik PET'],
    kecamatan: 'Semarang Selatan',
    alamat: 'Jl. Sompok Baru No. 6, Semarang Selatan',
  ),
];

final _sampleArticles = <ArticleModel>[
  const ArticleModel(
    id: 'a1',
    title: 'Sampah Plastik',
    summary:
        'Sampah plastik selalu jadi masalah utama pencemaran lingkungan yang butuh ratusan tahun untuk terurai...',
    readTimeMinutes: 5,
    content:
        'Sampah plastik selalu jadi masalah utama pencemaran lingkungan yang butuh ratusan tahun untuk terurai. '
        'Sebagian besar kemasan sekali pakai, seperti kantong belanja, sedotan, dan botol minuman, hanya '
        'dipakai dalam hitungan menit namun tetap ada di lingkungan selama puluhan bahkan ratusan tahun setelahnya.\n\n'
        'Di Indonesia, plastik menyumbang lebih dari seperlima total timbulan sampah nasional. Ketika tidak '
        'dipilah dari sumbernya, plastik bercampur dengan sampah organik dan berakhir di TPA, atau lebih buruk '
        'lagi mencemari sungai dan laut. Padahal jenis seperti botol PET, kemasan HDPE, dan kardus punya nilai '
        'jual dan bisa didaur ulang berulang kali kalau dipilah dalam kondisi bersih dan kering.\n\n'
        'Langkah paling sederhana yang bisa kamu mulai hari ini: pisahkan plastik bersih dari sampah dapur '
        'sejak di rumah, bilas kemasan bekas makanan sebelum disetor, dan gunakan menu Setor Anorganik di '
        'SisaPedia supaya plastikmu langsung tersambung ke pengepul atau industri daur ulang terdekat, bukan '
        'berakhir tercampur di TPA.',
  ),
  const ArticleModel(
    id: 'a2',
    title: 'Food Waste & Food Loss',
    summary:
        'Tahukah kamu 1/3 dari makanan yang diproduksi berakhir jadi sampah? Yuk kurangi mulai dari dapur sendiri.',
    readTimeMinutes: 4,
    content:
        'Tahukah kamu sekitar sepertiga dari seluruh makanan yang diproduksi di dunia berakhir jadi sampah '
        'sebelum sempat dimakan? Ada dua istilah yang sering tertukar: food loss, makanan yang hilang di '
        'rantai produksi dan distribusi sebelum sampai ke konsumen, dan food waste, makanan layak yang '
        'akhirnya dibuang di tingkat rumah tangga, restoran, atau ritel.\n\n'
        'Rumah tangga adalah penyumbang terbesar food waste di banyak kota, termasuk di Indonesia. Sisa nasi, '
        'sayur yang layu, dan buah yang terlanjur busuk sebelum dimasak semuanya masuk kategori ini. Ketika '
        'dibuang begitu saja ke TPA, sisa makanan ini membusuk tanpa oksigen dan menghasilkan gas metana, '
        'salah satu gas rumah kaca yang jauh lebih kuat dampaknya dibanding karbon dioksida.\n\n'
        'Cara paling mudah menguranginya mulai dari dapur sendiri, rencanakan belanja sesuai kebutuhan, '
        'simpan sisa makanan dengan benar, dan olah sisa sayur/buah yang masih layak jadi kompos atau pakan '
        'maggot BSF lewat menu Setor Organik. Setiap kilogram yang kamu setor lewat SisaPedia langsung '
        'dihitung sebagai sampah yang berhasil dialihkan dari TPA di dasbor dampakmu.',
  ),
  const ArticleModel(
    id: 'a3',
    title: '5 Cara Memilah Sampah Dapur',
    summary:
        'Memilah sampah dapur ternyata gampang kalau tahu caranya. Ini 5 langkah praktis buat mulai hari ini.',
    readTimeMinutes: 4,
    content:
        'Memilah sampah dapur ternyata gampang kalau tahu caranya. Berikut 5 langkah praktis buat mulai hari ini.\n\n'
        '1. Siapkan dua wadah terpisah di dapur, satu untuk sisa organik (sayur, buah, ampas kopi, nasi), '
        'satu lagi untuk anorganik bersih (plastik, kertas, logam).\n\n'
        '2. Bilas kemasan plastik dan kaleng sebelum dibuang ke wadah anorganik, sisa makanan yang menempel '
        'membuat plastik sulit didaur ulang dan mengundang bau.\n\n'
        '3. Jangan campur minyak jelantah dengan sampah dapur biasa, kumpulkan terpisah di botol bekas '
        'karena minyak butuh jalur pengolahan sendiri.\n\n'
        '4. Padatkan volume kardus dan kemasan sebelum disetor supaya lebih ringkas dibawa dan lebih mudah '
        'ditimbang oleh mitra pengepul.\n\n'
        '5. Setor rutin lewat SisaPedia, baik manual maupun lewat Setor Cerdas dengan asisten Sari yang '
        'tinggal kamu ajak bicara. Konsistensi memilah setiap hari jauh lebih berdampak daripada sekali '
        'besar tapi jarang.',
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
  String? _otpPhone;
  @override
  Stream<String?> get uidChanges => Stream.value(_previewUid);

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String role = 'sumber',
  }) async {
    PreviewStore.role = role == 'pengolah' ? 'pengolah' : 'sumber';
    await PreviewStore.save();
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPhoneOtp(String phone) async {
    _otpPhone = phone;
  }

  @override
  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    if (_otpPhone != phone || token != '246810') {
      throw StateError('Kode OTP Preview tidak valid. Gunakan 246810.');
    }
  }

  @override
  Future<void> linkPhone(String phone) async {
    if (phone.trim().isEmpty) {
      throw const FormatException('Nomor telepon wajib diisi.');
    }
    _otpPhone = phone;
  }

  @override
  Future<void> verifyLinkedPhoneOtp({
    required String phone,
    required String token,
  }) => verifyPhoneOtp(phone: phone, token: token);

  @override
  Stream<UserModel?> watchProfile(String uid) =>
      Stream.value(_fakeUser.copyWith(primaryRole: PreviewStore.role));

  @override
  Future<UserModel?> getProfile(String uid) async =>
      _fakeUser.copyWith(primaryRole: PreviewStore.role);
}

class FakeSubmissionRepository implements SubmissionRepositoryBase {
  FakeSubmissionRepository() {
    if (PreviewStore.submissions.isEmpty) {
      PreviewStore.submissions = _sampleSubmissions
          .map((e) => e.toMap()..['id'] = e.id)
          .toList();
    }
    _items = PreviewStore.submissions
        .map((e) => SubmissionModel.fromMap(e['id']?.toString() ?? '', e))
        .toList();
  }
  late List<SubmissionModel> _items;

  void _requireRole(String role) {
    if (PreviewStore.role != role) {
      throw StateError('Aksi ini hanya tersedia untuk peran $role.');
    }
  }

  List<SubmissionModel> get _currentItems => PreviewStore.submissions
      .map((e) => SubmissionModel.fromMap(e['id']?.toString() ?? '', e))
      .toList();

  @override
  Future<String> create(SubmissionModel submission) async {
    _requireRole('sumber');
    _items = _currentItems;
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
        status: SubmissionStatus.submitted,
        source: submission.source,
        createdAt: DateTime.now(),
        district: submission.district,
        address: submission.address,
        pickupStart: submission.pickupStart,
        pickupEnd: submission.pickupEnd,
        sourcePhotoPath: submission.sourcePhotoPath,
        latitude: submission.latitude,
        longitude: submission.longitude,
      ),
    );
    PreviewStore.submissions = _items
        .map((e) => e.toMap()..['id'] = e.id)
        .toList();
    final id = _items.first.id;
    final row = PreviewStore.submissions.firstWhere((item) => item['id'] == id);
    final capacity = PreviewStore.capacities.firstWhere(
      (item) => item['processor_id'] == 'preview-pengolah',
      orElse: () => const <String, dynamic>{
        'total_kg': 150,
        'available_kg': 150,
      },
    );
    final previewProcessor = PartnerActorModel(
      id: 'preview-pengolah',
      nama: 'Bank Sampahku Berkahmu',
      tipe: PartnerType.bankSampah,
      lat: -7.02,
      lng: 110.41,
      kapasitasTersedia: (capacity['available_kg'] as num?)?.toDouble() ?? 0,
      kapasitasTotal: (capacity['total_kg'] as num?)?.toDouble() ?? 0,
      kategoriDiterima: [row['subtipe']?.toString() ?? ''],
    );
    final fallbackProcessors = List.generate(
      2,
      (index) => PartnerActorModel(
        id: 'preview-pengolah-${index + 2}',
        nama: 'Mitra fallback ${index + 2}',
        tipe: PartnerType.bankSampah,
        lat: -7.02 + (index + 1) * .01,
        lng: 110.41,
        kapasitasTersedia:
            previewProcessor.kapasitasTersedia - (index + 1) * 10,
        kapasitasTotal: previewProcessor.kapasitasTotal,
        kategoriDiterima: previewProcessor.kategoriDiterima,
      ),
    );
    for (final processor in fallbackProcessors) {
      if (!PreviewStore.capacities.any(
        (item) => item['processor_id'] == processor.id,
      )) {
        PreviewStore.capacities.add({
          'processor_id': processor.id,
          'total_kg': processor.kapasitasTotal,
          'available_kg': processor.kapasitasTersedia,
          'reserved_kg': 0.0,
        });
      }
    }
    final ranked = rankCandidates(
      category: WasteCategoryX.fromString(row['kategori']?.toString() ?? ''),
      subtype: row['subtipe']?.toString(),
      weightKg: (row['berat_kg'] as num?)?.toDouble() ?? 0,
      sourceLat: (row['latitude'] as num?)?.toDouble(),
      sourceLng: (row['longitude'] as num?)?.toDouble(),
      pickupStart: DateTime.tryParse(row['pickup_start']?.toString() ?? ''),
      pickupEnd: DateTime.tryParse(row['pickup_end']?.toString() ?? ''),
      partners: [previewProcessor, ...fallbackProcessors, ..._samplePartners],
    );
    for (var index = 0; index < ranked.length; index++) {
      final candidate = ranked[index];
      final rank = index + 1;
      PreviewStore.candidates.add({
        'id': 'candidate-$id-$rank',
        'submission_id': id,
        'processor_id': candidate.partner.id,
        'rank': rank,
        'compatibility_score': candidate.compatibility,
        'distance_score': candidate.distance,
        'capacity_score': candidate.capacity,
        'reference_value_score': candidate.referenceValue,
        'minimum_volume_score': candidate.minimumVolume,
        'total_score': candidate.totalScore,
        'approximate_distance_km': null,
        'processor_name': candidate.partner.nama,
        'available_capacity_kg': candidate.partner.kapasitasTersedia,
        'total_capacity_kg': candidate.partner.kapasitasTotal,
        'minimum_pickup_kg': candidate.partner.minimumPickupKg,
        'pickup_available': candidate.partner.pickupAvailable,
      });
    }
    await PreviewStore.save();
    return id;
  }

  @override
  Stream<List<SubmissionModel>> watchUserSubmissions(
    String uid, {
    int limit = 20,
  }) {
    return Stream.multi((controller) {
      void emit() => controller.add(
        _currentItems.where((s) => s.uid == uid).take(limit).toList(),
      );
      emit();
      final subscription = PreviewStore.changes.listen((_) => emit());
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<List<SubmissionModel>> watchVerifiedSubmissions({String? uid}) {
    return Stream.multi((controller) {
      void emit() => controller.add(
        _currentItems
            .where(
              (s) =>
                  (s.status == SubmissionStatus.verified ||
                      s.status == SubmissionStatus.completed) &&
                  (uid == null || s.uid == uid),
            )
            .toList(),
      );
      emit();
      final subscription = PreviewStore.changes.listen((_) => emit());
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> advance(
    String id,
    SubmissionStatus status, {
    String? reason,
    double? actualWeight,
  }) async {
    _items = _currentItems;
    final index = _items.indexWhere((e) => e.id == id);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(
      status: status,
      beratKg: actualWeight,
    );
    PreviewStore.submissions = _items
        .map((e) => e.toMap()..['id'] = e.id)
        .toList();
    await PreviewStore.save();
  }

  Map<String, dynamic>? _submission(String id) {
    final rows = PreviewStore.submissions.where(
      (row) => row['id']?.toString() == id,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _setStatus(String id, String status, {double? weight}) async {
    final row = _submission(id);
    if (row == null) throw StateError('Setoran tidak ditemukan');
    final current = SubmissionStatusX.fromString(
      row['status']?.toString() ?? 'submitted',
    );
    final next = SubmissionStatusX.fromString(status);
    if (!isValidTransition(current, next)) {
      throw StateError('Transisi ${current.name} ke ${next.name} tidak valid');
    }
    row['status'] = status;
    if (weight != null) row['berat_kg'] = weight;
    PreviewStore.audits.add({
      'id': 'audit-${DateTime.now().microsecondsSinceEpoch}',
      'actor_id': _previewUid,
      'action': 'transition',
      'entity_type': 'submission',
      'entity_id': id,
      'metadata': {'from': current.name, 'to': status},
    });
    await PreviewStore.save();
  }

  @override
  Future<void> selectCandidate(String submissionId, String processorId) async {
    _requireRole('sumber');
    final row = _submission(submissionId);
    if (row == null) throw StateError('Setoran tidak ditemukan');
    row['partner_id'] = processorId;
    row['partner_name'] = processorId == 'preview-pengolah'
        ? 'Bank Sampahku Berkahmu'
        : _samplePartners
              .firstWhere(
                (partner) => partner.id == processorId,
                orElse: () => _samplePartners.first,
              )
              .nama;
    if (row['status'] == 'submitted') row['status'] = 'matching';
    final candidate = PreviewStore.candidates.firstWhere(
      (item) =>
          item['submission_id'] == submissionId &&
          item['processor_id'] == processorId,
      orElse: () => throw StateError('Kandidat tidak tersedia'),
    );
    PreviewStore.offers.removeWhere(
      (offer) => offer['submission_id'] == submissionId,
    );
    final visibleProcessorId = processorId.startsWith('preview-pengolah-')
        ? 'preview-pengolah'
        : processorId;
    row['partner_id'] = visibleProcessorId;
    row['partner_name'] = visibleProcessorId == 'preview-pengolah'
        ? 'Bank Sampahku Berkahmu'
        : row['partner_name'];
    PreviewStore.offers.add({
      'id': 'offer-$submissionId-$processorId',
      'submission_id': submissionId,
      'processor_id': visibleProcessorId,
      'candidate_processor_id': processorId,
      'candidate_rank': candidate['rank'],
      'status': 'pending',
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 20))
          .toIso8601String(),
    });
    row['status'] = 'offered';
    await PreviewStore.save();
  }

  Map<String, dynamic> _offer(String id) {
    final matches = PreviewStore.offers.where(
      (offer) => offer['id']?.toString() == id,
    );
    if (matches.isEmpty) throw StateError('Tawaran tidak ditemukan');
    return matches.first;
  }

  Map<String, dynamic> _capacity(String processorId) {
    final rows = PreviewStore.capacities.where(
      (row) => row['processor_id'] == processorId,
    );
    if (rows.isEmpty) throw StateError('Kapasitas pengolah tidak ditemukan');
    return rows.first;
  }

  void _reserveCapacity(String processorId, double weight) {
    final capacity = _capacity(processorId);
    final available = (capacity['available_kg'] as num?)?.toDouble() ?? 0;
    if (available < weight) throw StateError('Kapasitas tidak mencukupi');
    capacity['available_kg'] = available - weight;
    capacity['reserved_kg'] =
        ((capacity['reserved_kg'] as num?)?.toDouble() ?? 0) + weight;
  }

  void _releaseCapacity(Map<String, dynamic> row) {
    if (row['capacity_released_at'] != null) return;
    final processorId = row['partner_id']?.toString();
    if (processorId == null || processorId.isEmpty) return;
    final capacity = _capacity(processorId);
    final weight = (row['capacity_reserved_kg'] as num?)?.toDouble() ?? 0;
    final total = (capacity['total_kg'] as num?)?.toDouble() ?? 0;
    final available = (capacity['available_kg'] as num?)?.toDouble() ?? 0;
    capacity['available_kg'] = (available + weight).clamp(0, total);
    capacity['reserved_kg'] =
        ((capacity['reserved_kg'] as num?)?.toDouble() ?? 0) - weight;
    row['capacity_released_at'] = DateTime.now().toUtc().toIso8601String();
  }

  @override
  Future<void> acceptOffer(String offerId) async {
    _requireRole('pengolah');
    final offer = _offer(offerId);
    if (offer['status'] != 'pending') {
      throw StateError('Tawaran sudah diproses');
    }
    final expiresAt = DateTime.tryParse(offer['expires_at']?.toString() ?? '');
    if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
      return rejectOffer(offerId, 'Tawaran kedaluwarsa');
    }
    final row = _submission(offer['submission_id'].toString());
    if (row == null) throw StateError('Setoran tidak ditemukan');
    final weight = (row['berat_kg'] as num?)?.toDouble() ?? 0;
    _reserveCapacity(offer['processor_id'].toString(), weight);
    row['capacity_reserved_kg'] = weight;
    row['capacity_released_at'] = null;
    offer['status'] = 'accepted';
    await _setStatus(row['id'].toString(), 'accepted');
  }

  @override
  Future<void> rejectOffer(String offerId, String reason) async {
    _requireRole('pengolah');
    if (reason.trim().isEmpty) {
      throw ArgumentError('Alasan penolakan wajib diisi');
    }
    final offer = _offer(offerId);
    if (offer['status'] != 'pending') {
      throw StateError('Tawaran sudah diproses');
    }
    offer['status'] = 'rejected';
    offer['rejection_reason'] = reason.trim();
    final row = _submission(offer['submission_id'].toString());
    if (row != null) {
      final next = PreviewStore.candidates.where(
        (candidate) =>
            candidate['submission_id'] == row['id'] &&
            (candidate['rank'] as num? ?? 0) >
                (offer['candidate_rank'] as num? ?? 0),
      );
      if (next.isNotEmpty) {
        final candidate = next.first;
        final candidateProcessorId = candidate['processor_id'].toString();
        final visibleProcessorId =
            candidateProcessorId.startsWith('preview-pengolah-')
            ? 'preview-pengolah'
            : candidateProcessorId;
        row['partner_id'] = visibleProcessorId;
        row['partner_name'] = visibleProcessorId == 'preview-pengolah'
            ? 'Bank Sampahku Berkahmu'
            : 'Mitra fallback ${candidate['rank']}';
        row['status'] = 'offered';
        PreviewStore.offers.add({
          'id': 'offer-${row['id']}-$candidateProcessorId',
          'submission_id': row['id'],
          'processor_id': visibleProcessorId,
          'candidate_processor_id': candidateProcessorId,
          'candidate_rank': candidate['rank'],
          'status': 'pending',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 20))
              .toIso8601String(),
        });
        PreviewStore.notifications.add({
          'id': 'notification-fallback-${row['id']}',
          'uid': row['uid'],
          'title': 'Kandidat fallback aktif',
          'body': 'Tawaran diteruskan ke kandidat berikutnya.',
          'kind': 'offer',
          'read': false,
        });
      } else {
        row['status'] = 'rejected';
        _releaseCapacity(row);
        PreviewStore.notifications.add({
          'id': 'notification-rejected-${row['id']}',
          'uid': row['uid'],
          'title': 'Tawaran ditolak',
          'body': 'Semua kandidat telah menolak tawaran.',
          'kind': 'offer',
          'read': false,
        });
      }
      PreviewStore.notifications.add({
        'id': 'notification-reject-source-${offer['id']}',
        'uid': row['uid'],
        'title': 'Tawaran ditolak',
        'body': 'Pengolah menolak tawaran: ${reason.trim()}',
        'kind': 'offer',
        'read': false,
      });
    }
    await PreviewStore.save();
  }

  @override
  Future<void> simulateOfferExpiry(String offerId) async {
    final offer = _offer(offerId);
    offer['expires_at'] = DateTime.now()
        .toUtc()
        .subtract(const Duration(seconds: 1))
        .toIso8601String();
    await rejectOffer(offerId, 'Simulasi waktu habis');
  }

  @override
  Future<void> setEnRoute(String submissionId) async {
    _requireRole('pengolah');
    await _setStatus(submissionId, 'enRoute');
  }

  @override
  Future<void> cancelSubmission(String submissionId, String reason) async {
    _requireRole('sumber');
    final row = _submission(submissionId);
    if (row == null) throw StateError('Setoran tidak ditemukan');
    final currentStatus = row['status']?.toString();
    if (currentStatus == 'accepted' && reason.trim().isEmpty) {
      throw ArgumentError('Alasan pembatalan wajib diisi');
    }
    if (![
      'submitted',
      'matching',
      'offered',
      'accepted',
    ].contains(row['status'])) {
      throw StateError('Setoran tidak dapat dibatalkan pada status ini');
    }
    final cancellationReason = reason.trim().isEmpty
        ? 'Dibatalkan sebelum pickup'
        : reason.trim();
    row['status'] = 'cancelled';
    row['cancellation_reason'] = cancellationReason;
    _releaseCapacity(row);
    PreviewStore.notifications.add({
      'id': 'notification-cancel-${row['id']}',
      'uid': row['uid'],
      'title': 'Setoran dibatalkan',
      'body': 'Setoran dibatalkan: $cancellationReason',
      'kind': 'pickup',
      'read': false,
    });
    if (row['partner_id'] != null && currentStatus == 'accepted') {
      PreviewStore.notifications.add({
        'id': 'notification-cancel-partner-${row['id']}',
        'uid': row['partner_id'],
        'title': 'Pickup dibatalkan',
        'body': cancellationReason,
        'kind': 'pickup',
        'read': false,
      });
    }
    await PreviewStore.save();
  }

  @override
  Future<void> recordWeight(
    String submissionId,
    double actualWeightKg,
    String evidencePath,
  ) async {
    _requireRole('pengolah');
    if (actualWeightKg <= 0 || evidencePath.trim().isEmpty) {
      throw ArgumentError('Berat dan bukti timbang wajib diisi');
    }
    final row = _submission(submissionId);
    if (row == null) throw StateError('Setoran tidak ditemukan');
    row['evidence_path'] = evidencePath;
    await _setStatus(submissionId, 'weighed', weight: actualWeightKg);
  }

  @override
  Future<void> confirmWeight(String submissionId) async {
    _requireRole('sumber');
    await _setStatus(submissionId, 'completed');
    final row = _submission(submissionId)!;
    _releaseCapacity(row);
    final transactionId = 'transaction-$submissionId';
    if (!PreviewStore.transactions.any(
      (tx) => tx['submission_id'] == submissionId,
    )) {
      PreviewStore.transactions.add({
        'id': transactionId,
        'submission_id': submissionId,
        'processor_id': row['partner_id'],
        'actual_weight_kg': row['berat_kg'],
        'evidence_path': row['evidence_path'],
        'formula_version': PreviewStore.formula['version'],
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      });
      final points = ((row['berat_kg'] as num?)?.toDouble() ?? 0) * 10;
      PreviewStore.points.add({
        'id': 'ledger-$submissionId',
        'uid': row['uid'],
        'entry_type': 'earn',
        'jumlah': points.round(),
        'points': points.round(),
        'deskripsi': 'Setoran terverifikasi · ${row['berat_kg']} kg',
        'status': 'posted',
        'transaction_id': transactionId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    await PreviewStore.save();
  }

  @override
  Future<void> disputeWeight(String submissionId, String reason) async {
    _requireRole('sumber');
    final row = _submission(submissionId);
    if (row == null) throw StateError('Setoran tidak ditemukan');
    row['dispute_reason'] = reason;
    await _setStatus(submissionId, 'disputed');
  }

  @override
  Future<void> resolveDispute(
    String submissionId, {
    required bool approve,
    required String reason,
    double? correctedWeightKg,
  }) async {
    if (PreviewStore.role != 'admin') {
      throw StateError('Hanya Admin yang dapat menyelesaikan sengketa');
    }
    if (!PreviewStore.audits.any(
      (audit) =>
          audit['entity_id'] == submissionId &&
          audit['action'] == 'dispute_resolution',
    )) {
      PreviewStore.audits.add({
        'id': 'audit-dispute-${DateTime.now().microsecondsSinceEpoch}',
        'actor_id': 'preview-admin',
        'action': 'dispute_resolution',
        'entity_type': 'submission',
        'entity_id': submissionId,
        'metadata': {'approve': approve, 'reason': reason},
      });
    }
    if (approve) {
      if (correctedWeightKg != null) {
        final row = _submission(submissionId);
        if (row != null) row['berat_kg'] = correctedWeightKg;
      }
      final roleBeforeCompletion = PreviewStore.role;
      PreviewStore.role = 'sumber';
      await confirmWeight(submissionId);
      PreviewStore.role = roleBeforeCompletion;
    } else {
      await _setStatus(submissionId, 'cancelled');
      final row = _submission(submissionId);
      if (row != null) _releaseCapacity(row);
    }
  }
}

class FakePointsRepository implements PointsRepositoryBase {
  FakePointsRepository() {
    if (PreviewStore.points.isEmpty) {
      PreviewStore.points = _samplePointsTransactions
          .map((e) => e.toMap()..['id'] = e.id)
          .toList();
    }
    _items = PreviewStore.points
        .map(
          (e) => PointsTransactionModel.fromMap(e['id']?.toString() ?? '', e),
        )
        .toList();
  }
  late List<PointsTransactionModel> _items;

  List<PointsTransactionModel> get _currentItems => PreviewStore.points
      .map((e) => PointsTransactionModel.fromMap(e['id']?.toString() ?? '', e))
      .toList();

  @override
  Stream<List<PointsTransactionModel>> watchUserTransactions(
    String uid, {
    int limit = 20,
  }) {
    return Stream.multi((controller) {
      void emit() => controller.add(
        _currentItems.where((t) => t.uid == uid).take(limit).toList(),
      );
      emit();
      final subscription = PreviewStore.changes.listen((_) => emit());
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> requestRedeem({
    required String uid,
    required int jumlah,
    required String deskripsi,
  }) async {
    if (PreviewStore.role != 'sumber' || uid != 'preview-sumber') {
      throw StateError('Hanya Sumber yang dapat mengajukan redeem.');
    }
    final requestId = 'redeem-${DateTime.now().microsecondsSinceEpoch}';
    PreviewStore.redeems.insert(0, {
      'id': requestId,
      'uid': uid,
      'points': jumlah,
      'description': deskripsi,
      'status': 'submitted',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    _items = _currentItems;
    _items.insert(
      0,
      PointsTransactionModel(
        id: requestId,
        uid: uid,
        jenis: PointsTransactionType.redeem,
        jumlah: 0,
        deskripsi: deskripsi,
        status: PointsTransactionStatus.pendingRedeem,
        createdAt: DateTime.now(),
      ),
    );
    PreviewStore.points = _items.map((e) {
      final row = e.toMap()..['id'] = e.id;
      if (e.id == requestId) {
        row['redeem_request_id'] = requestId;
        row['points'] = 0;
      }
      return row;
    }).toList();
    await PreviewStore.save();
  }

  @override
  Future<void> reviewRedeem(
    String requestId, {
    required bool approve,
    required String reason,
  }) async {
    if (PreviewStore.role != 'admin') {
      throw StateError('Hanya Admin yang dapat meninjau redeem');
    }
    final rows = PreviewStore.redeems.where(
      (row) => row['id']?.toString() == requestId,
    );
    if (rows.isEmpty) throw StateError('Permintaan redeem tidak ditemukan');
    final request = rows.first;
    if (request['status'] != 'submitted') return;
    final amount = (request['points'] as num?)?.toInt() ?? 0;
    if (approve) {
      final uid = request['uid']?.toString() ?? '';
      final balance = PreviewStore.points
          .where((row) => row['uid'] == uid)
          .fold<int>(
            0,
            (sum, row) =>
                sum +
                ((row['points'] as num?)?.toInt() ??
                    (row['jumlah'] as num?)?.toInt() ??
                    0),
          );
      if (balance < amount) throw StateError('Saldo poin tidak mencukupi');
      if (!PreviewStore.points.any(
        (row) => row['redeem_request_id'] == requestId,
      )) {
        PreviewStore.points.add({
          'id': 'ledger-redeem-$requestId',
          'uid': uid,
          'entry_type': 'redeem',
          'points': -amount,
          'jumlah': -amount,
          'deskripsi': request['description'],
          'status': 'posted',
          'redeem_request_id': requestId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    }
    request['status'] = approve ? 'approved' : 'rejected';
    request['review_reason'] = reason;
    PreviewStore.audits.add({
      'id': 'audit-redeem-$requestId',
      'actor_id': 'preview-admin',
      'action': 'redeem_review',
      'entity_type': 'redeem_request',
      'entity_id': requestId,
      'metadata': {'approve': approve, 'reason': reason},
    });
    await PreviewStore.save();
  }

  @override
  Future<void> fulfillRedeem(String requestId, {String? reason}) async {
    if (PreviewStore.role != 'admin') {
      throw StateError('Hanya Admin yang dapat memenuhi redeem');
    }
    final rows = PreviewStore.redeems.where(
      (row) => row['id']?.toString() == requestId,
    );
    if (rows.isEmpty || rows.first['status'] != 'approved') {
      throw StateError('Redeem belum disetujui');
    }
    rows.first['status'] = 'fulfilled';
    PreviewStore.audits.add({
      'id': 'audit-fulfilled-$requestId',
      'actor_id': 'preview-admin',
      'action': 'redeem_fulfilled',
      'entity_type': 'redeem_request',
      'entity_id': requestId,
      'metadata': {'reason': reason},
    });
    await PreviewStore.save();
  }
}

class FakePartnerRepository implements PartnerRepositoryBase {
  @override
  Stream<List<PartnerActorModel>> watchPartners() => Stream.multi((controller) {
    void emit() => controller.add(_samplePartners);
    emit();
    final subscription = PreviewStore.changes.listen((_) => emit());
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<void> requestMatch({
    required String partnerId,
    required String uid,
  }) async {
    final submissions = PreviewStore.submissions.where(
      (row) => row['uid'] == uid && row['status'] == 'submitted',
    );
    if (submissions.isEmpty) {
      throw StateError('Tidak ada setoran yang siap dicocokkan');
    }
    final submission = submissions.first;
    submission['partner_id'] = partnerId;
    submission['partner_name'] = _samplePartners
        .firstWhere(
          (partner) => partner.id == partnerId,
          orElse: () => _samplePartners.first,
        )
        .nama;
    submission['status'] = 'offered';
    PreviewStore.offers.add({
      'id': 'offer-${submission['id']}-$partnerId',
      'submission_id': submission['id'],
      'processor_id': partnerId,
      'candidate_rank': 1,
      'status': 'pending',
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 20))
          .toIso8601String(),
    });
    await PreviewStore.save();
  }

  @override
  Future<void> reviewProcessor(
    String processorId, {
    required bool approve,
    required String reason,
  }) async {
    if (PreviewStore.role != 'admin') {
      throw StateError('Hanya Admin yang dapat memverifikasi pengolah');
    }
    final rows = PreviewStore.profiles.where(
      (profile) => profile['id']?.toString() == processorId,
    );
    if (rows.isEmpty) throw StateError('Pengolah tidak ditemukan');
    rows.first['processor_status'] = approve ? 'approved' : 'rejected';
    PreviewStore.audits.add({
      'id': 'audit-processor-$processorId',
      'actor_id': 'preview-admin',
      'action': 'processor_review',
      'entity_type': 'processor',
      'entity_id': processorId,
      'metadata': {'approve': approve, 'reason': reason},
    });
    await PreviewStore.save();
  }

  @override
  Future<void> updateProfile({
    required String processorId,
    required String displayName,
    required String processorType,
    required List<String> materials,
    required double totalCapacityKg,
    required double serviceRadiusKm,
    required double minimumPickupKg,
    required String administrativeArea,
    required String evidencePath,
    required double latitude,
    required double longitude,
  }) async {
    final rows = PreviewStore.profiles.where((p) => p['id'] == processorId);
    if (rows.isEmpty) throw StateError('Profil pengolah tidak ditemukan');
    final profile = rows.first;
    profile.addAll({
      'identity': displayName,
      'processor_type': processorType,
      'materials': materials,
      'total_capacity_kg': totalCapacityKg,
      'service_radius_km': serviceRadiusKm,
      'minimum_pickup_kg': minimumPickupKg,
      'administrative_area': administrativeArea,
      'latitude': latitude,
      'longitude': longitude,
      'evidence_path': evidencePath,
      'processor_status': profile['processor_status'] ?? 'pending',
    });
    await PreviewStore.save();
  }

  @override
  Future<void> updateOperational({
    required String processorId,
    required bool active,
    required bool pickupAvailable,
    String? pickupStart,
    String? pickupEnd,
  }) async {
    if (PreviewStore.role != 'pengolah') {
      throw StateError('Hanya Pengolah dapat mengubah operasional');
    }
    final profile = PreviewStore.profiles.firstWhere(
      (row) => row['id']?.toString() == processorId,
      orElse: () => throw StateError('Pengolah tidak ditemukan'),
    );
    profile.addAll({
      'active': active,
      'pickup_available': pickupAvailable,
      'pickup_start': pickupStart,
      'pickup_end': pickupEnd,
    });
    await PreviewStore.save();
  }
}

class FakeContentRepository implements ContentRepositoryBase {
  List<ArticleModel> _articles() {
    final persisted = PreviewStore.content
        .where((row) => row['status'] == 'approved' && row['kind'] != 'event')
        .map(
          (row) => ArticleModel(
            id: row['id'].toString(),
            title: row['title']?.toString() ?? '',
            summary: row['body']?.toString() ?? '',
            content: row['body']?.toString() ?? '',
          ),
        );
    return [..._sampleArticles, ...persisted];
  }

  List<MovementEventModel> _events() {
    final persisted = PreviewStore.content
        .where((row) => row['status'] == 'approved' && row['kind'] == 'event')
        .map(
          (row) => MovementEventModel(
            id: row['id'].toString(),
            title: row['title']?.toString() ?? '',
            organizer: row['organizer']?.toString() ?? 'Komunitas Pengolah',
            date: DateTime.tryParse(row['event_at']?.toString() ?? ''),
            location: row['event_location']?.toString() ?? '',
          ),
        );
    return [..._sampleEvents, ...persisted];
  }

  @override
  Stream<List<ArticleModel>> watchArticles() => Stream.multi((controller) {
    controller.add(_articles());
    final subscription = PreviewStore.changes.listen(
      (_) => controller.add(_articles()),
    );
    controller.onCancel = subscription.cancel;
  });

  @override
  Stream<List<MovementEventModel>> watchMovementEvents() =>
      Stream.multi((controller) {
        controller.add(_events());
        final subscription = PreviewStore.changes.listen(
          (_) => controller.add(_events()),
        );
        controller.onCancel = subscription.cancel;
      });

  @override
  Future<void> joinEvent({required String eventId, required String uid}) async {
    PreviewStore.notifications.add({
      'id': 'notification-event-${DateTime.now().microsecondsSinceEpoch}',
      'uid': uid,
      'title': 'Event diikuti',
      'body': 'Pendaftaran event berhasil dicatat.',
      'kind': 'event',
      'read': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await PreviewStore.save();
  }

  @override
  Future<String> createDraft({
    required String kind,
    required String title,
    required String body,
    DateTime? scheduledAt,
    String? location,
  }) async {
    if (PreviewStore.role != 'pengolah') {
      throw StateError('Hanya Pengolah dapat membuat draft');
    }
    final id = 'content-${DateTime.now().microsecondsSinceEpoch}';
    PreviewStore.content.add({
      'id': id,
      'kind': kind,
      'title': title,
      'body': body,
      'status': 'draft',
      'author_id': 'preview-pengolah',
      if (kind == 'event') ...{
        'event_at': scheduledAt?.toUtc().toIso8601String(),
        'event_location': location,
      },
    });
    await PreviewStore.save();
    return id;
  }

  @override
  Future<void> updateDraft({
    required String id,
    required String title,
    required String body,
  }) async {
    if (PreviewStore.role != 'pengolah') {
      throw StateError('Hanya Pengolah dapat mengubah draft');
    }
    final row = PreviewStore.content.firstWhere((e) => e['id'] == id);
    if (row['author_id'] != 'preview-pengolah' ||
        !['draft', 'rejected'].contains(row['status'])) {
      throw StateError('Draft tidak dapat diubah');
    }
    row['title'] = title;
    row['body'] = body;
    row['status'] = 'draft';
    await PreviewStore.save();
  }

  @override
  Future<void> submitDraft(String id) async {
    final row = PreviewStore.content.firstWhere((e) => e['id'] == id);
    if (PreviewStore.role != 'pengolah' ||
        row['author_id'] != 'preview-pengolah') {
      throw StateError('Draft bukan milik Pengolah');
    }
    row['status'] = 'submitted';
    await PreviewStore.save();
  }

  @override
  Future<void> moderateDraft(
    String id, {
    required bool approve,
    required String reason,
  }) async {
    if (PreviewStore.role != 'admin' || reason.trim().isEmpty) {
      throw StateError('Admin dan alasan wajib');
    }
    final row = PreviewStore.content.firstWhere((e) => e['id'] == id);
    if (row['status'] != 'submitted') throw StateError('Draft belum disubmit');
    row['status'] = approve ? 'approved' : 'rejected';
    PreviewStore.audits.add({
      'id': 'audit-$id',
      'action': 'content_review',
      'entity_id': id,
      'metadata': {'reason': reason},
    });
    await PreviewStore.save();
  }
}

class FakeSariGatewayService extends SariGatewayService {
  @override
  bool get isConfigured => true;

  @override
  Future<String> generateInsight(String dataSummary) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return 'Setoran organikmu naik dibanding bulan lalu, didorong oleh sisa sayur & buah. '
        'Coba setor ampas kopi juga, poin bonusnya sedang tinggi minggu ini.';
  }

  @override
  Future<String> chat(List<Map<String, String>> history) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final lastUser = history.isNotEmpty ? history.last['content'] ?? '' : '';
    final q = lastUser.toLowerCase();

    if (q.contains('poin sirkular') || q.contains('poin')) {
      return 'Poin Sirkular adalah reward yang kamu dapat tiap kali menyetor sampah '
          'organik atau anorganik. Poinmu saat ini ${_fakeUser.poinSirkular}, bisa '
          'ditukar jadi voucher atau donasi lingkungan.';
    }
    if (q.contains('jadwal') || q.contains('jemput')) {
      return 'Jadwal jemput mengikuti mitra terdekat di wilayahmu, cek lewat menu '
          'Wilayah Pencocokan di Beranda untuk lihat lokasi dan slot yang tersedia.';
    }
    if (q.contains('setor') || q.contains('sampah')) {
      return 'Kamu bisa setor lewat Setor Cerdas (cukup ngomong ke aku) atau Setor '
          'Manual di Beranda, pilih kategori Organik atau Anorganik sesuai jenis '
          'sampahmu.';
    }
    if (q.contains('halo') || q.contains('hai') || q.isEmpty) {
      return 'Hai! Aku Sari, asisten sirkularmu di SisaPedia. Ada yang bisa kubantu '
          'soal poin, setoran, atau jadwal jemput?';
    }
    return 'Aku bisa bantu soal Poin Sirkular, cara setor sampah, atau jadwal '
        'jemput mitra terdekat. Coba tanya salah satu topik itu ya.';
  }

  @override
  Future<Map<String, dynamic>> parseWaste(String transcript) async {
    final parsed = RegexWasteParserForPreview.parse(transcript);
    return {
      'kategori': parsed.category,
      'subtipe': parsed.subtype,
      'berat_kg': parsed.weightKg,
      'confidence': parsed.confidence,
      'perlu_klarifikasi': parsed.confidence < .7,
    };
  }
}

class RegexWasteParserForPreview {
  static ({String category, String subtype, double weightKg, double confidence})
  parse(String transcript) {
    final text = transcript.toLowerCase();
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:kg|kilo|kilogram)',
    ).firstMatch(text);
    final kg =
        double.tryParse(match?.group(1)?.replaceAll(',', '.') ?? '') ?? 1;
    if (text.contains('plastik') || text.contains('botol')) {
      return (
        category: 'anorganik',
        subtype: 'Botol Plastik PET',
        weightKg: kg,
        confidence: .92,
      );
    }
    if (text.contains('kertas') || text.contains('kardus')) {
      return (
        category: 'anorganik',
        subtype: 'Kardus & Kertas',
        weightKg: kg,
        confidence: .88,
      );
    }
    return (
      category: 'organik',
      subtype: text.contains('kopi') ? 'Ampas Kopi' : 'Sisa Sayur & Buah',
      weightKg: kg,
      confidence: text.isEmpty ? .2 : .78,
    );
  }
}
