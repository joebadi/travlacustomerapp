import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/forum/domain/forum_models.dart';

class ForumRepository {
  const ForumRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ForumCategory>> categories() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/forum/categories');
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data.whereType<Map<String, dynamic>>().map(ForumCategory.fromJson).toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<ForumThread>> threads({String? category, String? query, String sort = 'active'}) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/forum/threads',
        queryParameters: {
          if (category != null && category.isNotEmpty) 'category': category,
          if (query != null && query.isNotEmpty) 'q': query,
          'sort': sort,
        },
      );
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data.whereType<Map<String, dynamic>>().map(ForumThread.fromJson).toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<ForumThreadDetail> show(String threadId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/forum/threads/$threadId');
      final data = _dataMap(response.data);
      final thread = data['thread'];
      final replies = data['replies'];
      return ForumThreadDetail(
        thread: ForumThread.fromJson((thread as Map).cast<String, dynamic>()),
        replies: (replies is List ? replies : const [])
            .whereType<Map>()
            .map((e) => ForumReply.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false),
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<ForumThread> createThread({
    required String categoryId,
    required String title,
    required String body,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/forum/threads',
        data: {'category_id': categoryId, 'title': title.trim(), 'body': body.trim()},
      );
      return ForumThread.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> reply(String threadId, String body) => _post('/forum/threads/$threadId/replies', {'body': body.trim()});
  Future<void> likeThread(String threadId) => _post('/forum/threads/$threadId/like');
  Future<void> likeReply(String replyId) => _post('/forum/replies/$replyId/like');

  Future<void> deleteThread(String threadId) => _delete('/forum/threads/$threadId');
  Future<void> deleteReply(String replyId) => _delete('/forum/replies/$replyId');

  Future<void> _post(String path, [Map<String, dynamic>? data]) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(path, data: data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> _delete(String path) async {
    try {
      await _apiClient.dio.delete<Map<String, dynamic>>(path);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry('$k', v));
    throw const ApiFailure('Travla returned an unexpected forum response.');
  }
}

final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  return ForumRepository(ref.watch(apiClientProvider));
});

final forumCategoriesProvider = FutureProvider.autoDispose<List<ForumCategory>>((ref) {
  return ref.watch(forumRepositoryProvider).categories();
});

typedef ForumQuery = ({String? category, String? query, String sort});

final forumThreadsProvider =
    FutureProvider.autoDispose.family<List<ForumThread>, ForumQuery>((ref, q) {
      return ref.watch(forumRepositoryProvider).threads(
            category: q.category,
            query: q.query,
            sort: q.sort,
          );
    });

final forumThreadProvider =
    FutureProvider.autoDispose.family<ForumThreadDetail, String>((ref, id) {
      return ref.watch(forumRepositoryProvider).show(id);
    });
