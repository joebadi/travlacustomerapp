import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_tracking.dart';

class VehicleTrackingRepository {
  const VehicleTrackingRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<VehicleTrackingWorkspace> load(String vehicleId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/vehicles/$vehicleId/tracking',
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('Travla returned invalid tracking data.');
      }
      return VehicleTrackingWorkspace.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<CreatedTrackerSource> create({
    required String vehicleId,
    required String type,
    required String label,
    required String uniqueId,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/vehicles/$vehicleId/trackers',
        data: {
          'type': type,
          if (label.trim().isNotEmpty) 'label': label.trim(),
          if (type == 'TRACCAR') 'unique_id': uniqueId.trim(),
        },
      );
      final data = response.data?['data'];
      final tracker = data is Map<String, dynamic> ? data['tracker'] : null;
      if (data is! Map<String, dynamic> || tracker is! Map<String, dynamic>) {
        throw const ApiFailure('The tracking source could not be confirmed.');
      }
      return CreatedTrackerSource(
        source: VehicleTrackerSource.fromJson(tracker),
        apiKey: data['api_key']?.toString(),
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> setActive(String trackerId, bool isActive) => _mutate(
    () => _apiClient.dio.patch<void>(
      '/trackers/$trackerId',
      data: {'is_active': isActive},
    ),
  );

  Future<String> regenerateKey(String trackerId) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/trackers/$trackerId/regenerate-key',
      );
      final key = response.data?['data']?['api_key']?.toString();
      if (key == null || key.isEmpty) {
        throw const ApiFailure('Travla did not return the new tracker key.');
      }
      return key;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> delete(String trackerId) =>
      _mutate(() => _apiClient.dio.delete<void>('/trackers/$trackerId'));

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }
}

final vehicleTrackingRepositoryProvider = Provider<VehicleTrackingRepository>((
  ref,
) {
  return VehicleTrackingRepository(ref.watch(apiClientProvider));
});

final vehicleTrackingWorkspaceProvider = FutureProvider.autoDispose
    .family<VehicleTrackingWorkspace, String>((ref, vehicleId) {
      return ref.watch(vehicleTrackingRepositoryProvider).load(vehicleId);
    });
