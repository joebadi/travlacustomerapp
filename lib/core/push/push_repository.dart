import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';

/// Registers/removes this device's FCM token with the backend so it can receive
/// push notifications. Failures are non-fatal — push is best-effort.
class PushRepository {
  const PushRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> register({
    required String token,
    required String platform,
  }) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/push-tokens',
        data: {'token': token, 'platform': platform},
      );
    } on DioException {
      // Best-effort; the next app launch / token refresh retries.
    }
  }

  Future<void> unregister(String token) async {
    try {
      await _apiClient.dio.delete<Map<String, dynamic>>(
        '/push-tokens',
        data: {'token': token},
      );
    } on DioException {
      // Ignore — signing out should never be blocked by push cleanup.
    }
  }
}

final pushRepositoryProvider = Provider<PushRepository>((ref) {
  return PushRepository(ref.watch(apiClientProvider));
});
