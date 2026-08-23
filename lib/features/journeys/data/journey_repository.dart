import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/journeys/domain/journey_models.dart';

class JourneyRepository {
  const JourneyRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Journey>> list() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/journeys');
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data.whereType<Map<String, dynamic>>().map(Journey.fromJson).toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<Journey> show(String journeyId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/journeys/$journeyId');
      return Journey.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /// Starts a journey and returns its id.
  Future<String> create({
    required String title,
    String? transportMode,
    String? vehicleId,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/journeys',
        data: {
          'title': title.trim(),
          'transport_mode': ?transportMode,
          if (vehicleId != null && vehicleId.isNotEmpty) 'vehicle_id': vehicleId,
          'recorded_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      return _dataMap(response.data)['id']?.toString() ?? '';
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> addPoints(String journeyId, List<Map<String, dynamic>> points) async {
    if (points.isEmpty) return;
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/journeys/$journeyId/points',
        data: {'points': points},
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /// Ask the server to snap this journey to the road network (OSRM
  /// map-matching). Best-effort: returns the refreshed journey either way.
  Future<Journey> match(String journeyId) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/journeys/$journeyId/match',
      );
      return Journey.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /// Create/refresh a share link (optionally expiring after [expiresInDays]).
  /// Sets visibility to LINK if the journey was private.
  Future<Journey> share(String journeyId, {int? expiresInDays}) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/journeys/$journeyId/share',
        data: {'expires_in_days': ?expiresInDays},
      );
      return Journey.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /// Set visibility: PRIVATE | LINK | ORGANISATION | PUBLIC.
  Future<Journey> setVisibility(String journeyId, String visibility) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/journeys/$journeyId/visibility',
        data: {'visibility': visibility},
      );
      return Journey.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /// Clone a shared journey into the signed-in user's list; returns the copy.
  Future<Journey> importJourney(String journeyId) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/journeys/$journeyId/import',
      );
      return Journey.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> delete(String journeyId) async {
    try {
      await _apiClient.dio.delete<Map<String, dynamic>>('/journeys/$journeyId');
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<RoadReportType>> roadReportCatalogue() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/road-reports/catalogue');
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data.whereType<Map<String, dynamic>>().map(RoadReportType.fromJson).toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<NearbyRoadReport>> nearbyReports({
    required double lat,
    required double lng,
    double radius = 3,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/road-reports/nearby',
        queryParameters: {'lat': lat, 'lng': lng, 'radius': radius},
      );
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data.whereType<Map<String, dynamic>>().map(NearbyRoadReport.fromJson).toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> createRoadReport({
    required String type,
    required double latitude,
    required double longitude,
    double? heading,
    String? description,
    double? gpsAccuracy,
    bool physicallyTravelled = true,
  }) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/road-reports',
        data: {
          'type': type,
          'latitude': latitude,
          'longitude': longitude,
          'heading': ?heading,
          if (description != null && description.isNotEmpty) 'description': description,
          'gps_accuracy': ?gpsAccuracy,
          'physically_travelled': physicallyTravelled,
        },
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry('$k', v));
    throw const ApiFailure('Travla returned an unexpected journeys response.');
  }
}

final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  return JourneyRepository(ref.watch(apiClientProvider));
});

final journeysProvider = FutureProvider.autoDispose<List<Journey>>((ref) {
  return ref.watch(journeyRepositoryProvider).list();
});

final journeyProvider = FutureProvider.autoDispose.family<Journey, String>((ref, id) {
  return ref.watch(journeyRepositoryProvider).show(id);
});

final roadReportCatalogueProvider = FutureProvider.autoDispose<List<RoadReportType>>((ref) {
  return ref.watch(journeyRepositoryProvider).roadReportCatalogue();
});
