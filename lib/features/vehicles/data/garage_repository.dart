import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';

class GarageRepository {
  GarageRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<GarageSnapshot> load() async {
    try {
      final responses = await Future.wait([
        _apiClient.dio.get<Map<String, dynamic>>(
          '/vehicles',
          queryParameters: const {'per_page': 50},
        ),
        _apiClient.dio.get<Map<String, dynamic>>('/transfers/pending-received'),
        _apiClient.dio.get<Map<String, dynamic>>(
          '/transfers/incoming-vehicles',
        ),
      ]);

      return GarageSnapshot(
        vehicles: _vehiclesFrom(responses[0].data),
        pendingTransfers: _transfersFrom(responses[1].data),
        incomingVehicles: _transfersFrom(responses[2].data),
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  List<VehicleSummary> _vehiclesFrom(Map<String, dynamic>? envelope) {
    final items = envelope?['data'];
    if (items is! List) {
      throw const ApiFailure('Travla returned an unexpected vehicle list.');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(VehicleSummary.fromJson)
        .toList(growable: false);
  }

  List<IncomingTransferSummary> _transfersFrom(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    final items = data is Map<String, dynamic> ? data['items'] : null;
    if (items is! List) {
      throw const ApiFailure('Travla returned an unexpected transfer list.');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(IncomingTransferSummary.fromJson)
        .toList(growable: false);
  }
}

final garageRepositoryProvider = Provider<GarageRepository>((ref) {
  return GarageRepository(ref.watch(apiClientProvider));
});

final garageProvider = FutureProvider.autoDispose<GarageSnapshot>((ref) {
  return ref.watch(garageRepositoryProvider).load();
});
