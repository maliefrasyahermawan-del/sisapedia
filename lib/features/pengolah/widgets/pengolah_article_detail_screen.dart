import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/pengolah_articles.dart';

class PengolahArticleDetailScreen extends StatelessWidget {
  const PengolahArticleDetailScreen({super.key, required this.article});

  final PengolahArticle article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Artikel'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(article.title, style: AppTextStyles.h1),
          const SizedBox(height: 6),
          Text(article.readTime, style: AppTextStyles.captionMuted),
          const SizedBox(height: 20),
          for (final p in article.paragraphs) ...[
            Text(p, style: AppTextStyles.body.copyWith(height: 1.6)),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
