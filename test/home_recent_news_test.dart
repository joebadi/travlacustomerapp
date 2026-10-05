import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/home/presentation/home_screen.dart';
import 'package:travla_customer_app/features/news/domain/news_models.dart';

void main() {
  testWidgets('home newsroom uses square editorial cards', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const article = NewsArticle(
      id: 'article-1',
      slug: 'safer-roads',
      title: 'A practical guide to safer roads',
      category: 'Road safety',
      coverImageUrl: null,
      excerpt: 'What every Nigerian vehicle owner should know this week.',
      body: null,
      tags: [],
      sourceName: null,
      sourceUrl: null,
      author: 'Travla Desk',
      featured: false,
      publishedAt: null,
      viewCount: 10,
      readingMinutes: 4,
      related: [],
    );
    const secondArticle = NewsArticle(
      id: 'article-2',
      slug: 'vehicle-papers',
      title: 'The papers every vehicle owner should keep current',
      category: 'Ownership',
      coverImageUrl: null,
      excerpt: 'A simple checklist for staying ready on Nigerian roads.',
      body: null,
      tags: [],
      sourceName: null,
      sourceUrl: null,
      author: null,
      featured: false,
      publishedAt: null,
      viewCount: 4,
      readingMinutes: 3,
      related: [],
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: HomeRecentNewsSection(
                feed: AsyncValue.data(
                  NewsPage(
                    articles: [article, secondArticle],
                    currentPage: 1,
                    lastPage: 1,
                    total: 2,
                  ),
                ),
                onRetry: _noop,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('FROM THE NEWSROOM'), findsOneWidget);
    expect(find.text('Latest road stories'), findsOneWidget);
    expect(find.text('A practical guide to safer roads'), findsOneWidget);
    expect(find.text('READ STORY'), findsNWidgets(2));
    expect(find.text('01 / 02'), findsOneWidget);

    final card = tester.widget<Container>(
      find.byKey(const ValueKey('home-news-card-safer-roads')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.borderRadius, isNull);
    expect(decoration.border, isNotNull);

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('02 / 02'), findsOneWidget);
    expect(
      find.text('The papers every vehicle owner should keep current'),
      findsOneWidget,
    );
  });
}

void _noop() {}
