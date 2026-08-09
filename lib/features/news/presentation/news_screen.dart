import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/news/data/news_repository.dart';
import 'package:travla_customer_app/features/news/domain/news_models.dart';

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _category = '';
  String _sort = 'latest';
  int _page = 1;

  NewsQuery get _feedQuery =>
      NewsQuery(search: _query, category: _category, sort: _sort, page: _page);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _page = 1;
      });
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(newsMetaProvider);
    ref.invalidate(newsFeedProvider(_feedQuery));
    await Future.wait([
      ref.read(newsMetaProvider.future),
      ref.read(newsFeedProvider(_feedQuery).future),
    ]);
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _category = '';
      _sort = 'latest';
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(newsMetaProvider);
    final feed = ref.watch(newsFeedProvider(_feedQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('News'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sort news',
            initialValue: _sort,
            onSelected: (value) => setState(() {
              _sort = value;
              _page = 1;
            }),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'latest', child: Text('Latest first')),
              PopupMenuItem(value: 'popular', child: Text('Most read')),
              PopupMenuItem(value: 'oldest', child: Text('Oldest first')),
            ],
            icon: const Icon(Icons.swap_vert_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.forest600,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _NewsHeader(
                controller: _search,
                onChanged: _searchChanged,
              ),
            ),
            SliverToBoxAdapter(
              child: meta.when(
                loading: () => const _CategoryLoading(),
                error: (_, _) => const SizedBox(height: 10),
                data: (value) => _CategoryStrip(
                  categories: value.categories,
                  selected: _category,
                  onSelected: (category) => setState(() {
                    _category = category;
                    _page = 1;
                  }),
                ),
              ),
            ),
            if (_query.isEmpty && _category.isEmpty && _page == 1)
              SliverToBoxAdapter(
                child: meta.when(
                  data: (value) => value.featured == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          child: _FeaturedArticle(article: value.featured!),
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: _FeaturedLoading(),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
            feed.when(
              loading: () => const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 2, 16, 30),
                sliver: SliverToBoxAdapter(child: _FeedLoading()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _NewsError(
                  message: error is ApiFailure
                      ? error.message
                      : 'The Travla newsroom could not be loaded.',
                  onRetry: () => ref.invalidate(newsFeedProvider(_feedQuery)),
                ),
              ),
              data: (page) => page.articles.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyNews(
                        hasFilters: _query.isNotEmpty || _category.isNotEmpty,
                        onClear: _clearFilters,
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 30),
                      sliver: SliverList.separated(
                        itemCount: page.articles.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == page.articles.length) {
                            return _Pagination(
                              page: page,
                              onPrevious: page.currentPage > 1
                                  ? () => setState(() => _page--)
                                  : null,
                              onNext: page.currentPage < page.lastPage
                                  ? () => setState(() => _page++)
                                  : null,
                            );
                          }
                          return _ArticleCard(article: page.articles[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsHeader extends StatelessWidget {
  const _NewsHeader({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRAVLA NEWSROOM',
            style: TextStyle(
              color: Color(0xFF75DFB8),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Know what is changing on the road.',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Vehicle laws, ownership guides, traffic and safety briefings.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .65),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search news and guides',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              fillColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<NewsCategory> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final name = index == 0 ? '' : categories[index - 1].name;
          final selectedNow = selected == name;
          return ChoiceChip(
            selected: selectedNow,
            onSelected: (_) => onSelected(name),
            label: Text(index == 0 ? 'All stories' : name),
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selectedNow ? AppColors.white : AppColors.muted,
            ),
            selectedColor: AppColors.forest700,
            backgroundColor: AppColors.white,
            side: BorderSide(
              color: selectedNow ? AppColors.forest700 : AppColors.border,
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class _FeaturedArticle extends StatelessWidget {
  const _FeaturedArticle({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forest950,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/news/${article.slug}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 170,
              width: double.infinity,
              child: _ArticleImage(url: article.coverImageUrl),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EDITOR’S LEAD',
                    style: TextStyle(
                      color: Color(0xFF75DFB8),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.white,
                      height: 1.22,
                    ),
                  ),
                  if (article.excerpt?.isNotEmpty == true) ...[
                    const SizedBox(height: 7),
                    Text(
                      article.excerpt!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .6),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ArticleMeta(article: article, onDark: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/news/${article.slug}'),
        child: SizedBox(
          height: 128,
          child: Row(
            children: [
              SizedBox(
                width: 122,
                height: double.infinity,
                child: _ArticleImage(url: article.coverImageUrl),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (article.category ?? 'News').toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.forest600,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Expanded(
                        child: Text(
                          article.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                      _ArticleMeta(article: article),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleImage extends StatelessWidget {
  const _ArticleImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url?.isNotEmpty == true) {
      return Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _NewsImageFallback(),
      );
    }
    return const _NewsImageFallback();
  }
}

class _NewsImageFallback extends StatelessWidget {
  const _NewsImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest700, AppColors.forest950],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.newspaper_rounded,
          color: Color(0xFF75DFB8),
          size: 32,
        ),
      ),
    );
  }
}

class _ArticleMeta extends StatelessWidget {
  const _ArticleMeta({required this.article, this.onDark = false});

  final NewsArticle article;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${formatNewsDate(article.publishedAt)} · ${article.readingMinutes} min read',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: onDark ? Colors.white.withValues(alpha: .45) : AppColors.muted,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.onPrevious,
    required this.onNext,
  });

  final NewsPage page;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    if (page.lastPage <= 1) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          OutlinedButton(onPressed: onPrevious, child: const Text('Previous')),
          Expanded(
            child: Text(
              'Page ${page.currentPage} of ${page.lastPage}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
          OutlinedButton(onPressed: onNext, child: const Text('Next')),
        ],
      ),
    );
  }
}

class _CategoryLoading extends StatelessWidget {
  const _CategoryLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 46,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _FeaturedLoading extends StatelessWidget {
  const _FeaturedLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 290,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (_) => Container(
          height: 128,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _NewsError extends StatelessWidget {
  const _NewsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 38),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNews extends StatelessWidget {
  const _EmptyNews({required this.hasFilters, required this.onClear});

  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilters ? Icons.search_off_rounded : Icons.newspaper_outlined,
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters
                  ? 'No stories match these filters.'
                  : 'No news has been published yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try another keyword or category.'
                  : 'New vehicle and road briefings will appear here when the Travla newsroom publishes them.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String formatNewsDate(DateTime? value) {
  if (value == null) return 'Recently';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
