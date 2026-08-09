import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_catalogue.dart';

class VehicleSetupRepository {
  const VehicleSetupRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<VehicleCatalogue> catalogue() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/catalogue/vehicles',
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('Travla returned an invalid vehicle catalogue.');
      }
      return VehicleCatalogue.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<AddedVehicleResult> addExisting(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/vehicles',
        data: payload,
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('Travla returned an invalid vehicle response.');
      }
      final vehicle = data['vehicle'];
      if (vehicle is! Map<String, dynamic> ||
          vehicle['id']?.toString().isEmpty != false) {
        throw const ApiFailure(
          'The vehicle was added but could not be opened.',
        );
      }
      final stolenMatch = data['stolen_match'];
      return AddedVehicleResult(
        id: vehicle['id'].toString(),
        stolenMatch: stolenMatch is Map<String, dynamic> ? stolenMatch : null,
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }
}

final vehicleSetupRepositoryProvider = Provider<VehicleSetupRepository>((ref) {
  return VehicleSetupRepository(ref.watch(apiClientProvider));
});

final vehicleCatalogueProvider = FutureProvider.autoDispose<VehicleCatalogue>((
  ref,
) {
  return ref.watch(vehicleSetupRepositoryProvider).catalogue();
});
