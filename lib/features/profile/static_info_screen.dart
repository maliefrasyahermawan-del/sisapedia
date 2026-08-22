import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';

class _InfoContent {
  final String title;
  final String body;
  const _InfoContent(this.title, this.body);
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

const _faqItems = [
  _FaqItem(
    'Apa itu SisaPedia?',
    'SisaPedia adalah platform ekonomi sirkular yang menghubungkan penghasil '
        'sampah (rumah tangga, pasar, dan UMKM pangan) di Semarang dengan mitra '
        'pengolah terdekat, bank sampah, komposter, peternak maggot BSF, dan '
        'pengepul barang bernilai tinggi. SisaPedia berfokus mempertemukan '
        'pasokan dan permintaan sampah di sektor hulu, bukan sekadar layanan '
        'angkut sampah.',
  ),
  _FaqItem(
    'Apa itu Poin Sirkular dan bagaimana cara meningkatkannya?',
    'Poin Sirkular adalah reward yang kamu kumpulkan setiap kali menyetor '
        'sampah organik atau anorganik lewat SisaPedia, dengan konversi 1 kg '
        'sampah setara 10 poin. Semakin sering dan semakin banyak kamu '
        'menyetor, poinmu akan terus naik dan otomatis menaikkan Level '
        'Sirkular serta peringkatmu di leaderboard kota. Poin bisa ditukar '
        'jadi saldo e-wallet atau voucher mitra di menu Rekomendasi & '
        'Artikel.',
  ),
  _FaqItem(
    'Apa perbedaan SisaPedia dengan Bank Sampah biasa?',
    'SisaPedia gratis digunakan oleh siapa saja dan tidak menggantikan bank '
        'sampah, justru menghubungkanmu ke bank sampah, komposter, dan '
        'peternak maggot BSF terdekat lewat Wilayah Pencocokan. Setiap sampah '
        'yang disetor lewat mitra kami dipastikan diproses lebih lanjut, '
        'bukan dibuang ke TPA.',
  ),
  _FaqItem(
    'Bagaimana cara menyetor sampah melalui SisaPedia?',
    'Buka aplikasi, pilih "Setor Organik" atau "Setor Anorganik", pilih '
        'kategori dan kuantitas sampahmu, lalu pilih dijemput mitra atau '
        'diantar langsung ke titik setor terdekat. Poin Sirkular otomatis '
        'masuk setelah setoran diverifikasi. Selengkapnya lihat menu '
        'Panduan.',
  ),
  _FaqItem(
    'Bagaimana cara berlangganan Program Company & Event?',
    'Jika kamu pemilik bisnis atau penyelenggara event, buka menu '
        'Pertanyaan Umum ini atau hubungi tim SisaPedia untuk mengajukan '
        'kerja sama. Jadwal dan kapasitas armada akan disesuaikan dengan '
        'kebutuhanmu, lalu laporan dampak lingkungan dikirim setelah '
        'kegiatan selesai.',
  ),
  _FaqItem(
    'Sampah jenis apa saja yang dikelola SisaPedia?',
    'Organik: sisa sayur, sisa buah, sisa makanan, daun kering, ampas kopi, '
        'dan cangkang telur, diproses jadi kompos atau pakan maggot BSF. '
        'Anorganik bernilai tinggi: plastik PET, kertas, kardus, logam, dan '
        'kaca, disalurkan ke pengepul mitra.',
  ),
  _FaqItem(
    'Apakah SisaPedia yayasan atau LSM?',
    'SisaPedia adalah perusahaan teknologi berbasis sosial (social '
        'enterprise), bukan yayasan atau LSM. Model ini dipilih agar '
        'SisaPedia bisa berjalan mandiri dan berkelanjutan, tidak bergantung '
        'pada donasi, sehingga dampaknya bagi lingkungan dan masyarakat '
        'Semarang bisa terus berkembang.',
  ),
  _FaqItem(
    'Bagaimana cara bergabung menjadi mitra SisaPedia?',
    'Jika kamu pelaku usaha daur ulang seperti bank sampah, komposter, '
        'peternak maggot BSF, atau pengepul, kamu bisa mendaftar dengan '
        'peran "Pengolah" di aplikasi. Selengkapnya lihat panduan "Menjadi '
        'Mitra" di menu Panduan.',
  ),
];

const _tentangParagraphs = [
  'SisaPedia adalah platform ekonomi sirkular yang menghubungkan penghasil '
      'sampah, rumah tangga, pasar, dan UMKM pangan di Kota Semarang, dengan '
      'mitra pengolah terdekat: bank sampah, komposter, peternak maggot BSF, '
      'dan pengepul barang bernilai tinggi.',
  'Lewat Wilayah Pencocokan dan asisten AI Sari, SisaPedia memudahkan siapa '
      'saja untuk menyetor sampah organik maupun anorganik, memantau '
      'dampaknya lewat Dashboard, dan mengumpulkan Poin Sirkular yang naik '
      'jadi Level Sirkular.',
  'Kami percaya kota yang lebih hijau dimulai dari kebiasaan kecil: '
      'memilah dan menyalurkan sampah ke tangan yang tepat, bukan '
      'membuangnya ke TPA.',
];

const _content = {
  'syarat': _InfoContent(
    'Syarat dan Ketentuan',
    'Dengan menggunakan SisaPedia, kamu setuju untuk memberikan data setoran yang '
        'akurat dan menjaga keamanan akunmu. Penyalahgunaan sistem poin dapat '
        'mengakibatkan pembekuan akun.',
  ),
  'privasi': _InfoContent(
    'Kebijakan Privasi',
    'SisaPedia menyimpan data akun dan riwayat setoranmu untuk menghitung dampak '
        'sirkular dan poin. Data tidak dibagikan ke pihak ketiga tanpa persetujuanmu.',
  ),
};

class StaticInfoScreen extends StatelessWidget {
  const StaticInfoScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    if (slug == 'faq') return const _FaqView();
    if (slug == 'tentang') return const _TentangView();

    final content = _content[slug] ??
        const _InfoContent('SisaPedia', 'Konten belum tersedia.');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(content.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          content.body,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.6),
        ),
      ),
    );
  }
}

class _FaqView extends StatelessWidget {
  const _FaqView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pertanyaan Umum')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _faqItems.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final item = _faqItems[i];
          return AppCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                iconColor: AppColors.primary,
                collapsedIconColor: AppColors.textSecondary,
                title: Text(item.question, style: AppTextStyles.bodyBold),
                childrenPadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.answer,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary, height: 1.6),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TentangView extends StatelessWidget {
  const _TentangView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tentang SisaPedia')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.eco_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text('SisaPedia', style: AppTextStyles.h1),
            const SizedBox(height: 2),
            Text('Versi 1.0.0', style: AppTextStyles.captionMuted),
            const SizedBox(height: 20),
            for (final paragraph in _tentangParagraphs) ...[
              Text(
                paragraph,
                textAlign: TextAlign.left,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary, height: 1.6),
              ),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _TentangStatTile(
                    value: '3.240 kg',
                    label: 'Organik teralihkan/bulan',
                    background: AppColors.primaryLight,
                    valueColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TentangStatTile(
                    value: '1,8 ton',
                    label: 'Anorganik teralihkan/bulan',
                    background: const Color(0xFFEFF4FF),
                    valueColor: AppColors.anorganik,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TentangStatTile extends StatelessWidget {
  const _TentangStatTile({
    required this.value,
    required this.label,
    required this.background,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color background;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.h2.copyWith(color: valueColor, fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.captionMuted,
          ),
        ],
      ),
    );
  }
}
