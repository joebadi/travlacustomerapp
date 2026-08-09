import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/notifications/domain/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<NotificationSnapshot> load() async {
    try {
      final responses = await Future.wait([
        _apiClient.dio.get<Map<String, dynamic>>(
          '/notifications',
          queryParameters: const {'per_page': 50},
        ),
        _apiClient.dio.get<Map<String, dynamic>>('/notifications/unread-count'),
      ]);

      final listEnvelope = responses[0].data;
      final rawItems = listEnvelope?['data'];
      if (rawItems is! List) {
        throw const ApiFailure(
          'Travla returned an unexpected notification list.',
        );
      }

      final countData = responses[1].data?['data'];
      final unreadCount = countData is Map<String, dynamic>
          ? (countData['count'] as num?)?.toInt() ?? 0
          : 0;

      return NotificationSnapshot(
        items: rawItems
            .whereType<Map<String, dynamic>>()
            .map(AppNotification.fromJson)
            .toList(growable: false),
        unreadCount: unreadCount,
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _apiClient.dio.post<void>('/notifications/$id/read');
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _apiClient.dio.post<void>('/notifications/read-all');
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

final notificationsProvider = FutureProvider.autoDispose<NotificationSnapshot>((
  ref,
) async {
  final refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(refreshTimer.cancel);
  return ref.watch(notificationRepositoryProvider).load();
});
