# SisaPedia — Progress Save Point

> Dokumen ini dibaca dulu di sesi baru sebelum menyentuh kode. Isinya: cara
> build/extract APK, peta file penting, keputusan desain sesi ini, dan config
> yang perlu disiapkan manual. Ditulis per **19 Agustus 2026**.

## 1. Status singkat

Fase 1 — role **Sumber** (warga/pemilah sampah) saja. Role Pengolah &
DLH-Admin belum dikerjakan (lihat Bagian 5).

Checkpoint git: lihat `git log --oneline -3`. Commit terakhir mencakup semua
patch UI/UX sesi 19 Agustus 2026 (lihat Bagian 4).

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

Build terakhir: **55.3MB**, berhasil, 0 analyzer issues. Ada 1 warning
Gradle soal Kotlin Gradle Plugin (`firebase_storage`, `speech_to_text`) —
tidak fatal, aman diabaikan untuk saat ini.

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
    preview/preview_mode.dart       — SEMUA data mock (user, submissions, partners, articles,
                                       events, FakeGroqService.chat) — edit di sini kalau mau
                                       ubah data yang muncul di build preview
    providers/
      data_providers.dart           — provider Riverpod untuk articles/partners/events/dashboard
      notification_providers.dart   — state notifikasi (seed + markAllRead), BARU sesi ini
      repository_providers.dart     — wiring repository asli vs fake (lewat preview override)
    router/app_router.dart          — semua route go_router, termasuk 3 route BARU:
                                       /artikel/:id, /notifikasi, /wilayah-pencocokan, /sari-chat
    services/groq_service.dart      — GroqService.chat() BARU (chat Sari penuh, terpisah dari
                                       generateInsight() yang lama untuk Insight AI Dashboard)
    theme/                          — app_colors.dart, app_text_styles.dart, app_theme.dart
  data/
    geo/semarang_boundary.dart      — BARU: 194 titik lat/lng batas administratif Kota Semarang
                                       (dari OSM/Nominatim, disederhanakan RDP eps=0.0012)
    models/                         — semua model data (ArticleModel.content sudah diisi mock)
    repositories/                   — implementasi asli (Firestore), dipakai kalau bukan preview
  features/
    home/beranda_screen.dart        — layar utama, sudah SafeArea + bell notifikasi + tanpa overlap bug
    map/peta_screen.dart            — peta interaktif, sekarang ada PolygonLayer garis merah Semarang
    wilayah/wilayah_pencocokan_screen.dart  — BARU: alternatif list (bukan peta) untuk pilih mitra
    sari_chat/sari_chat_screen.dart — BARU: layar chat penuh dengan Sari (pakai GroqService.chat)
    notifications/notifications_screen.dart — BARU
    articles/article_detail_screen.dart     — BARU
    profile/panduan_screen.dart     — BARU: accordion 7 bagian panduan lengkap
    shared/widgets/bottom_nav_scaffold.dart — FAB "Sari" mengambang di semua tab BARU di sini
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
