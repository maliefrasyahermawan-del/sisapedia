import '../../data/models/article_model.dart';
import '../../data/models/movement_event_model.dart';
import '../../data/models/partner_actor_model.dart';
import '../../data/models/points_transaction_model.dart';
import '../../data/models/submission_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/waste_detection_result.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/points_repository.dart';
import '../../data/repositories/submission_repository.dart';
import '../services/gemini_vision_service.dart';
import '../services/groq_service.dart';

/// In-memory fake repositories backed by sample data, shared by both the
/// compile-time preview build (see [kPreviewMode] in preview_mode.dart) and
/// the runtime "Masuk sebagai Akun Testing" demo login.
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
          : const [
              'Botol Plastik PET',
              'Kardus & Kertas',
              'Logam & Kaleng',
            ][i % 3],
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
    kategoriDiterima: ['Organik', 'Kertas', 'Plastik'],
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
    kategoriDiterima: ['Organik'],
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
    kategoriDiterima: ['Plastik', 'Logam', 'Kertas'],
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
    kategoriDiterima: ['Organik'],
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
    kategoriDiterima: ['Organik', 'Plastik'],
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
    kategoriDiterima: ['Logam', 'Plastik'],
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
  Future<String> create(SubmissionModel submission) async {
    final id = 'local-${_items.length}';
    _items.insert(
      0,
      SubmissionModel(
        id: id,
        uid: submission.uid,
        kategori: submission.kategori,
        subtipe: submission.subtipe,
        beratKg: submission.beratKg,
        partnerId: submission.partnerId,
        partnerName: submission.partnerName,
        status: SubmissionStatus.pending,
        source: submission.source,
        createdAt: DateTime.now(),
        fotoUrl: submission.fotoUrl,
        alamat: submission.alamat,
        tanggalPengantaran: submission.tanggalPengantaran,
        waktuPengantaran: submission.waktuPengantaran,
        catatan: submission.catatan,
        deliveryMode: submission.deliveryMode,
      ),
    );
    return id;
  }

  @override
  Stream<SubmissionModel?> watchSubmission(String id) {
    return Stream.value(_items.where((s) => s.id == id).firstOrNull);
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
}

const _sampleDetections = [
  WasteDetectionResult(
    kategori: WasteCategory.anorganik,
    jenisMaterial: 'Plastik',
    subJenis: 'Botol Plastik PET',
    estimasiJumlah: 2,
    confidence: WasteConfidence.tinggi,
  ),
  WasteDetectionResult(
    kategori: WasteCategory.organik,
    jenisMaterial: 'Sisa Makanan',
    subJenis: 'Sisa Sayur & Buah',
    estimasiJumlah: null,
    confidence: WasteConfidence.sedang,
  ),
  WasteDetectionResult(
    kategori: WasteCategory.anorganik,
    jenisMaterial: 'Kertas',
    subJenis: 'Kardus & Kertas',
    estimasiJumlah: 1,
    confidence: WasteConfidence.rendah,
  ),
];

class FakeGeminiVisionService extends GeminiVisionService {
  @override
  bool get isConfigured => true;

  @override
  Future<WasteDetectionResult> analyze(List<int> imageBytes) async {
    await Future.delayed(const Duration(milliseconds: 900));
    return _sampleDetections[
        DateTime.now().millisecondsSinceEpoch % _sampleDetections.length];
  }
}
