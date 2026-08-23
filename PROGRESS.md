# SisaPedia — Progress Save Point

> Dokumen ini dibaca dulu di sesi baru sebelum menyentuh kode. Isinya: cara
> build/extract APK, peta file penting, keputusan desain sesi ini, dan config
> yang perlu disiapkan manual. Update terakhir: **22 Agustus 2026**.

## 1. Status singkat

Fase 1 — role **Sumber** (warga/pemilah sampah) saja. Role Pengolah &
DLH-Admin belum dikerjakan (lihat Bagian 5). Register sudah punya UI pilihan
role ("Saya Sumber" / "Saya Pengolah") tapi "Saya Pengolah" sengaja
non-fungsional ("Segera hadir") — semua akun baru tetap terdaftar sebagai
Sumber.

Checkpoint git: lihat `git log --oneline -3`. Dua commit terakhir sama-sama
dari sesi **22 Agustus 2026**: (1) redesign Beranda header/kartu poin +
layar sukses setor + Login/Daftar sesuai referensi desain + login
"Tamu"/"Akun Testing" baru, lalu (2) patch susulan — fix bug kartu poin
ketutup header, warna box kategori setor, ganti ikon app + nama app jadi
"SisaPedia" (lihat Bagian 4 & 4b).

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

Build terakhir (22 Agustus 2026, mode normal/non-preview, setelah patch
susulan ikon+warna+bugfix): **56.1MB**, berhasil, `flutter analyze` bersih
(0 issues). Ada 1 warning Gradle soal Kotlin Gradle Plugin
(`firebase_storage`, `speech_to_text`) — tidak fatal, aman diabaikan untuk
saat ini.

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
                                       tanpa uid Firebase asli); route BARU: /setor/sukses
    services/groq_service.dart      — GroqService.chat() (chat Sari penuh, terpisah dari
                                       generateInsight() untuk Insight AI Dashboard)
    theme/                          — app_colors.dart (+ accent700/800/900, levelBadge BARU),
                                       app_text_styles.dart, app_theme.dart
  data/
    geo/semarang_boundary.dart      — 194 titik lat/lng batas administratif Kota Semarang
                                       (dari OSM/Nominatim, disederhanakan RDP eps=0.0012)
    models/                         — semua model data (ArticleModel.content sudah diisi mock)
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
                                       (dulu cuma snackbar+pop)
      setor_success_screen.dart     — BARU (22 Agt): layar sukses full-screen, estimasi poin +
                                       status "menunggu verifikasi" (BUKAN angka final, karena poin
                                       asli baru masuk setelah admin verifikasi submission)
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
    shared/widgets/bottom_nav_scaffold.dart — FAB "Sari" mengambang di semua tab (mic nonaktif
                                       otomatis untuk tamu, karena uid Firebase asli null)
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
- Ikon app (`assets/icon/app_icon*.png`) hasil recreate manual
  (`scripts/gen_icon.py`), BUKAN file asli dari user (belum pernah di-share
  sebagai file, cuma gambar di chat) — lihat Bagian 4c kalau mau ganti pakai
  file PNG asli.

## 6. Config yang HARUS disiapkan manual (tidak bisa dikerjakan AI)

Sama seperti di `README.md`, dua hal ini butuh akun pribadi:

1. **Firebase** — `flutterfire configure`, aktifkan Authentication
   (Email/Password) + Firestore. Cuma perlu kalau mau jalan di mode
   normal (non-preview).
2. **Groq API key** — daftar di console.groq.com, isi `.env` dari
   `.env.example`. Tanpa ini pun app tetap jalan (baik mode preview maupun
   normal), Insight AI dan Sari Chat cuma fallback ke pesan/jawaban mock.

`.env` sudah di-gitignore, jangan pernah commit isinya.

## 7. Cara lanjut kerja di sesi berikutnya

1. Baca file ini dulu.
2. `git log --oneline` untuk lihat checkpoint terakhir sebelum mulai edit.
3. `flutter analyze` sebelum dan sesudah perubahan besar.
4. Build APK preview mode untuk validasi visual (Bagian 2), atau
   `flutter run --dart-define=PREVIEW_MODE=true` kalau ada device/emulator
   terhubung untuk iterasi lebih cepat.
5. Kalau bikin perubahan berarti, commit ke git (`git add lib/ && git
   commit`) supaya ada checkpoint baru yang bisa di-rollback.
