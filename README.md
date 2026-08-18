# SisaPedia

Aplikasi mobile Flutter untuk pengelolaan sampah sirkular — lomba DSDC Undip.

**Status saat ini**: Phase 1 — role **Sumber** (warga/pemilah sampah) saja. Role
Pengolah & DLH-Admin belum dikerjakan.

## Fitur

- Login/Register (Firebase Auth)
- Beranda: Poin Sirkular, Setor Cerdas (voice AI), Setor manual (Organik/Anorganik),
  Wilayah Pencocokan, redeem poin, artikel, Movement, riwayat setoran
- **Setor Cerdas**: speech-to-text nyata (`speech_to_text`, locale `id_ID`) +
  parsing kata kunci Bahasa Indonesia untuk deteksi jenis & berat sampah
- Peta Pencocokan: peta interaktif OpenStreetMap (`flutter_map`) menampilkan
  mitra pengolah (Bank Sampah, Maggot BSF, Pengepul, Pengompos)
- Dashboard: statistik dampak sirkular, grafik tren bulanan, breakdown kategori,
  dan **Insight AI** yang digenerate lewat Groq API
- Profil: info akun, poin, halaman statis, logout

## Setup wajib sebelum menjalankan app

Dua hal ini **tidak bisa disiapkan oleh AI**, karena butuh login akun kamu sendiri:

### 1. Firebase

1. Install FlutterFire CLI (sekali saja): `dart pub global activate flutterfire_cli`
2. Buat project baru di [console.firebase.google.com](https://console.firebase.google.com)
3. Di folder project ini, jalankan:
   ```bash
   flutterfire configure
   ```
   Login dengan akun Google kamu, pilih project Firebase yang baru dibuat, pilih
   platform Android (dan iOS jika perlu). Perintah ini akan **menimpa**
   `lib/firebase_options.dart` (yang saat ini masih placeholder) dengan config asli.
4. Di Firebase Console, aktifkan:
   - **Authentication** → Sign-in method → Email/Password
   - **Firestore Database** → Create database (mode production atau test, sesuaikan)

### 2. Groq API key (untuk Insight AI "Sari")

1. Buat API key di [console.groq.com](https://console.groq.com)
2. Copy `.env.example` menjadi `.env`, lalu isi:
   ```
   GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxx
   ```
   File `.env` sudah di-gitignore, jadi aman dari commit.

Tanpa Groq key, app tetap jalan normal — kartu "Insight AI Sari" di Dashboard
akan menampilkan pesan bahwa Groq belum dikonfigurasi.

### 3. Seed data contoh (opsional, biar app tidak kosong)

Tambahkan manual di Firestore Console beberapa dokumen contoh:

- **`partners`**: `{ nama, tipe: "bankSampah"|"maggotBsf"|"pengepul"|"pengompos", lat, lng, kapasitas_tersedia, kapasitas_total, kategori_diterima: [...] }`
- **`articles`**: `{ title, summary, content, read_time_minutes }`
- **`movement_events`**: `{ title, organizer, date (timestamp), location }`

## Menjalankan app

```bash
flutter pub get
flutter run
```

Pastikan device/emulator Android sudah terhubung (`flutter devices` untuk cek).

## Batasan yang disengaja (bukan bug)

- Redeem poin ke e-wallet (Dana/OVO) dan voucher **tidak memproses uang nyata** —
  hanya mencatat permintaan (`points_transactions` dengan status `pending_redeem`)
  untuk ditindaklanjuti admin secara manual.
- Setor Cerdas pakai parsing regex/keyword, bukan LLM, supaya tidak butuh koneksi
  API tiap kali. Kalau parsing perlu ditingkatkan, ganti implementasi
  `WasteVoiceParser` di `lib/core/services/waste_voice_parser.dart` dengan versi
  yang memanggil Groq API (interface sudah disiapkan untuk itu).
- Role Pengolah & DLH-Admin belum diimplementasi — menyusul di sesi berikutnya.
