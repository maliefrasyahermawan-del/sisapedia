import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sisapedia/core/providers/data_providers.dart';
import 'package:sisapedia/data/models/article_model.dart';
import 'package:sisapedia/features/articles/article_list_screen.dart';
import 'package:sisapedia/features/home/widgets/redeem_article_section.dart';

void main() {
  const articles = [
    ArticleModel(
      id: 'article-1',
      title: 'Cara Memilah Sampah',
      summary: 'Panduan singkat memilah sampah dari rumah.',
      content: 'Pisahkan sampah sesuai kategorinya.',
      readTimeMinutes: 3,
    ),
  ];

  testWidgets('Lihat Lainnya opens the complete article list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          articlesProvider.overrideWith((ref) => Stream.value(articles)),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) =>
                    Scaffold(body: RedeemArticleSection(onRedeem: (_, _) {})),
              ),
              GoRoute(
                path: '/artikel',
                builder: (_, _) => const ArticleListScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lihat Lainnya'));
    await tester.pumpAndSettle();

    expect(find.text('Semua Artikel'), findsOneWidget);
    expect(find.text('Cara Memilah Sampah'), findsOneWidget);
    expect(find.text('Baca selengkapnya'), findsOneWidget);
  });
}
