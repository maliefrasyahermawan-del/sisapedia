# SisaPedia Android Demo v1.0.1+2

Release APK untuk demo juri dengan Preview Mode dan Sari OmniRoute live-first.

- File: `SisaPedia-v1.0.1-demo.apk`
- SHA-256: `2EFEB0ED62841298A25BA8F238A855682809D3297C7883FA611071DCFC3C0B87`
- Package: `com.sisapedia.sisapedia`
- Signing: APK Signature Scheme v2
- Preview OTP: `246810`

Perubahan sejak v1.0.0 demo:

- Daftar semua artikel dan navigasi detail yang berfungsi.
- Reset password melalui Supabase dengan fallback Preview deterministik.
- Flow OTP nomor HP dua tahap dengan validasi dan feedback error.
- Bukti timbang Pengolah dapat memakai foto galeri atau sample demo.

Sari memakai konfigurasi compile-time `OMNIROUTE_APP_SECRET`,
`OMNIROUTE_BASE_URL`, dan `OMNIROUTE_MODEL`, serta fallback lokal ketika
tunnel tidak tersedia.
