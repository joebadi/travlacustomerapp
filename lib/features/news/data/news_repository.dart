import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/news/domain/news_models.dart';

class NewsRepository {
  const NewsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<NewsMeta> meta() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/news-meta',
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('Travla returned invalid newsroom details.');
      }
      return NewsMeta.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<NewsPage> feed(NewsQuery query) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/news',
        queryParameters: {
          if (query.search.trim().isNotEmpty) 'q': query.search.trim(),
          if (query.category.isNotEmpty) 'category': query.category,
          'sort': query.sort,
          'page': query.page,
          'per_page': 10,
        },
      );
      final data = response.data?['data'];
      final meta = response.data?['meta'];
      if (data is! List || meta is! Map<String, dynamic>) {
        throw const ApiFailure('Travla returned an invalid news feed.');
      }
      return NewsPage(
        articles: data
            .whereType<Map<String, dynamic>>()
            .map(NewsArticle.fromJson)
            .toList(growable: false),
        currentPage: (meta['current_page'] as num?)?.toInt() ?? query.page,
        lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
        total: (meta['total'] as num?)?.toInt() ?? data.length,
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<NewsArticle> article(String slug) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/news/${Uri.encodeComponent(slug)}',
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('This news article could not be loaded.');
      }
      return NewsArticle.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }
}

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepository(ref.watch(apiClientProvider));
});

final newsMetaProvider = FutureProvider.autoDispose<NewsMeta>((ref) {
  return ref.watch(newsRepositoryProvider).meta();
});

final newsFeedProvider = FutureProvider.autoDispose.family<NewsPage, NewsQuery>(
  (ref, query) {
    return ref.watch(newsRepositoryProvider).feed(query);
  },
);

final newsArticleProvider = FutureProvider.autoDispose
    .family<NewsArticle, String>((ref, slug) {
      return ref.watch(newsRepositoryProvider).article(slug);
    });
