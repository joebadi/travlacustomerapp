import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_service.dart';

class VehicleServiceRepository {
  const VehicleServiceRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<VehicleServiceWorkspace> load(String vehicleId) async {
    try {
      final responses = await Future.wait([
        _apiClient.dio.get<Map<String, dynamic>>('/vehicle-services/catalogue'),
        _apiClient.dio.get<Map<String, dynamic>>(
          '/vehicles/$vehicleId/services',
        ),
        _apiClient.dio.get<Map<String, dynamic>>('/catalogue/service-cities'),
      ]);
      final catalogue = responses[0].data?['data'];
      final orders = responses[1].data?['data'];
      final cities = responses[2].data?['data'];
      if (catalogue is! List || orders is! List || cities is! List) {
        throw const ApiFailure('Travla returned an invalid service workspace.');
      }
      return VehicleServiceWorkspace(
        catalogue: catalogue
            .whereType<Map<String, dynamic>>()
            .map(VehicleServiceCatalogueItem.fromJson)
            .where((item) => item.value.isNotEmpty)
            .toList(growable: false),
        orders: orders
            .whereType<Map<String, dynamic>>()
            .map(VehicleServiceOrder.fromJson)
            .toList(growable: false),
        cities: cities
            .whereType<Map<String, dynamic>>()
            .map(VehicleServiceCity.fromJson)
            .where((item) => item.city.isNotEmpty && item.state.isNotEmpty)
            .toList(growable: false),
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> create({
    required String vehicleId,
    required String serviceType,
    required Map<String, String> details,
    required String deliveryMethod,
    required String deliveryAddress,
    required String city,
    required String state,
    required DateTime? preferredDate,
    required String notes,
  }) => _mutate(
    () => _apiClient.dio.post<void>(
      '/vehicles/$vehicleId/services',
      data: {
        'service_type': serviceType,
        if (details.isNotEmpty) 'details': details,
        'delivery_method': deliveryMethod,
        if (deliveryMethod == 'DELIVERY')
          'delivery_address': deliveryAddress.trim(),
        if (city.isNotEmpty) 'city': city,
        if (state.isNotEmpty) 'state': state,
        if (preferredDate != null) 'preferred_date': _apiDate(preferredDate),
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    ),
  );

  Future<void> pay(String orderId) => _mutate(
    () => _apiClient.dio.post<void>('/vehicle-services/$orderId/pay'),
  );

  Future<void> cancel(String orderId) => _mutate(
    () => _apiClient.dio.post<void>('/vehicle-services/$orderId/cancel'),
  );

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }
}

String _apiDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

final vehicleServiceRepositoryProvider = Provider<VehicleServiceRepository>((
  ref,
) {
  return VehicleServiceRepository(ref.watch(apiClientProvider));
});

final vehicleServiceWorkspaceProvider = FutureProvider.autoDispose
    .family<VehicleServiceWorkspace, String>((ref, vehicleId) {
      return ref.watch(vehicleServiceRepositoryProvider).load(vehicleId);
    });
