import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/tracking/domain/live_position.dart';

class TrackingMapRepository {
  const TrackingMapRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Latest position for each of the user's vehicles.
  Future<List<LivePosition>> live() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/tracking/live',
      );
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(LivePosition.fromJson)
          .where((p) => p.vehicleId.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /// Recent GPS trail for one vehicle, oldest→newest, for the map polyline.
  Future<List<({double latitude, double longitude})>> trail(
    String vehicleId, {
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/vehicles/$vehicleId/tracking/trail',
        queryParameters: {'limit': limit},
      );
      final trail = response.data?['data']?['trail'];
      if (trail is! List) return const [];
      return trail
          .whereType<Map>()
          .map(
            (e) => (
              latitude: (e['latitude'] as num?)?.toDouble() ?? 0.0,
              longitude: (e['longitude'] as num?)?.toDouble() ?? 0.0,
            ),
          )
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /// Submit a GPS fix for a phone tracker. Authenticated by the tracker's key
  /// (public ingest endpoint), not the session.
  Future<void> ingest({
    required String apiKey,
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
    double? accuracy,
  }) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/track/ingest',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'speed': ?speed,
          'heading': ?heading,
          'accuracy': ?accuracy,
          'recorded_at': DateTime.now().toUtc().toIso8601String(),
        },
        options: Options(headers: {'x-api-key': apiKey}),
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }
}

final trackingMapRepositoryProvider = Provider<TrackingMapRepository>((ref) {
  return TrackingMapRepository(ref.watch(apiClientProvider));
});

final livePositionsProvider = FutureProvider.autoDispose<List<LivePosition>>((
  ref,
) {
  return ref.watch(trackingMapRepositoryProvider).live();
});

final vehicleTrailProvider = FutureProvider.autoDispose
    .family<List<({double latitude, double longitude})>, String>((
      ref,
      vehicleId,
    ) {
      return ref.watch(trackingMapRepositoryProvider).trail(vehicleId);
    });
