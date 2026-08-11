import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/domain/fleet_models.dart';

class FleetRepository {
  const FleetRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<FleetHome> home() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/fleet');
      return FleetHome.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<String> createOrganisation({
    required String name,
    String? registrationNumber,
    String? billingAddress,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/fleet',
        data: {
          'name': name.trim(),
          if (registrationNumber != null && registrationNumber.trim().isNotEmpty)
            'registration_number': registrationNumber.trim(),
          if (billingAddress != null && billingAddress.trim().isNotEmpty)
            'billing_address': billingAddress.trim(),
        },
      );
      return _dataMap(response.data)['id']?.toString() ?? '';
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> accept(String organisationId) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>('/fleet/$organisationId/accept');
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetOrgDetail> show(String organisationId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/fleet/$organisationId');
      return FleetOrgDetail.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetKpis> dashboard(String organisationId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/fleet/$organisationId/dashboard');
      return FleetKpis.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry('$k', v));
    throw const ApiFailure('Travla returned an unexpected fleet response.');
  }
}

final fleetRepositoryProvider = Provider<FleetRepository>((ref) {
  return FleetRepository(ref.watch(apiClientProvider));
});

final fleetHomeProvider = FutureProvider.autoDispose<FleetHome>((ref) {
  return ref.watch(fleetRepositoryProvider).home();
});

final fleetOrgProvider = FutureProvider.autoDispose.family<FleetOrgDetail, String>((ref, id) {
  return ref.watch(fleetRepositoryProvider).show(id);
});

final fleetDashboardProvider = FutureProvider.autoDispose.family<FleetKpis, String>((ref, id) {
  return ref.watch(fleetRepositoryProvider).dashboard(id);
});
