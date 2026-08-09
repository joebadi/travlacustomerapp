import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/news/data/news_repository.dart';
import 'package:travla_customer_app/features/news/domain/news_models.dart';
import 'package:travla_customer_app/features/news/presentation/news_screen.dart';

class NewsArticleScreen extends ConsumerWidget {
  const NewsArticleScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final article = ref.watch(newsArticleProvider(slug));
    return Scaffold(
      appBar: AppBar(title: const Text('News article')),
      body: article.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ArticleError(
          message: error is ApiFailure
              ? error.message
              : 'This news article could not be loaded.',
          onRetry: () => ref.invalidate(newsArticleProvider(slug)),
        ),
        data: (value) => _ArticleBody(article: value),
      ),
    );
  }
}

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (article.coverImageUrl?.isNotEmpty == true)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                article.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ArticleImageFallback(),
              ),
            )
          else
            const SizedBox(height: 150, child: _ArticleImageFallback()),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.forest100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        article.category ?? 'News',
                        style: const TextStyle(
                          color: AppColors.forest700,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${article.readingMinutes} min read · ${article.viewCount} reads',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  article.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    height: 1.2,
                    letterSpacing: -.6,
                  ),
                ),
                if (article.excerpt?.isNotEmpty == true) ...[
                  const SizedBox(height: 11),
                  Text(
                    article.excerpt!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        size: 19,
                        color: AppColors.forest600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            if (article.author?.isNotEmpty == true)
                              'By ${article.author}',
                            formatNewsDate(article.publishedAt),
                          ].join(' · '),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SelectableText(
                  _cleanBody(article.body ?? ''),
                  style: const TextStyle(
                    color: Color(0xFF34423C),
                    fontSize: 14,
                    height: 1.72,
                  ),
                ),
                if (article.tags.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: article.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF1F0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                if (article.sourceName?.isNotEmpty == true) ...[
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.forest50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.forest100),
                    ),
                    child: Text(
                      'Original source: ${article.sourceName}',
                      style: const TextStyle(
                        color: AppColors.forest700,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (article.related.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    'Continue reading',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  ...article.related.map(
                    (related) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 4,
                        ),
                        title: Text(
                          related.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${related.category ?? 'News'} · ${related.readingMinutes} min',
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                        onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                NewsArticleScreen(slug: related.slug),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _cleanBody(String value) {
    return value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }
}

class _ArticleImageFallback extends StatelessWidget {
  const _ArticleImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.forest700, AppColors.forest950],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.newspaper_rounded,
          color: Color(0xFF75DFB8),
          size: 38,
        ),
      ),
    );
  }
}

class _ArticleError extends StatelessWidget {
  const _ArticleError({required this.message, required this.onRetry});

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
            const Icon(Icons.article_outlined, size: 38),
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
