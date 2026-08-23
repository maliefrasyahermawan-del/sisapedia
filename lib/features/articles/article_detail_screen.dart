import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/article_model.dart';

class ArticleDetailScreen extends ConsumerWidget {
  const ArticleDetailScreen({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(articlesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Artikel')),
      body: articlesAsync.when(
        data: (articles) {
          final article = articles.cast<ArticleModel?>().firstWhere(
            (a) => a?.id == articleId,
            orElse: () => null,
          );
          if (article == null) {
            return Center(
              child: Text(
                'Artikel tidak ditemukan.',
                style: AppTextStyles.captionMuted,
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ARTIKEL',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(article.title, style: AppTextStyles.h1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${article.readTimeMinutes} menit baca',
                      style: AppTextStyles.captionMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  article.content.isNotEmpty
                      ? article.content
                      : article.summary,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'Gagal memuat artikel.',
            style: AppTextStyles.captionMuted,
          ),
        ),
      ),
    );
  }
}
