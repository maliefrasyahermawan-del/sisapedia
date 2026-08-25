# SisaPedia — Progress Save Point

> Dokumen ini dibaca dulu di sesi baru sebelum menyentuh kode. Isinya: cara
> build/extract APK, peta file penting, keputusan desain sesi ini, dan config
> yang perlu disiapkan manual. Update terakhir: **26 Agustus 2026** — project
> Firebase **`sisapedia`** sudah beneran dikonfigurasi (bukan placeholder
> lagi), dan Akun Testing Sumber + Akun Pengolah (Testing) sekarang jadi
> **identitas Firebase nyata yang sama** lintas HP, dengan alur pertukaran
> setor sampah real-time lengkap (konfirmasi → kirim → terima → verifikasi →
> poin + QR) — lihat Bagian 4h. Ada **bug router** yang ketemu pas user tes
> di HP (masuk Akun Pengolah malah balik ke tampilan Sumber) — sudah
> diperbaiki, lihat Bagian 4i.

## 1. Status singkat

Fase 1 — role **Sumber** (warga/pemilah sampah) tetap jalur utama (Firebase
asli, register, dsb). Role **Pengolah** punya jalur testing cepat (tombol
Login "Masuk sebagai Akun Pengolah (Testing)" → langsung ke UI Pengolah,
tanpa daftar) — awalnya (25 Agt, Bagian 4g) data mock lokal per-device, tapi
sejak 26 Agustus (Bagian 4h) **kedua tombol testing (Sumber & Pengolah)
sign-in ke akun Firebase tetap yang sama** sehingga 2 HP berbeda (satu login
Akun Testing, satu login Akun Pengolah Testing) bisa saling lihat & bertukar
data submission secara real-time lewat Firestore — ini yang bikin simulasi
"2 HP" yang diminta user bisa jalan. Role **DLH-Admin** masih belum
dikerjakan sama sekali (lihat Bagian 5). Register sumber masih punya UI
pilihan role ("Saya Sumber" / "Saya Pengolah") dan "Saya Pengolah" di form
itu tetap non-fungsional ("Segera hadir") — jalur Pengolah yang beneran
jalan adalah tombol testing di Login, bukan lewat form Daftar.

Checkpoint git: lihat `git log --oneline -6`. Rangkaian commit dari sesi
**22–24 Agustus 2026**: (1) redesign Beranda header/kartu poin + layar
sukses setor + Login/Daftar sesuai referensi desain + login "Tamu"/"Akun
Testing" baru, (2) patch susulan — fix bug kartu poin ketutup header, warna
box kategori setor, ganti ikon app + nama app jadi "SisaPedia", (3) fix logo
splash/login yang belum sinkron dengan ikon app asli + redesign daftar
"Jenis Sampah" di Setor Manual jadi list rapi, (4) cherry-pick font Red Hat
+ layar Semua Artikel dari branch `dev`, (5) **fitur baru "Setor Cerdas
Mode Foto"** (Gemini Vision) + upgrade besar-besaran Setor Manual (foto
bukti, mode pengiriman, drill-down jenis sampah, info pengantaran) — lihat
Bagian 4, 4b, 4d, 4e, 4f.

## 2. Cara build & extract APK

App ini punya dua mode jalan:

- **Mode normal** (produksi/dev asli): butuh Firebase project + Groq API key
  sendiri (lihat `README.md` Bagian "Setup wajib"). **Sejak 26 Agustus 2026,
  project Firebase `sisapedia` sudah dikonfigurasi beneran** (lihat Bagian
  4h) — `lib/firebase_options.dart` sudah keisi config asli, BUKAN
  placeholder lagi. Mode ini WAJIB dipakai kalau mau coba fitur pertukaran
  setor real-time 2 HP (Bagian 4h), karena Akun Testing Sumber/Pengolah baru
  benar-benar terhubung lewat Firestore di mode ini.
- **Mode Preview** (`PREVIEW_MODE=true`): jalan 100% dari data mock di
  `lib/core/preview/preview_mode.dart`, tidak butuh Firebase/Groq sama
  sekali — TAPI di mode ini Akun Testing Sumber/Pengolah balik jadi data
  mock lokal per-device (TIDAK saling terhubung), karena tidak ada Firebase
  yang di-init sama sekali. Pakai mode ini kalau cuma mau lihat UI tanpa
  internet/Firebase, bukan untuk simulasi 2 HP.

```bash
cd "D:\Portofolio Alif 2\Project 55 - SisaPedia Mobile App"
flutter pub get
flutter analyze --no-fatal-infos      # pastikan bersih sebelum build
flutter build apk --release           # mode normal, WAJIB untuk fitur 2 HP (Bagian 4h)
# ATAU: flutter build apk --release --dart-define=PREVIEW_MODE=true   (mode preview, offline)
```

Hasil APK selalu di path yang sama (build ulang menimpa file lama):

```
build\app\outputs\flutter-apk\app-release.apk
```

Build terakhir (26 Agustus 2026, mode **normal** — bukan PREVIEW_MODE — setelah
fitur pertukaran setor real-time Sumber<->Pengolah, Bagian 4h): **57.7MB**,
berhasil, `flutter analyze` bersih (0 issues, cuma 2 info style yang
diabaikan). Ada 1 warning Gradle soal Kotlin Gradle Plugin
(`firebase_storage`, `speech_to_text`) — tidak fatal, aman diabaikan untuk
saat ini (sama seperti build-build sebelumnya).

> Catatan (BERUBAH per 26 Agustus 2026): login "Masuk sebagai Akun Testing"
> dan "Masuk sebagai Akun Pengolah (Testing)" sekarang **sign-in ke akun
> Firebase Authentication nyata** yang sama tiap kali ditekan (lihat
> `lib/core/session/testing_accounts.dart`) — bukan lagi cuma
> `sessionModeProvider` lokal + data Fake seperti sebelumnya (Bagian 4b),
> KECUALI kalau app di-build dengan `PREVIEW_MODE=true`, yang tetap
> mempertahankan perilaku lama (offline, data Fake, per-device). Efeknya:
> tekan tombol itu di 2 HP berbeda pakai APK mode normal → keduanya login
> ke identitas Firebase yang SAMA persis → bisa saling lihat data via
> Firestore. `PREVIEW_MODE` compile-time tetap ada untuk kasus "mau lihat UI
> tanpa Firebase sama sekali", tapi TIDAK BISA dipakai untuk simulasi 2 HP.

Untuk jalan langsung ke device/emulator tanpa build APK:
```bash
flutter run                                        # mode normal, fitur 2 HP aktif
flutter run --dart-define=PREVIEW_MODE=true         # mode preview, offline
```

## 3. Peta file penting

```
lib/
  app.dart                          — root MaterialApp.router (banner PRATINJAU sudah dihapus)
  main.dart                         — entrypoint, load .env, init Firebase (dilewati kalau PREVIEW_MODE).
                                       BERUBAH (26 Agt): setelah init Firebase, cek kalau user yang
                                       lagi login persisted itu salah satu akun testing (email cocok
                                       `kTestingSumberAccount`/`kTestingPengolahAccount`) → signOut
                                       paksa, supaya akun testing tetap "reset tiap restart app"
                                       seperti perilaku lama meski sekarang Firebase Auth-nya beneran
                                       persisted (lihat Bagian 4h untuk kenapa ini perlu)
  firebase_options.dart             — BERUBAH (26 Agt): config ASLI project Firebase `sisapedia`
                                       (dari `flutterfire configure`), BUKAN placeholder lagi — cuma
                                       `web` yang masih placeholder (app ini tidak target web)
  core/
    preview/
      fake_repositories.dart        — BARU (22 Agt): semua kelas Fake*Repository + data mock,
                                       dipindah keluar dari preview_mode.dart supaya bisa dipakai
                                       runtime (login Akun Testing) TANPA circular import
      preview_mode.dart             — sekarang cuma `kPreviewMode` flag + `previewModeOverrides`
                                       (compile-time), datanya sendiri ada di fake_repositories.dart
    session/                        — BARU (22 Agt): infra login Tamu/Akun Testing
      session_mode.dart             — `SessionMode` enum (normal/guest/demo/pengolahDemo, BARU 25 Agt)
                                       + `sessionModeProvider` + `kGuestUid`/`guestUserModel`
      guest_gate.dart                — dialog "Anda Belum Terdaftar" dipakai saat tamu coba setor
      testing_accounts.dart          — BARU (26 Agt): `kTestingSumberAccount`/`kTestingPengolahAccount`
                                       (email/password TETAP, hardcoded) + `signInTestingAccount()` —
                                       create-lalu-fallback-signIn ke akun Firebase Auth NYATA yang
                                       sama persis tiap device, ini akar dari fitur 2 HP (Bagian 4h)
    utils/level_utils.dart          — BARU (22 Agt): `LevelProgress.fromPoin()`, hitung level/ring
                                       progress dari poinSirkular (presentasi saja, tiap 2000 poin
                                       naik 1 level) — dipakai kartu poin Beranda & layar sukses setor
    services/
      submission_flow_service.dart  — BARU (26 Agt): state machine pertukaran setor Sumber<->Pengolah
                                       (`SubmissionFlowService`, lihat Bagian 4h) — SENGAJA terpisah
                                       dari `SubmissionRepositoryBase`, tidak ada versi Fake/offline
                                       (hanya masuk akal dengan backend nyata), layar yang memakainya
                                       hanya dijangkau saat `!kPreviewMode`
    providers/
      data_providers.dart           — provider Riverpod untuk articles/partners/events/dashboard
      notification_providers.dart   — `notificationsListProvider` (BARU 26 Agt) pilih otomatis: akun
                                       Sumber testing yang tersambung Firestore → notifikasi asli
                                       (koleksi `notifications`, ditulis `SubmissionFlowService`),
                                       selainnya (tamu/normal/preview) → seed lokal lama;
                                       `markAllNotificationsRead(ref)` gantikan pemanggilan langsung
                                       `.notifier.markAllRead()` di NotificationsScreen
      repository_providers.dart     — BERUBAH (26 Agt): `authRepositoryProvider`/
                                       `submissionRepositoryProvider`/`pointsRepositoryProvider`
                                       sekarang HANYA fake kalau `kPreviewMode` (compile-time) — bukan
                                       lagi berdasar `sessionMode == demo`. Efeknya Akun Testing Sumber
                                       & Akun Pengolah (Testing) di build normal sekarang pakai
                                       Firestore asli (lihat Bagian 4h), bukan `Fake*Repository` lagi.
                                       `partner`/`content`/Groq/Gemini TETAP gated ke `sessionMode ==
                                       demo` seperti sebelumnya (tidak berubah, tidak terkait fitur ini)
    router/app_router.dart          — redirect guard sekarang juga cek sessionMode (tamu/demo lolos
                                       tanpa uid Firebase asli); route BARU: /setor/sukses,
                                       /setor/foto-konfirmasi, /pengolah (BARU 25 Agt, shell mandiri
                                       role Pengolah — redirect dari Login otomatis ke sini kalau
                                       sessionMode == pengolahDemo, lihat Bagian 4g). **PENTING (bug fix 24 Agt)**: route
                                       literal (/setor/sukses, /setor/foto-konfirmasi) HARUS
                                       dideklarasikan SEBELUM /setor/:kategori — go_router cocokin
                                       sibling routes berurutan sesuai deklarasi, dan `:kategori`
                                       match string APAPUN termasuk "sukses"/"foto-konfirmasi",
                                       jadi kalau kebalik, route literal itu nggak akan pernah
                                       ke-reach (fallback diam-diam ke SetorFormScreen kategori
                                       organik) — ini yang sempat bikin alur Foto Cerdas nyasar ke
                                       form manual, lihat Bagian 4f
    services/
      groq_service.dart             — GroqService.chat() (chat Sari penuh, terpisah dari
                                       generateInsight() untuk Insight AI Dashboard)
      gemini_vision_service.dart    — BARU (24 Agt): GeminiVisionService.analyze(), rotasi
                                       otomatis sampai 3 API key (GEMINI_API_KEY_1/2/3) kalau
                                       kena rate limit (HTTP 429), parse JSON hasil deteksi
                                       (strip code-fence markdown dulu kalau ada)
      photo_upload_service.dart     — BARU (24 Agt): uploadSubmissionPhoto(), upload ke
                                       Firebase Storage ATAU placeholder fake kalau
                                       kPreviewMode/demo (lihat Bagian 4f)
    theme/                          — app_colors.dart (+ accent700/800/900, levelBadge BARU),
                                       app_text_styles.dart, app_theme.dart (font Red Hat, lihat
                                       Bagian 4e)
  data/
    geo/semarang_boundary.dart      — 194 titik lat/lng batas administratif Kota Semarang
                                       (dari OSM/Nominatim, disederhanakan RDP eps=0.0012)
    models/                         — semua model data (ArticleModel.content sudah diisi mock).
                                       submission_model.dart (24 Agt) nambah: fotoUrl, alamat,
                                       tanggalPengantaran, waktuPengantaran, catatan,
                                       DeliveryMode enum (cod/antarLangsung/requestPengolah) —
                                       semua nullable/additive, nggak ganggu kode lama.
                                       BERUBAH LAGI (26 Agt, Bagian 4h): + `namaSumber` (nama Sumber
                                       didenormalisasi saat create, biar antrean Pengolah nggak perlu
                                       lookup `users/{uid}` tiap item), + `SubmissionFlowStatus` enum
                                       (10 state, lihat Bagian 4h) & field-field terkait
                                       (`flowStatus`, `pengolahUid/Nama/Telepon`, `koreksiKategori/
                                       Subtipe/BeratKg`, `catatanVerifikasi`, `finalPoin`,
                                       `qrPayload`, 3 timestamp tambahan), + `copyWith({id})`.
                                       `NegosiasiKeputusan` enum (3 pilihan Sumber) di file yang sama.
                                       waste_detection_result.dart BARU: WasteDetectionResult +
                                       WasteConfidence enum, dipakai GeminiVisionService
    repositories/                   — implementasi asli (Firestore), dipakai kalau `!kPreviewMode`
                                       (BERUBAH 26 Agt — dulu berdasar sessionMode, lihat catatan
                                       `repository_providers.dart` di atas).
                                       submission_repository.dart: `create()` sekarang balikin id
                                       (`Future<String>`, bukan `Future<void>`) + method baru
                                       `watchSubmission(id)` (realtime 1 dokumen, dipakai layar
                                       progress). `watchUserSubmissions()` DIUBAH dari
                                       `.where().orderBy().limit()` jadi `.where()` + sort/limit di
                                       client — query `where` + `orderBy` field beda butuh composite
                                       index Firestore yang belum ada di project baru, jadi
                                       dihindari sekalian (lihat juga points_repository.dart yang
                                       kena perubahan sama untuk alasan sama)
  features/
    home/
      beranda_screen.dart           — uid Beranda sekarang fallback ke `kGuestUid` saat tamu supaya
                                       layar tidak stuck loading. BERUBAH (26 Agt, Bagian 4j): teruskan
                                       `onLihatStatusSetoran` baru ke `SetorActionsSection`
      widgets/beranda_header.dart   — REDESIGN (22 Agt): gradasi hijau, salam berbasis jam
                                       (pagi/siang/sore/malam), sesuai referensi desain
      widgets/setor_actions_section.dart — BERUBAH (26 Agt, Bagian 4j): + kartu "Lihat Status Setoran
                                       Sampah" (`_StatusSetoranCard`) di bawah kartu Wilayah Pencocokan
      widgets/points_card.dart      — REDESIGN (22 Agt): kartu gradasi hijau tua + ring progress
                                       level, badge "LV. n", label "PENGUMPUL RAJIN" — ganti total
                                       dari kartu putih lama (tombol Share dihapus, tidak ada di
                                       referensi)
    setor_manual/
      setor_form_screen.dart        — submit sekarang: (1) blokir tamu → `showGuestRegisterGate()`
                                       lalu redirect /register, (2) sukses → push `/setor/sukses`
                                       (dulu cuma snackbar+pop). Jenis Sampah sekarang drill-down
                                       2 level (BARU 24 Agt, lihat Bagian 4f) — tap kategori utama
                                       (mis. "Kaca") buka bottom sheet berisi ≥5 sub-jenis spesifik
                                       (`_pickJenis()`, data di `const _organikJenis`/`_anorganikJenis`).
                                       Foto bukti wajib (`FotoBuktiField`) + `PengantaranSection`
                                       (mode pengiriman/alamat/jadwal/catatan) ditambahkan di sini.
                                       BERUBAH (26 Agt): submit isi `namaSumber` dari
                                       `userProfileProvider`, tangkap id balikan `create()`, push
                                       `submission.copyWith(id: id)` ke `/setor/sukses`
      setor_success_screen.dart     — DIHAPUS (26 Agt), digantikan `setor_progress_screen.dart`
                                       (lihat Bagian 4h) — poin TIDAK lagi langsung "estimasi
                                       ditampilkan", sekarang beneran nunggu Pengolah lewat live
                                       tracker sebelum poin masuk
      setor_progress_screen.dart    — BARU (26 Agt): `SetorProgressScreen`, dipasang di route
                                       `/setor/sukses` (nama path TETAP dipakai — sengaja, biar
                                       nggak perlu nambah literal route baru di atas
                                       `/setor/:kategori`, lihat catatan bug 24 Agt di atasnya).
                                       `StreamBuilder` ke `watchSubmission(id)`, render timeline
                                       tahap + kartu kontekstual sesuai `flowStatus` (nunggu/kontak
                                       Pengolah/diverifikasi/negosiasi/QR sukses/gagal). Tombol
                                       negosiasi manggil `submissionFlowServiceProvider` — lihat
                                       Bagian 4h untuk detail state machine lengkap
      setoran_status_list_screen.dart — BARU (26 Agt, Bagian 4j): `SetoranStatusListScreen`, route
                                       `/setor/status` — list SEMUA submission user (reuse
                                       `watchUserSubmissions()`, bukan provider baru) + chip status,
                                       tap item buka `SetorProgressScreen` yang sama. Empty state
                                       "Status Setoran: Kosong" kalau belum pernah setor
      widgets/                      — BARU (24 Agt): dipakai bareng Setor Manual & Setor Cerdas Foto
        pengantaran_section.dart    — `PengantaranSection`: pilihan Mode Pengiriman (COD/Antar
                                       Langsung/Request Pengolah Datang, `DeliveryMode` enum di
                                       submission_model.dart) + field alamat yang label/hint-nya
                                       otomatis berubah sesuai mode + tanggal/waktu pengantaran +
                                       catatan opsional
        foto_bukti_field.dart       — `FotoBuktiField`: kartu upload foto bukti sampah (wajib),
                                       cuma dipakai Setor Manual (Setor Cerdas Foto reuse foto
                                       deteksi AI-nya sendiri sebagai bukti, tidak perlu foto kedua)
    setor_foto/                     — BARU (24 Agt): alur "Mode Foto Cerdas"
      foto_cerdas_flow.dart         — `startFotoCerdasFlow()` (entry point) dan
                                       `captureAndAnalyzePhoto()` (dipisah dari navigasi supaya
                                       "Ambil Ulang Foto" bisa `pushReplacement` tanpa pop/push
                                       manual yang rawan context-invalid)
      foto_konfirmasi_screen.dart   — `FotoKonfirmasiScreen`, layar "Validasi Hasil AI": preview
                                       foto + badge keyakinan AI, kategori/jenis material/sub-jenis
                                       BISA DIKOREKSI (bukan teks statis), berat WAJIB manual (AI
                                       tidak pernah diminta nebak kg), + `PengantaranSection` yang
                                       sama dengan Setor Manual
    setor_cerdas/
      voice_modal.dart              — alur suara lama, TIDAK diubah sama sekali
      setor_cerdas_mode_sheet.dart  — BARU (24 Agt): bottom sheet pilihan "Mode Suara Cerdas" vs
                                       "Mode Foto Cerdas", jadi entry point baru tombol Setor
                                       Cerdas di nav bar (ikonnya juga diganti mic → otak
                                       `Icons.psychology_rounded`, lihat Bagian 4f)
    auth/
      login_screen.dart             — REDESIGN (22 Agt) sesuai referensi HTML + tombol baru "Masuk
                                       sebagai Tamu" dan "Masuk sebagai Akun Testing"; tombol BARU
                                       (25 Agt) "Masuk sebagai Akun Pengolah (Testing)" — lihat 4g.
                                       BERUBAH LAGI (26 Agt): `_enterAs()` untuk 2 tombol testing
                                       sekarang `async` — panggil `signInTestingAccount()` (Firebase
                                       Auth nyata) dulu sebelum set sessionMode, kecuali kalau
                                       `kPreviewMode`. State loading per-tombol (`_enteringTestingMode`)
                                       + snackbar error kalau sign-in gagal (mis. tidak ada internet)
      register_screen.dart          — REDESIGN (22 Agt) sesuai referensi HTML + role card "Saya
                                       Sumber"/"Saya Pengolah" (Pengolah non-fungsional, lihat Bag. 1)
    pengolah/                       — BARU (25 Agt): UI role Pengolah, testing-only, lihat Bagian 4g
      pengolah_shell_screen.dart    — shell mandiri (bottom nav 5 tab sendiri, BUKAN
                                       StatefulShellRoute/BottomNavScaffold milik Sumber).
                                       BERUBAH (26 Agt): `_keluar()` sekarang beneran signOut Firebase
                                       kalau `!kPreviewMode` (dulu cuma reset sessionMode lokal)
      pengolah_colors.dart          — aksen biru role Pengolah, terpisah dari AppColors (hijau Sumber)
      data/pengolah_mock.dart       — data mock lokal (submission masuk, event komunitas) — TETAP
                                       dipakai sebagai fallback offline kalau `kPreviewMode`
      widgets/
        pengolah_beranda_tab.dart   — BERUBAH (26 Agt): bell notifikasi (`_NotifBell`) + label
                                       "Setoran Masuk · N baru" sekarang pakai count ASLI dari
                                       `submissionFlowServiceProvider.watchIncomingQueue()` (bukan
                                       `pengolahSubmissions.length` mock) kalau `!kPreviewMode`
        pengolah_setoran_tab.dart   — BERUBAH TOTAL (26 Agt): kalau `!kPreviewMode`, tampilkan 2
                                       `StreamBuilder` realtime — "Perlu Dikonfirmasi"
                                       (`watchIncomingQueue()`) & "Sedang Diproses"
                                       (`watchPengolahAktif(uid)`) — tap kartu push ke
                                       `PengolahSubmissionDetailScreen(submissionId: ...)`. Kalau
                                       `kPreviewMode`, fallback ke UI mock lama (`_OfflineSetoranList`,
                                       class private baru di file yang sama, isinya persis widget
                                       lama sebelum 26 Agt)
        pengolah_submission_detail_screen.dart — DITULIS ULANG (26 Agt): dari terima `PengolahSubmission`
                                       (mock, statis) jadi terima `submissionId` (String) + StreamBuilder
                                       live ke `watchSubmission()`. Tombol aksi berubah total sesuai
                                       `flowStatus` — Terima/Tolak (menungguKonfirmasi), Tandai Sudah
                                       Diterima (dikonfirmasi), Setujui/Tidak Sesuai + form koreksi
                                       berat & catatan (sedangDiverifikasi), read-only untuk sisanya.
                                       Semua manggil method `submissionFlowServiceProvider`
        pengolah_dashboard_tab.dart, pengolah_komunitas_tab.dart, pengolah_profil_tab.dart,
        pengolah_create_post_screen.dart — TIDAK diubah sesi ini (26 Agt), tetap mock lokal
    map/peta_screen.dart            — peta interaktif, PolygonLayer garis merah batas Semarang
    wilayah/wilayah_pencocokan_screen.dart  — alternatif list (bukan peta) untuk pilih mitra
    sari_chat/sari_chat_screen.dart — layar chat penuh dengan Sari (pakai GroqService.chat)
    notifications/notifications_screen.dart — BERUBAH (26 Agt): baca `notificationsListProvider`
                                       (bukan `notificationsProvider` langsung), mark-all-read manggil
                                       `markAllNotificationsRead(ref)` — otomatis pilih Firestore asli
                                       atau seed lokal (lihat catatan notification_providers.dart)
    articles/article_detail_screen.dart
    profile/
      panduan_screen.dart           — accordion 7 bagian panduan lengkap
      profil_screen.dart            — tombol Keluar sekarang reset sessionMode ke normal juga
                                       (bukan cuma signOut Firebase), supaya tamu/akun testing bisa
                                       "keluar" balik ke Login sungguhan. BERUBAH (26 Agt): kondisi
                                       signOut Firebase diperluas jadi `mode == normal || mode ==
                                       demo` (dulu cuma `normal`) — Akun Testing Sumber sekarang
                                       identitas Firebase nyata juga, butuh signOut sungguhan
    shared/widgets/
      bottom_nav_scaffold.dart      — FAB "Sari" mengambang di semua tab; tombol Setor Cerdas
                                       (nonaktif otomatis untuk tamu) sekarang buka
                                       `showSetorCerdasModeSheet()`, bukan langsung `showVoiceModal()`
      image_source_sheet.dart       — BARU (24 Agt): `showImageSourceSheet()`, bottom sheet
                                       Kamera/Galeri yang dipakai bareng Setor Cerdas Foto dan
                                       foto bukti Setor Manual
```

## 4. Ringkasan patch sesi 19 Agustus 2026 (urut sesuai permintaan)

**Batch 1 — bug visual awal:**
- Header Beranda dibungkus `SafeArea` (dulu bentrok status bar).
- Artikel jadi bisa diklik → `ArticleDetailScreen` baru dengan isi lengkap
  (3 artikel diisi konten penuh di `preview_mode.dart`).
- Dashboard "Saya" vs "Kota Semarang" dibedakan — ditambah ~42 submission
  mock dari 9 warga lain supaya scope kota beda dari scope personal.
- Fitur notifikasi ditambah (bell + badge + `NotificationsScreen`).

**Batch 2 — bug lanjutan + fitur baru:**
- Card Poin Sirkular yang ketutup header dihapus efek `Transform.translate`-nya.
- Ribbon "PRATINJAU" dihapus total dari `app.dart`.
- Tombol "Gabung" Movement sekarang buka form (`join_event_sheet.dart`):
  Nama, No. HP/WA, Motivasi → baru submit. **Belum ada backend nyata ke
  akun Pengolah** (memang sengaja ditunda per instruksi user), tapi form +
  UX submit sudah lengkap.
- Chatbot Sari diimplementasikan nyata: FAB mengambang di semua tab →
  `SariChatScreen`, pakai `GroqService.chat()` (real API kalau `.env` ada
  `GROQ_API_KEY`; fallback jawaban mock berbasis keyword di
  `FakeGroqService.chat()` untuk build preview).
- "Wilayah Pencocokan" tidak lagi lempar ke tab Peta, sekarang buka layar
  list terpisah dengan tab kecamatan (Tembalang/Semarang Tengah/Semarang
  Selatan) — lebih ringan render-nya dibanding peta interaktif.
- Panduan diganti jadi accordion 7 bagian (Registrasi, Pickup Sampah, Drop
  Off Sampah, Company dan Event, Menjadi Mitra, Poin & Level Sirkular,
  Jenis dan Harga Sampah).

**Batch 3 — garis batas kota di peta:**
- `PolygonLayer` merah (`#DC2626`, border 2.5px, tanpa fill) mengikuti
  batas administratif asli Kota Semarang, bukan bentuk perkiraan/kasar.
  Data diambil dari Nominatim (`nominatim.openstreetmap.org/search`,
  `polygon_geojson=1`), disederhanakan dari 2.585 → 194 titik.

## 4b. Ringkasan patch sesi 22 Agustus 2026

Sumber desain: 3 screenshot referensi (Beranda header + kartu poin, layar
sukses setor) dan file `SisaPedia - Standalone Export.html` (mockup HTML
untuk Login & Daftar). **Sesuai instruksi user, HANYA layar-layar ini yang
didesain ulang** — tidak ada layar lain di mockup yang ikut diterapkan.

- **Beranda**: header + kartu poin didesain ulang total mengikuti referensi
  (ring progress level, badge "LV. n", label "PENGUMPUL RAJIN"). Level
  dihitung murni presentasi dari `poinSirkular` (`level_utils.dart`), bukan
  field baru di backend.
- **Layar sukses setor** (`setor_success_screen.dart`, route baru
  `/setor/sukses`): checkmark besar + "Mantap, {nama}!" + kartu poin.
  Diputuskan bareng user: angka poin yang tampil **estimasi**, bukan final
  — karena poin sungguhan baru ditambahkan setelah admin/pengolah
  memverifikasi submission (statusnya masih `pending` saat submit). Cuma
  dipasang di alur **Setor Manual**; Setor Cerdas (voice, multi-item) tetap
  pakai pop biasa seperti sebelumnya karena copy layar sukses ini didesain
  untuk satu item.
- **Login & Daftar**: didesain ulang mengikuti mockup HTML (header gradasi
  hijau, field, tombol pill). Daftar dapat kartu pilih role "Saya
  Sumber"/"Saya Pengolah" dari mockup — diputuskan bareng user: "Saya
  Pengolah" tetap tampil tapi non-fungsional ("Segera hadir"), karena app
  masih fase 1 Sumber-only; submit tetap daftar sebagai Sumber.
- **Login "Masuk sebagai Tamu"** (baru, bukan dari mockup — permintaan
  terpisah user): `sessionModeProvider` di-set ke `guest`, masuk tanpa data
  nyata (`guestUserModel`, uid sintetis `guest-local`). Begitu tamu pilih
  jenis sampah di Setor Manual lalu tekan submit, muncul dialog "Anda
  Belum Terdaftar" dan diarahkan ke `/register`. Tombol mic "Setor Cerdas"
  otomatis nonaktif untuk tamu (karena butuh uid Firebase asli).
- **Login "Masuk sebagai Akun Testing"** (baru, bukan dari mockup):
  `sessionModeProvider` di-set ke `demo`, semua repository provider otomatis
  switch ke `Fake*Repository` yang sudah ada di `fake_repositories.dart`
  (data yang sama persis dipakai build `PREVIEW_MODE`) — jadi seluruh app
  (Beranda, Dashboard, Peta, riwayat, dsb) langsung terisi data mock tanpa
  perlu build ulang dengan `--dart-define`.
- Refactor pendukung: `preview_mode.dart` dipecah jadi
  `fake_repositories.dart` (data + kelas Fake) supaya bisa dipakai runtime
  tanpa circular import balik ke `repository_providers.dart`.

## 4c. Patch susulan sesi 22 Agustus 2026 (sama hari, commit terpisah)

Tiga hal yang direvisi user setelah lihat hasil patch 4b:

- **Bug kartu poin ketutup header** — root cause-nya trik
  `Transform.translate` di dalam `SliverToBoxAdapter` (Bagian 4b) cuma
  menggeser hasil gambar (paint offset), bukan posisi layout aslinya, jadi
  urutan gambar antar sliver kadang bikin header nutupin sebagian kartu
  level. Diganti total: `beranda_screen.dart` sekarang render header +
  kartu poin dalam satu `Stack` eksplisit (kartu poin jadi child terakhir
  → selalu di atas), bukan dua sliver terpisah lagi.
- **Warna box kategori setor** (`setor_actions_section.dart`) — mengikuti
  gaya pewarnaan dari referensi (bukan layoutnya): "Setor Organik" latar
  hijau muda, "Setor Anorganik" latar biru muda, "Wilayah Pencocokan" latar
  oranye muda. Layout kartu (ukuran, susunan 2 kolom + 1 baris penuh) tetap
  seperti sebelumnya.
- **Ganti ikon app + nama app** — ikon launcher (Android semua mipmap +
  adaptive icon, iOS semua ukuran AppIcon.appiconset) diganti jadi logo
  bowtie hijau-biru sesuai referensi, di-generate lewat
  `flutter_launcher_icons` dari `assets/icon/app_icon*.png`. **Catatan
  jujur**: file gambar logo asli yang dikirim user tidak ada di disk lokal
  (cuma terlihat di chat), jadi bentuknya di-recreate ulang secara
  presisi (`scripts/gen_icon.py`, dua segitiga simetris) — kalau ada
  perbedaan detail dari file asli, minta user kirim file PNG-nya langsung
  lalu timpa `assets/icon/app_icon.png` + `app_icon_foreground.png` dan
  jalankan ulang `dart run flutter_launcher_icons`. Nama tampilan app juga
  dibetulkan castingnya: `sisapedia` → `SisaPedia` di
  `android/app/src/main/AndroidManifest.xml` (`android:label`) dan
  `ios/Runner/Info.plist` (`CFBundleDisplayName`/`CFBundleName`).

## 4d. Patch sesi 23 Agustus 2026

Dua hal dari feedback user setelah lihat APK patch 4c:

- **Logo splash & login belum sinkron dengan ikon app** — sebelumnya
  `splash_screen.dart`, header `login_screen.dart`, dan brand mark kecil di
  `beranda_header.dart` masih pakai glyph `Icons.eco_rounded` (daun bawaan
  Material), padahal ikon launcher app sendiri sudah diganti jadi logo
  bowtie hijau-biru sejak patch 4c. Sekarang ketiganya pakai
  `Image.asset('assets/icon/app_icon.png')` — file PNG yang sama persis
  dipakai `flutter_launcher_icons` buat generate ikon launcher — supaya
  logo yang tampil di dalam app konsisten dengan ikon aplikasi di
  homescreen HP. File ini didaftarkan sebagai asset Flutter biasa di
  `pubspec.yaml` (`flutter: assets:`), bukan cuma dipakai launcher icon.
- **Redesign pemilihan "Jenis Sampah"** di `setor_form_screen.dart` — dulu
  `Wrap` isi `ChoiceChip` polos, sekarang jadi list vertikal rapi di dalam
  satu card (ikon lingkaran per jenis sampah + nama + tombol pill
  "Pilih"/"Dipilih", dipisah `Divider` antar baris), niru gaya referensi
  user (bukan fitur kamera "tambah sendiri"-nya, cuma cara list +
  tombolnya). Widget barunya `_JenisSampahTile` (private, di file yang
  sama), dan mapping ikon per subtipe ada di `const _subtipeIcons` (masih
  di file yang sama) — kalau nanti nambah subtipe baru, jangan lupa
  tambahin entry ikonnya juga di situ.

## 4e. Cherry-pick dari branch `dev` (23 Agustus 2026, sore)

Orang lain (bukan sesi ini) push ke branch `dev` di remote GitHub yang sama
(`origin/dev`, author `ezaarp <andrariezarizqip@gmail.com>`, 7 commit tgl 23
Agustus 19:37–20:20) — isinya jauh lebih besar dari `master`: ganti backend
total dari **Firebase ke Supabase**, tambah role Pengolah/DLH-Admin penuh,
OTP telepon, reset password, matching engine, dan testsuite besar. Setelah
dikonfirmasi ke user, **diputuskan TIDAK full-merge** — `master` tetap
Firebase, tetap fase 1 Sumber-only. Yang diambil cuma bagian yang
benar-benar backend-agnostic dan aman berdiri sendiri:

- **Font Red Hat asli** (`assets/fonts/RedHatDisplay[wght].ttf`,
  `RedHatText[wght].ttf` + lisensi OFL) menggantikan Google Fonts Manrope di
  `app_text_styles.dart`/`app_theme.dart`. Ini justru menyamakan font app
  dengan token asli di file referensi HTML (`--font:'Red Hat Text'`,
  `--font-display:'Red Hat Display'`) yang jadi acuan redesign sesi-sesi
  sebelumnya — dependency `google_fonts` sudah dihapus total dari
  `pubspec.yaml` (tidak dipakai lagi di mana pun).
- **`lib/features/articles/article_list_screen.dart`** (BARU) — layar
  "Semua Artikel" (list lengkap, bukan cuma 3 teratas). Tombol "Lihat
  Lainnya" di `redeem_article_section.dart` sebelumnya `onPressed: () {}`
  (dead button, bug lama yang belum ketahuan) — sekarang beneran navigasi
  ke `/artikel` (route baru di `app_router.dart`).

Yang **SENGAJA TIDAK** diambil (backend-coupled ke Supabase atau ekspansi
scope role Pengolah/DLH di luar fase 1): `supabase_flutter` + seluruh
`supabase/` (migrations/RLS/Edge Functions), `lib/features/roles/*.dart`
(role shell + layar Pengolah/DLH/Admin), OTP telepon & reset password
(nempel ke Supabase Auth API, bukan portable ke Firebase Auth begitu saja),
`matching_engine.dart`/`lifecycle_rules.dart` (bergantung ke field
`PartnerActorModel`/`SubmissionStatus` yang diperluas, yang cuma dipakai
alur matching admin/Pengolah), `points_rules.dart` (formula poinnya sama
persis dengan yang sudah dipakai `setor_success_screen.dart`, tapi skema
level bertingkat nama-nya beda paradigma dari ring "LV. n" yang sudah
disetujui user — kalau diadopsi malah mundur dari desain yang sudah oke),
dan `releases/apk/*.apk` (APK yang mereka commit langsung ke git, bukan
gaya project ini).

## 4f. Fitur baru "Setor Cerdas Mode Foto" + upgrade Setor Manual (24 Agustus 2026)

Permintaan asli user: Setor Cerdas yang sekarang cuma mode suara (voice +
regex) mau ditambah alternatif **mode foto** pakai Gemini Vision — bukan
gantiin mode suara, dua-duanya hidup berdampingan dan user pilih sendiri
tiap kali mau setor.

**Alur baru:**
1. Tap tombol Setor Cerdas di nav bar (ikonnya diganti dari mic jadi otak,
   `Icons.psychology_rounded`, sesuai permintaan user) → `showSetorCerdasModeSheet()`
   nampilin 2 pilihan: "Mode Suara Cerdas" (langsung ke `showVoiceModal()`
   yang lama, **tidak disentuh sama sekali**) dan "Mode Foto Cerdas" (alur baru).
2. Mode Foto: pilih Kamera/Galeri (`showImageSourceSheet()`) → foto dikirim
   ke `GeminiVisionService.analyze()` → hasil deteksi (kategori, jenis
   material, sub-jenis, estimasi jumlah item, confidence tinggi/sedang/rendah)
   ditampilkan di layar **"Validasi Hasil AI"** (`FotoKonfirmasiScreen`) —
   semua field BISA DIKOREKSI, berat WAJIB diisi manual (AI dilarang keras
   nebak kg dari foto, sesuai instruksi user — nggak reliable tanpa objek
   referensi skala).
3. Baru setelah user tekan "Konfirmasi & Simpan", data masuk ke
   `submissionRepositoryProvider.create()` yang sama persis dengan alur
   Setor Manual.

**`GeminiVisionService`** (`lib/core/services/gemini_vision_service.dart`):
- Sampai 3 API key (`GEMINI_API_KEY_1/2/3` di `.env`), sequential fallback
  sederhana kalau kena HTTP 429 (rate limit/quota habis) — bukan
  round-robin/load-balancing kompleks, sesuai instruksi user.
- Model: `gemini-2.0-flash`. Prompt eksplisit minta JSON terstruktur +
  eksplisit MELARANG estimasi berat kg.
- Parse JSON aman (try-catch + strip code-fence ```` ```json ```` kalau ada).
- `FakeGeminiVisionService` di `fake_repositories.dart` (data dummy acak
  dari 3 contoh) buat mode Preview/Akun Testing — provider-nya
  (`geminiVisionServiceProvider`) ikut pola `_isDemo(ref)` yang sama
  dengan `groqServiceProvider`.

**Bug kritis yang ketemu & dibenerin** (user laporkan: habis foto+analisis,
malah nyasar ke layar Setor Organik manual, dan kategori "kelihatan salah"):
root cause-nya BUKAN Gemini salah tebak — `/setor/:kategori` dideklarasikan
SEBELUM `/setor/foto-konfirmasi` di `app_router.dart`. go_router cocokin
sibling routes urut sesuai deklarasi, dan `:kategori` itu wildcard yang
match string APAPUN (termasuk "foto-konfirmasi"), jadi route itu keburu
"dimakan" `:kategori` dan fallback diam-diam ke `WasteCategory.organik` —
user nggak pernah lihat jawaban asli Gemini sama sekali. Fix: pindahin
semua route literal di bawah `/setor/` (termasuk `/setor/sukses` yang sudah
lama ada, ternyata kena bug yang sama) ke atas `/setor/:kategori`.

**Upgrade susulan Setor Manual** (setelah user lihat "Validasi Hasil AI"
jalan, minta fitur logistik yang sebelumnya belum ada, niru referensi app
lain):
- **Foto Bukti Sampah** (wajib) — `FotoBuktiField`, upload via
  `photo_upload_service.dart` ke Firebase Storage (atau placeholder fake
  kalau `kPreviewMode`/demo — dicek eksplisit karena `sessionModeProvider`
  TIDAK otomatis `demo` di build `PREVIEW_MODE`, itu dua mekanisme
  independen, lihat catatan di kode). Setor Cerdas Foto REUSE foto deteksi
  AI-nya sendiri sebagai bukti, nggak minta foto kedua.
- **Mode Pengiriman** (`DeliveryMode` enum) — 3 kartu pilihan: COD (Ketemu
  Langsung), Antar Langsung (ke pengepul), Request Pengolah Datang (dijemput
  — ini behavior default lama). Field alamat di bawahnya ganti
  label/hint/placeholder otomatis sesuai mode yang dipilih (satu field,
  bukan 3 field terpisah).
- **Informasi Pengantaran** — tanggal (date picker) + slot waktu
  (08:00–12:00/12:00–15:00/15:00–17:00), keduanya wajib.
- **Informasi Tambahan** — catatan opsional.
- Semua field baru ini (`PengantaranSection`, shared widget) dipasang di
  KEDUA alur — Setor Manual DAN Setor Cerdas Foto — karena keduanya sama-
  sama bikin `SubmissionModel` yang butuh logistik penjemputan yang sama.
- **Jenis Sampah jadi drill-down 2 level** — sebelumnya tap kategori utama
  (mis. "Kaca") langsung jadi `subtipe` final. Sekarang tap kategori utama
  buka bottom sheet berisi ≥5 sub-jenis spesifik (persis contoh user: Kaca
  → Botol Kecap/ABC/Bir/Cuka/Saus Sambal), baru sub-jenis itu yang jadi
  `subtipe` final. Semua 9 kategori utama (4 organik + 5 anorganik) diisi
  minimal 5 sub-jenis masing-masing — datanya di `const _organikJenis`/
  `_anorganikJenis` di `setor_form_screen.dart`.

## 4g. Akun Pengolah — jalur testing tanpa daftar (25 Agustus 2026)

Permintaan asli user: role **Pengolah** (pengepul/bank sampah) belum ada
sama sekali di app (lihat Bagian 5 versi lama). Diminta dibangun jalur cepat
untuk testing/demo — **tanpa perlu daftar** — diakses dari tombol baru di
Login, tampilannya niru bagian "ROLE: PENGOLAH" di file referensi
`SisaPedia App.html` yang dikirim user (bukan `SisaPedia - Standalone
Export.html` yang sudah dipakai untuk redesign Login/Daftar). **Instruksi
eksplisit user: akun Sumber TIDAK BOLEH disentuh sama sekali** — jadi fitur
ini dibangun sebagai modul yang sepenuhnya berdiri sendiri.

**Cara masuk**: Login → tombol "Masuk sebagai Akun Pengolah (Testing)" (di
bawah tombol "Masuk sebagai Akun Testing" yang sudah ada) → langsung ke UI
Pengolah terisi data mock, tanpa Firebase, tanpa form daftar.

**Isolasi dari Sumber** (supaya klaim "tidak menyentuh akun Sumber" valid):
- `SessionMode` nambah 1 value baru: `pengolahDemo` (additive, tidak ada
  switch-case lain di codebase yang exhaustive terhadap enum ini — dicek
  dulu sebelum nambah, semua pemakaian lain pakai `==` bukan `switch`).
- `lib/features/pengolah/` adalah modul baru total: shell bottom-nav
  sendiri (`PengolahShellScreen`, `IndexedStack` 5 tab manual), palet warna
  sendiri (`pengolah_colors.dart`, aksen biru `#3B82F6` sesuai referensi —
  BUKAN nambah ke `AppColors` yang dipakai Sumber), data mock sendiri
  (`data/pengolah_mock.dart`, in-memory, tidak lewat
  `fake_repositories.dart`/`repository_providers.dart` milik Sumber).
- Route `/pengolah` di `app_router.dart` berdiri sendiri
  (`parentNavigatorKey: _rootNavigatorKey`, di luar `StatefulShellRoute`
  Sumber). Redirect guard nambah satu baris: kalau `sessionMode ==
  pengolahDemo` dan lagi di halaman auth, arahkan ke `/pengolah` (bukan
  `/beranda`) — satu-satunya baris yang diubah di redirect logic lama.
- Satu-satunya file Sumber yang disentuh: `login_screen.dart` (nambah 1
  tombol baru di paling bawah, TIDAK mengubah tombol/logic yang sudah ada)
  dan `session_mode.dart` (nambah 1 enum value, additive).

**Isi UI Pengolah** (5 tab bottom nav, niru referensi HTML persis strukturnya
— data dummy, semua tombol aksi cuma snackbar/navigasi lokal, TIDAK ada
backend nyata sama sekali):
1. **Beranda** — header biru gradasi, kartu sambutan nama akun ("Bank Sampah
   Melati Bersih"), progress bar Kapasitas Gudang (72%) & Kandang Maggot BSF
   (45%), "Menu Cepat" (Lihat Dashboard/Setoran Masuk/Komunitas — pindah tab
   langsung), artikel horizontal scroll.
2. **Dashboard** — badge kategori, 2 progress bar sama seperti Beranda,
   grafik batang "Tren Setoran Mingguan" (organik vs anorganik, 7 hari, data
   statis), kartu "Insight AI Sari" gradasi hijau berisi teks insight statis
   (BUKAN panggilan Groq/Gemini asli — beda dari Insight AI Sumber yang
   sudah pakai API sungguhan).
3. **Setoran** — daftar "Perlu Dikonfirmasi" (2 item mock: Warung Bu Sri,
   Budi Santoso) dengan tombol Lihat Informasi/Terima/Tolak. "Lihat
   Informasi" push ke `PengolahSubmissionDetailScreen` (alamat, telepon,
   rincian jenis+berat, tombol Terima/Tolak juga di situ). Terima/Tolak
   cuma snackbar konfirmasi, tidak mengubah state list (tidak ada
   penyimpanan/persist, sesuai semangat "testing-only").
4. **Komunitas** — tombol "+ Buat Event / Postingan" push ke
   `PengolahCreatePostScreen` (toggle Event/Postingan, field judul/deskripsi
   + tanggal/lokasi khusus Event, tombol Publikasikan → snackbar lalu pop,
   tidak benar-benar menambah ke list). List "Event Mendatang" (1 mock) +
   kartu "Blog Edukasi" statis.
5. **Profil** — kartu identitas akun, menu "Data Kapasitas"/"Riwayat
   Transaksi"/"Pengaturan Akun" (snackbar "Segera hadir"), "Keluar" — reset
   `sessionModeProvider` ke `normal` lalu `context.go('/login')` (pola sama
   persis dengan tombol Keluar Sumber di `profil_screen.dart`, tapi
   diimplementasikan ulang lokal di `pengolah_profil_tab.dart` supaya file
   Sumber itu tidak perlu disentuh).

**Belum/tidak dikerjakan (sesuai scope "testing-only" yang diminta)**:
- Event/Komunitas/Dashboard Pengolah TETAP data mock lokal (tidak diubah di
  sesi 26 Agustus juga) — mock reset tiap restart app.
- ~~Tidak ada koneksi ke submission asli yang dibuat lewat Setor Manual/Setor
  Cerdas Sumber — dua dunia data terpisah total untuk sesi ini.~~ **SUDAH
  TERHUBUNG sejak 26 Agustus 2026** — lihat Bagian 4h, ini justru jadi fitur
  utama sesi berikutnya.
- Form Daftar Sumber masih menampilkan role card "Saya Pengolah" tapi tetap
  non-fungsional ("Segera hadir") — TIDAK diubah untuk mengarah ke fitur
  baru ini, sesuai instruksi "jangan edit akun sumber sama sekali".
- Build APK release **56.5MB**, `flutter analyze` 0 issues (lihat Bagian 2).
  (Build ini sudah ditimpa oleh build 26 Agustus, lihat Bagian 4h.)

## 4h. Pertukaran setor real-time Sumber<->Pengolah, 2 akun testing jadi identitas Firebase nyata (26 Agustus 2026)

Permintaan asli user: pakai app di **2 HP fisik** — satu login Akun Testing
(Sumber), satu login Akun Pengolah (Testing) — dan keduanya **saling
terhubung**: Sumber setor sampah, Pengolah lihat masuk & konfirmasi, kalau
setuju baru progress jalan sesuai mode pengiriman (COD/antar
langsung/dijemput) dengan kontak Pengolah ditampilkan ke Sumber, sampai
akhirnya Pengolah verifikasi kesesuaian dan **poin baru ditambahkan saat
itu** (bukan langsung saat submit) + muncul QR "berhasil setor". Kalau
Pengolah menemukan ketidaksesuaian, Sumber dapat 3 pilihan: terima koreksi
(negosiasi poin), ambil sampah kembali (batal, 0 poin), atau biarkan di
Pengolah (poin minimal). **Instruksi eksplisit user: tetap tanpa form
daftar** — tinggal tap tombol testing yang sudah ada di Login.

**Prasyarat yang diselesaikan bareng user sebelum coding**: project
Firebase `sisapedia` dibuat via `console.firebase.google.com`, `firebase-tools`
& `flutterfire_cli` diinstall, `flutterfire configure --project=sisapedia
--platforms=android,ios --overwrite-firebase-options --yes` dijalankan user
sendiri di terminal → `lib/firebase_options.dart` sekarang berisi config
ASLI (App Id android `1:645788352305:android:...`, projectId `sisapedia`).
User juga sudah aktifkan **Authentication (Email/Password)** dan **Firestore
Database** (mode test) di Console.

**Kunci arsitektur — kenapa 2 device bisa saling lihat**: sebelum sesi ini,
tombol "Akun Testing"/"Akun Pengolah (Testing)" di Login cuma set
`sessionModeProvider` lokal + swap ke `Fake*Repository` in-memory —
masing-masing device punya dunia data sendiri-sendiri, sama sekali tidak
terhubung. Sekarang (`lib/core/session/testing_accounts.dart`):
- Tiap tombol testing punya **email/password TETAP** yang di-hardcode di
  app (`kTestingSumberAccount`, `kTestingPengolahAccount`).
- `signInTestingAccount()`: coba `createUserWithEmailAndPassword` dulu
  (device PERTAMA yang tap → akun ke-create) → kalau errornya
  `email-already-in-use` (device manapun setelahnya), fallback ke
  `signInWithEmailAndPassword` — race antara 2 device tap bersamaan aman
  karena Firebase yang jamin cuma 1 create yang menang.
- Hasilnya: SEMUA device yang tap "Akun Testing Sumber" login ke UID
  Firebase Auth yang PERSIS SAMA. Begitu juga Pengolah. Firestore jadi
  medium sinkron real-time antara 2 device itu — bukan lewat mekanisme
  custom apa pun, murni manfaatin `snapshots()` stream Firestore yang
  memang sudah live secara default.
- `lib/core/providers/repository_providers.dart`: `authRepositoryProvider`/
  `submissionRepositoryProvider`/`pointsRepositoryProvider` diubah dari
  gating `sessionMode == demo` jadi gating `kPreviewMode` doang — jadi Akun
  Testing (bukan cuma akun normal) sekarang beneran pakai
  `SubmissionRepository`/`AuthRepository` Firestore asli, KECUALI build
  dengan `--dart-define=PREVIEW_MODE=true` (tetap 100% offline/Fake seperti
  dulu, untuk yang mau lihat UI tanpa Firebase).
- `main.dart`: karena Firebase Auth persist login lintas restart by design
  (beda dari `sessionModeProvider` yang selalu reset ke `normal` tiap buka
  app), ditambah pengecekan: kalau user yang keinget itu salah satu email
  akun testing → force `signOut()` di awal `main()`, biar akun testing
  tetap terasa "reset tiap restart" seperti sebelumnya, sementara akun
  normal (register asli) tetap persist login seperti mestinya.

**State machine pertukaran** (`SubmissionFlowStatus` di
`data/models/submission_model.dart`, dieksekusi oleh
`SubmissionFlowService` di `core/services/submission_flow_service.dart`):

```
menungguKonfirmasi ──Pengolah Terima──> dikonfirmasi ──Pengolah "Tandai
  │                                          │            Sudah Diterima"──┐
  └──Pengolah Tolak──> ditolakPengolah        ▼                            ▼
                                     (kontak Pengolah tampil    diterimaPengolah
                                      ke Sumber, instruksi                │
                                      beda tergantung                    ▼ (otomatis)
                                      DeliveryMode)              sedangDiverifikasi
                                                                          │
                                                        ┌─────────Sesuai──┴──Tidak Sesuai──┐
                                                        ▼                                  ▼
                                                    disetujui                    perluKeputusanSumber
                                              (poin penuh + QR)                            │
                                                                     ┌──────────┬───────────┤
                                                                     ▼          ▼           ▼
                                                          selesaiNegosiasi  ambilKembali  selesaiPoinMinimal
                                                          (poin sesuai      (dibatalkan-   (poin kecil,
                                                           koreksi + QR)     DiambilKembali,  masih dapat QR)
                                                                             0 poin, no QR)
```

- Poin ASLI baru ditambahkan (transaksi Firestore, `users/{uid}.poin_sirkular`
  via `FieldValue.increment`) di 3 titik: `disetujui`, `selesaiNegosiasi`,
  `selesaiPoinMinimal` — formula tetap `estimatedPoinFromKg()` yang sudah
  ada (`level_utils.dart`), kecuali poin minimal yang dikali 0.2 (floor 5,
  konstanta di `SubmissionFlowService`, gampang diubah kalau formula final
  beda nanti — sama semangat "estimasi sementara" seperti poin lain).
- QR (`qr_flutter`, `QrImageView`) isinya cuma string penanda
  `sisapedia-setor:{submissionId}` — ditampilkan sebagai BUKTI/RESI di
  layar Sumber, **BUKAN untuk di-scan pihak lain** (beda dari rencana awal
  user yang sempat menyebut "pengolah kasih QR, sumber scan" — setelah
  didetailkan lagi sama user, alurnya jadi verifikasi Pengolah dilakukan
  duluan lewat tombol Setujui/Tidak Sesuai, QR-nya cuma resi akhir). Jadi
  TIDAK ada fitur scan kamera QR di app ini.
- Kontak yang ditampilkan ke Sumber (nomor telepon Pengolah) di layar
  progress itu **untuk dihubungi manual** (telepon/WA sendiri di luar app)
  — sengaja tidak pasang `url_launcher`/auto-dial, sesuai permintaan user
  "nanti tinggal dihubungin secara manual".
- Notifikasi Sumber: koleksi Firestore `notifications` (uid, title, body,
  type, submission_id, read, created_at), ditulis `SubmissionFlowService`
  di TIAP transisi state. Notifikasi Pengolah: TIDAK pakai koleksi
  terpisah — cukup badge count live dari `watchIncomingQueue().length` di
  bell icon Beranda Pengolah (app ini memang belum ada push notification
  sama sekali, jadi "notifikasi" di sini semuanya cuma live-badge/live-list
  dalam app, bukan push OS).

**Composite index Firestore — dihindari, bukan di-setup**: beberapa query
lama (`watchUserSubmissions`, `watchUserTransactions`) dan yang baru
(`watchIncomingQueue`, `watchPengolahAktif`) awalnya kombinasi
`.where().orderBy()`/`.where().where()` yang butuh composite index manual
di Console (baru bisa dibuat lewat link error runtime, bukan sesuatu yang
bisa disiapkan di awal tanpa tau project id). Diputuskan SEMUA query itu
disederhanakan jadi single `.where()` + sort/filter di client — untuk
skala testing (1-2 akun, puluhan submission) ini tidak masalah performa,
dan project Firebase-nya jalan tanpa perlu klik "create index" manual sama
sekali. Kalau nanti datanya besar/production sungguhan, ini kandidat
pertama yang perlu index asli + query balik ke server-side.

**Yang SENGAJA tidak dikerjakan (di luar scope yang diminta)**:
- Foto bukti setor TETAP placeholder fake untuk akun testing (Firebase
  Storage belum di-setup user — beda service dari Firestore/Auth yang
  sudah). Kalau nanti Storage disiapkan, tinggal ubah kondisi `useFake` di
  `setor_form_screen.dart`/`foto_konfirmasi_screen.dart` dari
  `kPreviewMode || sessionMode == demo` jadi `kPreviewMode` saja.
  `koreksiKategori`/`Subtipe` (field di submission untuk koreksi Pengolah)
  ditulis servicenya tapi UI dispute form di
  `pengolah_submission_detail_screen.dart` baru expose input **berat**
  (paling sering jadi sumber ketidaksesuaian) — field jenis/kategori sudah
  ada di model & service kalau nanti mau ditambah inputnya juga.
- Firestore Security Rules MASIH mode test (izin baca/tulis terbuka,
  expire otomatis ~30 hari sejak dibuat via Console) — cukup untuk
  testing/demo, TAPI kalau project ini mau dipakai lebih dari sebulan atau
  disebar ke orang lain, WAJIB pasang rules asli (minimal: cuma
  `request.auth.uid` yang match boleh tulis submission miliknya, poin
  cuma bisa nambah lewat service tepercaya). Belum dikerjakan sesi ini —
  di luar scope, tapi risiko keamanan nyata kalau dibiarkan lewat dari
  masa berlaku test mode.
- Build APK release **57.7MB** (mode NORMAL, bukan PREVIEW_MODE — lihat
  Bagian 2 untuk kenapa mode ini yang wajib dipakai untuk fitur ini),
  `flutter analyze` 0 issues (cuma 2 info style `use_null_aware_elements`
  di `submission_flow_service.dart`, aman diabaikan).

## 4i. Bug fix: router reset ke Beranda Sumber pas masuk Akun Pengolah (26 Agustus 2026, setelah user tes di HP)

User laporkan (dengan screenshot): setelah setup Firebase beres (Bagian 4h)
dan tap "Masuk sebagai Akun Pengolah (Testing)", app malah balik nampilin
Beranda **Sumber** (bisa Setor Organik/Anorganik segala), bukan shell
Pengolah yang biru. Sempat curiga fitur Pengolah-nya nggak beneran dibuat —
ternyata bug arsitektur router, bukan UI Pengolah yang salah (UI-nya sendiri
sudah benar, cuma nggak pernah kelihatan lama).

**Root cause** (`lib/core/router/app_router.dart` + `lib/app.dart`):
`routerProvider` awalnya nge-`ref.watch(currentUidProvider)` dan
`ref.watch(sessionModeProvider)` LANGSUNG di badan provider-nya. Di Riverpod,
itu artinya tiap kali salah satu state itu berubah (misalnya pas
`sessionModeProvider` di-set ke `pengolahDemo`), Riverpod recompute seluruh
`routerProvider` dan bikinkan **objek `GoRouter` yang benar-benar baru** —
dan `MaterialApp.router` (`app.dart`) langsung pasang router baru itu.
Router baru SELALU mulai dari `initialLocation: '/splash'`, membuang semua
riwayat navigasi. Lalu `SplashScreen` (`lib/features/splash/splash_screen.dart`)
punya `Timer` yang HARDCODE `context.go('/beranda')` sesudah 1.4 detik, tanpa
tau sama sekali soal mode `pengolahDemo`. Urutannya jadi: tap tombol Pengolah
→ sessionMode berubah → GoRouter DIGANTI BARU → balik ke `/splash` → 1.4
detik kemudian Splash paksa ke `/beranda` → nyasar ke Beranda Sumber.

Ini sebenarnya bug LAMA yang sudah ada sejak `sessionModeProvider`
diperkenalkan (22 Agustus, Bagian 4b) — tapi nggak pernah ketahuan karena
tombol "Tamu"/"Akun Testing" (Sumber) TUJUANNYA juga `/beranda`, jadi
kebetulan tetap kelihatan benar meski lewat jalur yang salah. Baru
ketahuan sekarang karena Pengolah adalah alur PERTAMA yang tujuannya beda
(`/pengolah`).

**Fix** (2 bagian, saling melengkapi):
1. `app_router.dart`: `routerProvider` sekarang cuma bikin `GoRouter` **satu
   kali** (tidak lagi `ref.watch` auth/session di badan provider). State
   terbaru dibaca via `ref.read()` di dalam closure `redirect` (yang memang
   dipanggil ulang tiap navigasi oleh go_router sendiri). Supaya go_router
   tau kapan harus re-run `redirect()` tanpa bikin ulang seluruh router,
   dipasang `refreshListenable` baru: `_RouterRefreshNotifier`
   (`ChangeNotifier` yang `ref.listen` ke `currentUidProvider`/
   `sessionModeProvider` dan manggil `notifyListeners()`). ini pola standar
   go_router+Riverpod yang benar — GoRouter jadi objek stabil sepanjang
   umur app, redirect logic tetap reaktif tanpa reset navigasi.
2. `splash_screen.dart`: diubah dari `StatefulWidget` jadi
   `ConsumerStatefulWidget`, `Timer`-nya sekarang baca
   `ref.read(sessionModeProvider)` dan pilih `/pengolah` atau `/beranda`
   sesuai mode — bukan hardcode `/beranda` lagi. (Fix #1 saja sebenarnya
   sudah cukup mencegah bug ini karena `/splash` jadi cuma kelewatan
   sekali di awal app dibuka, tapi fix #2 dipasang juga sebagai lapis
   jaga-jaga untuk skenario cold-start.)

Build APK ulang setelah fix ini — **cek versi/waktu build sebelum
percaya hasil tes**, lihat Bagian 2 untuk command build terbaru.

## 4j. Box "Lihat Status Setoran Sampah" di Beranda Sumber (26 Agustus 2026)

Permintaan user setelah lihat alur progress (Bagian 4h) jalan: dari Beranda
Sumber, di bawah kartu "Wilayah Pencocokan" ditambah 1 kartu baru "Lihat
Status Setoran Sampah" — tempat lihat semua setoran (bukan cuma yang baru
saja disubmit) beserta progress-nya masing-masing sampai tahap apa, dan
kalau belum pernah setor sama sekali harus jelas kelihatan kosong (bukan
layar kosong yang bikin bingung).

- `lib/features/home/widgets/setor_actions_section.dart`: `SetorActionsSection`
  nambah parameter wajib baru `onLihatStatusSetoran` + widget
  `_StatusSetoranCard` (gaya sama seperti kartu Wilayah Pencocokan yang
  sudah ada, warna baru `AppColors.statusSetoran`/`statusSetoranSoft` —
  indigo, biar beda dari hijau/biru/oranye yang sudah dipakai).
- `lib/features/home/beranda_screen.dart`: teruskan callback ke
  `context.push('/setor/status')`.
- BARU: `lib/features/setor_manual/setoran_status_list_screen.dart` —
  `SetoranStatusListScreen`, `StreamBuilder` ke
  `submissionRepositoryProvider.watchUserSubmissions(uid)` (bukan provider
  baru, reuse yang sudah ada). Tiap item nampilin kategori/subtipe/berat +
  chip `flowStatus.label` berwarna (hijau kalau `isSuccessOutcome`, merah
  kalau `isFailureOutcome`, indigo untuk yang masih berjalan) + tanggal.
  Tap item → `context.push('/setor/sukses', extra: submission)` (reuse
  `SetorProgressScreen` yang sama persis dengan yang muncul pas submit,
  lihat Bagian 4h — bukan layar baru).
- Kalau `items.isEmpty` → `_EmptyState`: "Status Setoran: Kosong" + "Belum
  ada aktivitas setor sampah. Yuk mulai setor dari Beranda." (persis sesuai
  yang diminta user, bukan generic "no data").
- Route BARU `/setor/status` di `app_router.dart` — dideklarasikan SEBELUM
  `/setor/:kategori` (pola sama seperti `/setor/sukses`/`/setor/foto-konfirmasi`,
  lihat catatan bug 24 Agustus tentang urutan route literal vs wildcard).

## 4k. Revisi setelah user coba di HP (26 Agustus 2026): stat Pengolah generik, artikel bisa dibuka, timeline diperbaiki, alur "tidak sesuai" disederhanakan

Empat revisi terpisah dari user setelah lihat build sebelumnya jalan:

**1. Kartu "Kandang Maggot BSF" diganti — tidak generik untuk semua Pengolah.**
User benar: nggak semua Pengolah punya unit maggot BSF (bank sampah biasa,
pengepul, dsb juga pakai role Pengolah yang sama). Diganti jadi
**"Menunggu Verifikasi"** — angka LIVE (bukan skala %) dari Firestore, hitung
submission milik Pengolah ini yang `flowStatus`-nya `diterimaPengolah` atau
`sedangDiverifikasi`. Berlaku di 2 tempat sekaligus (Beranda & Dashboard
Pengolah, keduanya sebelumnya duplikat kartu yang sama):
- BARU: `lib/features/pengolah/pengolah_providers.dart` —
  `pengolahIncomingQueueCountProvider` (dipindah dari private provider lama
  di `pengolah_beranda_tab.dart`) + `pengolahMenungguVerifikasiCountProvider`
  (BARU), dipakai bareng oleh Beranda & Dashboard supaya query Firestore-nya
  tidak duplikat.
- `pengolah_beranda_tab.dart`: `_CapacityRow` jadi `ConsumerWidget`, kartu
  kedua ganti jadi `_CountCard` (angka besar, bukan progress bar).
- `pengolah_dashboard_tab.dart`: sama, `_MiniStat` kedua diganti `_CountStat`.
  Badge chip judul juga diganti dari "Bank Sampah & Maggot BSF" jadi
  **"Mitra Pengolah Sampah"** (generik, akar masalah yang sama).
- Kartu pertama ("Kapasitas Gudang") TIDAK diubah — user cuma keberatan
  soal yang maggot-spesifik.

**2. Artikel "Seputar Pengolah" sekarang bisa dibuka.**
Sebelumnya 3 kartu artikel di Beranda Pengolah cuma dekorasi (tidak ada
`onTap` sama sekali) — bug murni, bukan desain sengaja.
- BARU: `lib/features/pengolah/data/pengolah_articles.dart` —
  `PengolahArticle` (title/readTime/paragraphs) + 3 artikel lengkap
  isinya sesuai judul yang sudah ada persis ("Smart Bin: Sensor Kapasitas
  Gudang Otomatis", "Optimalkan Kandang Maggot BSF dengan IoT" — ini cuma
  ARTIKEL EDUKASI opsional, bukan klaim akun ini punya unit maggot, jadi
  tetap dipertahankan sebagai salah satu topik, "5 Strategi Bank Sampah
  Naikkan Setoran").
- BARU: `lib/features/pengolah/widgets/pengolah_article_detail_screen.dart`
  — layar baca sederhana (judul + meta + paragraf).
- `pengolah_beranda_tab.dart`: `_ArticleCard` sekarang terima `onTap`,
  dibungkus `InkWell`, push ke detail screen dengan artikel yang sesuai.

**3. Label tahapan Progress Setoran diperbaiki.**
Bug murni: label di `_StageTimeline` (`setor_progress_screen.dart`) sebelumnya
hasil `_stages[i].label.split(' ').first` — cuma ambil KATA PERTAMA dari
label lengkap `SubmissionFlowStatus`, jadi kelihatan ngaco ("Menunggu",
"Disetujui", "Sampah", "Sedang" — padahal maksudnya beda tahap). Diperbaiki
sesuai yang diminta user: **Menunggu → Disetujui → Diverifikasi → Selesai**,
4 label tetap (`_stageLabels`, bukan potongan dari label lain) + fungsi
`_stageIndexFor()` yang eksplisit map tiap `SubmissionFlowStatus` ke salah
satu dari 4 tahap itu. Timeline sekarang SELALU tampil (dulu disembunyikan
total begitu status terminal) — tahap ke-4 "Selesai" ikut nyala/dicentang,
warnanya beda kalau outcome-nya gagal (merah) vs poin minimal (oranye) vs
sukses penuh (hijau), lihat `_StageTimeline`.

**4. Alur "Tidak Sesuai" disederhanakan — dikonfirmasi lewat AskUserQuestion.**
Spesifikasi ASLI (Bagian 4h) kasih Sumber 3 pilihan begitu Pengolah bilang
"Tidak Sesuai": terima koreksi/ambil kembali/biarkan poin minimal. Setelah
user coba alurnya, mereka minta simplifikasi jadi cuma **2 output**: (1)
Pengolah setuju → poin penuh + QR "berhasil disetor", (2) Pengolah bilang
tidak sesuai → **otomatis** "setor tidak berhasil" tapi Sumber tetap dapat
poin sedikit (karena sampah sudah fisik berpindah tangan) — TANPA Sumber
perlu pilih apa-apa lagi. Karena ini mengubah balik sebagian dari apa yang
diminta di pesan sebelumnya, saya konfirmasi dulu lewat AskUserQuestion —
user pilih opsi simple (otomatis), bukan tetap pertahankan 3 pilihan.

Perubahan kode (penyederhanaan besar, banyak yang dihapus bersih — bukan
dibiarkan jadi dead code):
- `SubmissionFlowStatus` (`submission_model.dart`): `perluKeputusanSumber`,
  `selesaiNegosiasi`, `dibatalkanDiambilKembali` DIHAPUS dari enum (bukan
  cuma berhenti dipakai). Yang tersisa: `menungguKonfirmasi → dikonfirmasi →
  diterimaPengolah → sedangDiverifikasi → {disetujui | selesaiPoinMinimal |
  ditolakPengolah}`. Getter baru `isPartialOutcome` (khusus
  `selesaiPoinMinimal`) dipisah dari `isSuccessOutcome` (sekarang cuma
  `disetujui`) — supaya UI bisa bedakan "sukses penuh+QR" vs "tidak
  berhasil tapi tetap dapat sedikit poin, TANPA QR".
- `NegosiasiKeputusan` enum DIHAPUS total. Field `koreksiKategori`/
  `koreksiSubtipe`/`koreksiBeratKg` DIHAPUS dari `SubmissionModel` (tidak
  ada lagi yang butuh "angka koreksi" karena tidak ada negosiasi) —
  `catatanVerifikasi` (alasan Pengolah) tetap ada, masih dipakai.
- `SubmissionFlowService`: `disputeVerifikasi()` + `resolveNegosiasi()`
  (2 method) DIGABUNG jadi 1 method baru **`rejectVerifikasi({submissionId,
  catatan})`** — transaksi Firestore langsung set `selesaiPoinMinimal` +
  kredit poin minimal (formula sama seperti sebelumnya: `estimatedPoinFromKg()
  * 0.2`, floor 5), tanpa tahap `perluKeputusanSumber` di tengah.
- `pengolah_submission_detail_screen.dart`: form "Tidak Sesuai" Pengolah
  disederhanakan — cuma field catatan (field "Berat menurutmu" dihapus,
  karena tidak ada lagi yang menghitung ulang poin dari angka koreksi).
- `setor_progress_screen.dart`: `_NegosiasiCard` (widget 3-tombol) DIHAPUS
  total, diganti `_PartialCard` (baru) — tampilan read-only "Setor Tidak
  Berhasil" + alasan Pengolah + poin minimal yang sudah masuk, TANPA QR
  (beda dari `_SuccessCard` yang tetap pakai QR).
- QR payload (`submission_flow_service.dart`) diganti jadi
  `SISAPEDIA-BERHASIL-DISETOR:{id}` (dari `sisapedia-setor:{id}`) — biar
  isi QR-nya eksplisit "berhasil disetor" sesuai yang diminta user, cuma
  dipakai untuk outcome `disetujui` (bukan `selesaiPoinMinimal`).

Build APK ulang setelah semua revisi ini — cek Bagian 2 untuk command
build terbaru, jangan percaya hasil tes dari APK versi sebelum tanggal ini.

## 5. Yang BELUM dikerjakan / diketahui terbatas

- Role **Pengolah** sekarang punya UI testing-only (lihat Bagian 4g) — akun
  demo lokal, data mock, TIDAK ada backend/Firestore/auth nyata untuk role
  ini. Role **DLH-Admin** masih belum ada sama sekali (README asli sudah
  menyebut ini dari awal, bukan regresi sesi ini).
- Form "Gabung Event" baru mengirim ke `joinEvent()` yang sama seperti
  sebelumnya (menandai partisipasi), belum benar-benar mengalirkan data
  Nama/Kontak/Motivasi ke sisi akun Pengolah — itu memang ditunda sesuai
  instruksi user ("tapi nanti aja").
- Redeem poin ke e-wallet/voucher tetap tidak memproses uang nyata (dari
  awal, lihat `README.md`).
- Setor Cerdas (voice) masih pakai `WasteVoiceParser` berbasis regex, BUKAN
  Groq — ini berbeda dari `SariChatScreen` yang baru (chat teks) yang
  sudah pakai Groq API sungguhan.
- Batas kota di peta cuma garis Kota Semarang, belum ada garis
  kecamatan/versi multi-kota (proposal DSDC menyebut visi nasional, tapi
  implementasi tetap Semarang-only per desain phase 1).
- Login "Nomor HP atau Email" cuma label ikut mockup — field & validasinya
  masih murni email (belum ada login/OTP nomor HP sungguhan).
- "Lupa kata sandi?" di Login belum ada alurnya (baru snackbar "Segera
  hadir"), belum reset password Firebase sungguhan.
- Estimasi poin di layar sukses setor (`beratKg * 10`, dibulatkan) itu
  formula sementara untuk preview UX — belum tentu sama dengan formula poin
  final yang dipakai proses verifikasi admin (kalau nanti beda, cukup ubah
  `_estimatedPoin()` di `setor_success_screen.dart`).
- Akun "Tamu" & "Akun Testing" cuma state lokal di memori (`sessionModeProvider`),
  reset otomatis ke `normal` tiap kali tombol "Keluar" di Profil ditekan atau
  app di-restart — belum ada persist ke local storage.
- Ada branch `origin/dev` di remote yang sama isinya rombakan besar (backend
  Supabase, role Pengolah/DLH-Admin, dst — lihat Bagian 4e) dari orang lain
  di luar sesi-sesi Claude ini. `master` sudah cherry-pick bagian amannya
  saja per keputusan user 23 Agustus 2026; `dev` dibiarkan apa adanya, tidak
  disentuh/dihapus. Kalau nanti mau full-merge (ganti ke Supabase +
  ekspansi role), itu keputusan besar terpisah, belum dilakukan.
- **Format `GEMINI_API_KEY_1` yang diisi user (23-24 Agustus 2026) tidak
  biasa** — polanya (`AQ.Ab8RN6...`, 53 karakter) beda dari format API key
  Gemini standar Google AI Studio (biasanya `AIzaSy...`). User bilang itu
  valid, jadi tetap dipakai apa adanya — tapi kalau nanti Mode Foto Cerdas
  error 401/403 terus di build normal (bukan demo), ini kandidat pertama
  yang dicek. Cek ulang di aistudio.google.com/apikey kalau perlu.
- Firebase Storage (`photo_upload_service.dart`) butuh project Firebase
  BENERAN sudah dikonfigurasi (`flutterfire configure`, lihat Bagian 6) buat
  upload foto bukti/foto deteksi jalan di build normal (non-demo, non-preview)
  — `firebase_options.dart` masih placeholder per catatan lama, jadi upload
  foto di jalur akun asli belum bisa dites sampai itu disiapkan.
- Estimasi jumlah item dari Gemini Vision (`estimasi_jumlah`) cuma
  ditampilkan sebagai info tambahan di layar Validasi Hasil AI, tidak
  dipakai buat hitung apa pun (poin/berat tetap murni dari input manual user).
- Ikon app (`assets/icon/app_icon*.png`) hasil recreate manual
  (`scripts/gen_icon.py`), BUKAN file asli dari user (belum pernah di-share
  sebagai file, cuma gambar di chat) — dipakai baik untuk ikon launcher
  maupun logo di dalam app (splash/login/Beranda, lihat Bagian 4d). Kalau
  user kirim file PNG logo aslinya nanti, timpa
  `assets/icon/app_icon.png` + `app_icon_foreground.png`, jalankan ulang
  `dart run flutter_launcher_icons`, lalu `flutter build apk --release` —
  otomatis ke-apply ke semua tempat karena satu file yang sama dipakai di
  mana-mana (lihat Bagian 4c & 4d).

## 6. Config yang HARUS disiapkan manual (tidak bisa dikerjakan AI)

Sama seperti di `README.md`, dua hal ini butuh akun pribadi:

1. ~~**Firebase** — `flutterfire configure`, aktifkan Authentication
   (Email/Password) + Firestore.~~ **SUDAH BERES per 26 Agustus 2026** —
   project `sisapedia` sudah dikonfigurasi user sendiri lewat
   `firebase-tools`/`flutterfire_cli` (login akun Google user),
   `firebase_options.dart` sudah berisi config asli, Authentication +
   Firestore sudah aktif. Kalau
   pindah/clone repo baru dan mau pakai project Firebase LAIN, jalankan
   ulang `flutterfire configure --project=<id-baru> --platforms=android,ios
   --overwrite-firebase-options --yes` (lihat Bagian 4h untuk kronologi
   lengkap perintahnya). Firestore Security Rules MASIH mode test
   (expire ~30 hari dari saat dibuat) — lihat catatan keamanan di Bagian 4h.
2. **Groq API key** — daftar di console.groq.com, isi `.env` dari
   `.env.example`. Tanpa ini pun app tetap jalan (baik mode preview maupun
   normal), Insight AI dan Sari Chat cuma fallback ke pesan/jawaban mock.
3. **Gemini API key** (BARU 24 Agustus 2026) — buat fitur "Setor Cerdas
   Mode Foto". Isi `GEMINI_API_KEY_1` di `.env` (opsional `_2`/`_3` buat
   fallback rate-limit). Tanpa ini, Mode Foto Cerdas di build normal bakal
   error "Belum ada GEMINI_API_KEY_1/2/3 yang diatur" — tapi lewat login
   "Akun Testing" atau build `PREVIEW_MODE=true` tetap jalan pakai
   `FakeGeminiVisionService` (data dummy, tanpa API key sama sekali).

`.env` sudah di-gitignore, jangan pernah commit isinya. Key yang sudah
diisi user (`GEMINI_API_KEY_1`) cuma ada di file `.env` lokal masing-masing
mesin — kalau pindah/clone repo baru, isi ulang manual.

## 7. Cara lanjut kerja di sesi berikutnya

1. Baca file ini dulu.
2. `git log --oneline` untuk lihat checkpoint terakhir sebelum mulai edit.
3. `flutter analyze` sebelum dan sesudah perubahan besar.
4. Build APK preview mode untuk validasi visual (Bagian 2), atau
   `flutter run --dart-define=PREVIEW_MODE=true` kalau ada device/emulator
   terhubung untuk iterasi lebih cepat.
5. Kalau bikin perubahan berarti, commit ke git (`git add lib/ && git
   commit`) supaya ada checkpoint baru yang bisa di-rollback.
