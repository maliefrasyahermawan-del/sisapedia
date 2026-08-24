# SisaPedia — Progress Save Point

> Dokumen ini dibaca dulu di sesi baru sebelum menyentuh kode. Isinya: cara
> build/extract APK, peta file penting, keputusan desain sesi ini, dan config
> yang perlu disiapkan manual. Update terakhir: **24 Agustus 2026** (fitur
> "Setor Cerdas Mode Foto" pakai Gemini Vision — lihat Bagian 4f).

## 1. Status singkat

Fase 1 — role **Sumber** (warga/pemilah sampah) saja. Role Pengolah &
DLH-Admin belum dikerjakan (lihat Bagian 5). Register sudah punya UI pilihan
role ("Saya Sumber" / "Saya Pengolah") tapi "Saya Pengolah" sengaja
non-fungsional ("Segera hadir") — semua akun baru tetap terdaftar sebagai
Sumber.

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
  sendiri (lihat `README.md` Bagian "Setup wajib").
- **Mode Preview** (`PREVIEW_MODE=true`): jalan 100% dari data mock di
  `lib/core/preview/preview_mode.dart`, tidak butuh Firebase/Groq sama
  sekali. **Ini mode yang dipakai untuk semua APK yang sudah di-generate dan
  divalidasi di sesi-sesi sebelumnya.**

```bash
cd "D:\Portofolio Alif 2\Project 55 - SisaPedia Mobile App"
flutter pub get
flutter analyze --no-fatal-infos      # pastikan bersih sebelum build
flutter build apk --release --dart-define=PREVIEW_MODE=true
```

Hasil APK selalu di path yang sama (build ulang menimpa file lama):

```
build\app\outputs\flutter-apk\app-release.apk
```

Build terakhir (24 Agustus 2026, setelah fitur Setor Cerdas Mode Foto +
upgrade Setor Manual): **57.2MB**, berhasil, `flutter analyze` bersih (0
issues). Ada 1 warning Gradle soal Kotlin Gradle Plugin (`firebase_storage`,
`speech_to_text`) — tidak fatal, aman diabaikan untuk saat ini.

> Catatan: login "Masuk sebagai Akun Testing" (Bagian 4) sekarang jadi cara
> paling gampang untuk lihat app terisi data mock **tanpa** perlu build
> `--dart-define=PREVIEW_MODE=true` — cukup build/`flutter run` mode normal
> lalu tekan tombol itu di layar Login. `PREVIEW_MODE` compile-time tetap ada
> dan tidak berubah perilakunya (dipakai kalau mau APK yang *selalu* mock
> dari awal buka app, tanpa harus lewat tombol Login).

Untuk jalan langsung ke device/emulator tanpa build APK:
```bash
flutter run --dart-define=PREVIEW_MODE=true
```

## 3. Peta file penting

```
lib/
  app.dart                          — root MaterialApp.router (banner PRATINJAU sudah dihapus)
  main.dart                         — entrypoint, load .env, init Firebase (dilewati kalau PREVIEW_MODE)
  core/
    preview/
      fake_repositories.dart        — BARU (22 Agt): semua kelas Fake*Repository + data mock,
                                       dipindah keluar dari preview_mode.dart supaya bisa dipakai
                                       runtime (login Akun Testing) TANPA circular import
      preview_mode.dart             — sekarang cuma `kPreviewMode` flag + `previewModeOverrides`
                                       (compile-time), datanya sendiri ada di fake_repositories.dart
    session/                        — BARU (22 Agt): infra login Tamu/Akun Testing
      session_mode.dart             — `SessionMode` enum (normal/guest/demo) + `sessionModeProvider`
                                       + `kGuestUid`/`guestUserModel`
      guest_gate.dart                — dialog "Anda Belum Terdaftar" dipakai saat tamu coba setor
    utils/level_utils.dart          — BARU (22 Agt): `LevelProgress.fromPoin()`, hitung level/ring
                                       progress dari poinSirkular (presentasi saja, tiap 2000 poin
                                       naik 1 level) — dipakai kartu poin Beranda & layar sukses setor
    providers/
      data_providers.dart           — provider Riverpod untuk articles/partners/events/dashboard
      notification_providers.dart   — state notifikasi (seed + markAllRead)
      repository_providers.dart     — tiap repo provider sekarang cek `sessionModeProvider`: demo
                                       → Fake*Repository (dari fake_repositories.dart), guest →
                                       `userProfileProvider` balik `guestUserModel` langsung, normal
                                       → repository Firestore asli
    router/app_router.dart          — redirect guard sekarang juga cek sessionMode (tamu/demo lolos
                                       tanpa uid Firebase asli); route BARU: /setor/sukses,
                                       /setor/foto-konfirmasi. **PENTING (bug fix 24 Agt)**: route
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
                                       waste_detection_result.dart BARU: WasteDetectionResult +
                                       WasteConfidence enum, dipakai GeminiVisionService
    repositories/                   — implementasi asli (Firestore), dipakai kalau sessionMode normal
  features/
    home/
      beranda_screen.dart           — uid Beranda sekarang fallback ke `kGuestUid` saat tamu supaya
                                       layar tidak stuck loading
      widgets/beranda_header.dart   — REDESIGN (22 Agt): gradasi hijau, salam berbasis jam
                                       (pagi/siang/sore/malam), sesuai referensi desain
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
                                       (mode pengiriman/alamat/jadwal/catatan) ditambahkan di sini
      setor_success_screen.dart     — layar sukses full-screen, estimasi poin (`estimatedPoinFromKg()`
                                       di `level_utils.dart`, BUKAN lagi private di file ini) +
                                       status "menunggu verifikasi"
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
                                       sebagai Tamu" dan "Masuk sebagai Akun Testing"
      register_screen.dart          — REDESIGN (22 Agt) sesuai referensi HTML + role card "Saya
                                       Sumber"/"Saya Pengolah" (Pengolah non-fungsional, lihat Bag. 1)
    map/peta_screen.dart            — peta interaktif, PolygonLayer garis merah batas Semarang
    wilayah/wilayah_pencocokan_screen.dart  — alternatif list (bukan peta) untuk pilih mitra
    sari_chat/sari_chat_screen.dart — layar chat penuh dengan Sari (pakai GroqService.chat)
    notifications/notifications_screen.dart
    articles/article_detail_screen.dart
    profile/
      panduan_screen.dart           — accordion 7 bagian panduan lengkap
      profil_screen.dart            — tombol Keluar sekarang reset sessionMode ke normal juga
                                       (bukan cuma signOut Firebase), supaya tamu/akun testing bisa
                                       "keluar" balik ke Login sungguhan
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

## 5. Yang BELUM dikerjakan / diketahui terbatas

- Role **Pengolah** dan **DLH-Admin** belum ada sama sekali (README asli
  sudah menyebut ini dari awal, bukan regresi sesi ini).
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

1. **Firebase** — `flutterfire configure`, aktifkan Authentication
   (Email/Password) + Firestore. Cuma perlu kalau mau jalan di mode
   normal (non-preview).
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
