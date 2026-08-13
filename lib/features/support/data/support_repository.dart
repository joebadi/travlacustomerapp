import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/support/domain/support_models.dart';

class SupportRepository {
  const SupportRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<SupportAvailability> availability() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/support/availability',
      );
      return SupportAvailability.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<SupportTicket>> myTickets() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/support/tickets',
      );
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(SupportTicket.fromJson)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<SupportTicket> ticket(String id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/support/tickets/$id',
      );
      return SupportTicket.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<SupportOrderOption>> orderOptions() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/support/order-options',
      );
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(SupportOrderOption.fromJson)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String message,
    String? category,
    required String channel,
    SupportOrderOption? related,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/support/tickets',
        data: {
          'subject': subject.trim(),
          'message': message.trim(),
          if (category != null && category.isNotEmpty) 'category': category,
          'channel': channel,
          if (related != null) ...{
            'related_type': related.type,
            'related_id': related.id,
            'related_label': related.label,
          },
        },
      );
      return SupportTicket.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> postMessage(String ticketId, String body) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/support/tickets/$ticketId/messages',
        data: {'body': body.trim()},
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> markRead(String ticketId) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/support/tickets/$ticketId/read',
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry('$k', v));
    throw const ApiFailure('Travla returned an unexpected support response.');
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(apiClientProvider));
});

final supportAvailabilityProvider =
    FutureProvider.autoDispose<SupportAvailability>((ref) {
      return ref.watch(supportRepositoryProvider).availability();
    });

final myTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>((
  ref,
) {
  return ref.watch(supportRepositoryProvider).myTickets();
});

final supportTicketProvider = FutureProvider.autoDispose
    .family<SupportTicket, String>((ref, id) {
      return ref.watch(supportRepositoryProvider).ticket(id);
    });

final supportOrderOptionsProvider =
    FutureProvider.autoDispose<List<SupportOrderOption>>((ref) {
      return ref.watch(supportRepositoryProvider).orderOptions();
    });
