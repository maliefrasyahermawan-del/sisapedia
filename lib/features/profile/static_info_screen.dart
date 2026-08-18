import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class _InfoContent {
  final String title;
  final String body;
  const _InfoContent(this.title, this.body);
}

const _content = {
  'faq': _InfoContent(
    'Pertanyaan Umum',
    'Q: Berapa lama setoran diverifikasi?\n'
        'A: Biasanya 1-2 hari kerja setelah mitra menerima sampahmu.\n\n'
        'Q: Apakah poin bisa hangus?\n'
        'A: Poin Sirkular tidak memiliki masa berlaku selama akun aktif.',
  ),
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
  'tentang': _InfoContent(
    'Tentang SisaPedia',
    'SisaPedia adalah platform pengelolaan sampah sirkular yang menghubungkan warga, '
        'bank sampah, dan dinas lingkungan untuk mempercepat pengalihan sampah dari TPA.',
  ),
};

class StaticInfoScreen extends StatelessWidget {
  const StaticInfoScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
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
