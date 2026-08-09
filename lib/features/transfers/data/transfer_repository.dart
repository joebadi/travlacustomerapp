import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/transfers/domain/transfer_models.dart';

class TransferRepository {
  const TransferRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<TransferSetup> setup() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/catalogue/service-cities',
      );
      final data = response.data?['data'];
      if (data is! List) {
        throw const ApiFailure('Transfer cities could not be loaded.');
      }
      return TransferSetup(
        cities: data
            .whereType<Map<String, dynamic>>()
            .map(TransferCity.fromJson)
            .where((item) => item.city.isNotEmpty)
            .toList(growable: false),
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<TransferReadiness> readiness({
    required String vehicleId,
    required String deliveryMethod,
    required String city,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/vehicles/$vehicleId/transfer-readiness',
        queryParameters: {
          'mode': 'MANAGED',
          'delivery_method': deliveryMethod,
          if (city.isNotEmpty) 'city': city,
        },
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('Transfer readiness could not be confirmed.');
      }
      return TransferReadiness.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<TransferRecipientMatch> lookup({
    required String phone,
    String? email,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/transfers/recipient-lookup',
        data: {
          'phone': phone.trim(),
          if (email?.trim().isNotEmpty == true) 'email': email!.trim(),
        },
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('The recipient lookup could not be completed.');
      }
      return TransferRecipientMatch.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<String> create(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/transfers',
        data: payload,
      );
      final id = response.data?['data']?['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const ApiFailure(
          'The transfer was submitted but could not be opened.',
        );
      }
      return id;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }
}

final transferRepositoryProvider = Provider<TransferRepository>(
  (ref) => TransferRepository(ref.watch(apiClientProvider)),
);
final transferSetupProvider = FutureProvider.autoDispose<TransferSetup>(
  (ref) => ref.watch(transferRepositoryProvider).setup(),
);
