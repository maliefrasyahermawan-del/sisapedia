import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class _PanduanSection {
  final String title;
  final List<String> points;
  const _PanduanSection(this.title, this.points);
}

const _sections = [
  _PanduanSection('Registrasi', [
    'Daftar pakai email dan buat kata sandi, lalu lengkapi nama di halaman Profil.',
    'Setiap akun baru otomatis berperan sebagai Sumber (warga/pemilah sampah).',
    'Poin Sirkular mulai dari 0 dan bertambah setiap setoranmu diverifikasi mitra.',
  ]),
  _PanduanSection('Pickup Sampah', [
    'Pilih Setor Organik atau Setor Anorganik di Beranda, isi jenis dan berat sampah.',
    'Pilih mitra terdekat lewat Wilayah Pencocokan, lalu ajukan pencocokan.',
    'Mitra akan menjadwalkan penjemputan sesuai kapasitas dan wilayah kerjanya.',
    'Status setoran berubah dari Menunggu menjadi Terverifikasi setelah mitra mengecek beratnya.',
  ]),
  _PanduanSection('Drop Off Sampah', [
    'Kalau mitra tidak melayani penjemputan, kamu bisa antar langsung ke lokasinya.',
    'Cek alamat dan jam operasional mitra lewat Wilayah Pencocokan sebelum berangkat.',
    'Sampah anorganik sebaiknya sudah dipilah dan dibersihkan sebelum diantar.',
  ]),
  _PanduanSection('Company dan Event', [
    'Menu Movement menampilkan event komunitas yang diadakan mitra pengolah di sekitarmu.',
    'Tekan Gabung untuk mendaftar, isi data kontak dan motivasimu di formulir yang muncul.',
    'Pendaftaranmu dikirim ke akun pengolah penyelenggara untuk ditinjau lebih lanjut.',
  ]),
  _PanduanSection('Menjadi Mitra', [
    'Bank sampah, pengompos, peternak maggot BSF, dan pengepul bisa mendaftar jadi mitra.',
    'Mitra baru perlu disetujui Admin sebelum muncul di Wilayah Pencocokan dan Peta.',
    'Hubungi narahubung SisaPedia lewat menu Tentang untuk proses pendaftaran mitra.',
  ]),
  _PanduanSection('Poin dan Level Sirkular', [
    'Setiap setoran terverifikasi menambah Poin Sirkular sesuai kategori dan berat sampah.',
    'Poin bisa ditukar jadi saldo e-wallet (Dana/OVO) mulai 500 poin, atau voucher mitra.',
    'Level personal naik bertahap seiring akumulasi poin, dan menentukan posisimu di leaderboard kota.',
  ]),
  _PanduanSection('Jenis dan Harga Sampah', [
    'Organik: sisa dapur, sayur, buah, dan ampas kopi, diproses jadi kompos atau pakan maggot BSF.',
    'Anorganik: plastik, kertas, dan logam, disalurkan ke pengepul atau industri daur ulang.',
    'Harga acuan anorganik ditampilkan mitra dan diperbarui berkala, bukan harga pasar waktu nyata.',
  ]),
];

class PanduanScreen extends StatelessWidget {
  const PanduanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Panduan')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _sections.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final section = _sections[i];
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(section.title, style: AppTextStyles.bodyBold),
              iconColor: AppColors.primary,
              collapsedIconColor: AppColors.textMuted,
              childrenPadding:
                  const EdgeInsets.fromLTRB(20, 0, 20, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final point in section.points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            point,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
