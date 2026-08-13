import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/stolen/domain/stolen_models.dart';

class StolenRepository {
  const StolenRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<StolenReport>> mine() async {
    return _list('/stolen/mine');
  }

  Future<StolenDirectoryPage> directory({
    StolenDirectoryFilters filters = const StolenDirectoryFilters(),
    int page = 1,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/public/stolen',
        queryParameters: {
          if (filters.query?.isNotEmpty == true) 'q': filters.query,
          if (filters.location?.isNotEmpty == true)
            'location': filters.location,
          if (filters.make?.isNotEmpty == true) 'make': filters.make,
          if (filters.color?.isNotEmpty == true) 'color': filters.color,
          if (filters.hasReward) 'has_reward': true,
          if (filters.reportedWithinDays != null)
            'reported_within': filters.reportedWithinDays,
          'sort': filters.sort,
          'page': page,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      final meta = body['meta'];
      final items = data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(StolenReport.fromJson)
                .toList(growable: false)
          : const <StolenReport>[];
      final metaMap = meta is Map ? meta.cast<String, dynamic>() : null;
      return StolenDirectoryPage(
        items: items,
        page: (metaMap?['current_page'] as num?)?.toInt() ?? page,
        lastPage: (metaMap?['last_page'] as num?)?.toInt() ?? page,
        total: (metaMap?['total'] as num?)?.toInt() ?? items.length,
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<StolenStats> stats() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/public/stolen/stats',
      );
      return StolenStats.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<StolenCheckResult> checkPlate(String plate) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/public/stolen/check',
        queryParameters: {'plate': plate.trim()},
      );
      return StolenCheckResult.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<StolenReport> show(String reportId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/stolen/$reportId',
      );
      return StolenReport.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<StolenReport> report({
    required String vehicleId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/vehicles/$vehicleId/stolen-report',
        data: payload,
      );
      return StolenReport.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> recover(String reportId) => _post('/stolen/$reportId/recover');
  Future<void> close(String reportId) => _post('/stolen/$reportId/close');
  Future<void> verifySighting(String sightingId) =>
      _post('/stolen/sightings/$sightingId/verify');
  Future<void> dismissSighting(String sightingId) =>
      _post('/stolen/sightings/$sightingId/dismiss');

  Future<void> reportSighting({
    required String reportId,
    required Map<String, dynamic> fields,
    List<PlatformFile> photos = const [],
  }) async {
    try {
      final form = FormData.fromMap({
        ...fields,
        for (final photo in photos)
          if (photo.path != null)
            'photos[]': await MultipartFile.fromFile(
              photo.path!,
              filename: photo.name,
            ),
      });
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/stolen/$reportId/sightings',
        data: form,
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<StolenReport>> _list(String path) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(path);
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(StolenReport.fromJson)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> _post(String path) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(path);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry('$k', v));
    throw const ApiFailure(
      'Travla returned an unexpected stolen-registry response.',
    );
  }
}

final stolenRepositoryProvider = Provider<StolenRepository>((ref) {
  return StolenRepository(ref.watch(apiClientProvider));
});

final myStolenReportsProvider = FutureProvider.autoDispose<List<StolenReport>>((
  ref,
) {
  return ref.watch(stolenRepositoryProvider).mine();
});

final stolenReportProvider = FutureProvider.autoDispose
    .family<StolenReport, String>((ref, reportId) {
      return ref.watch(stolenRepositoryProvider).show(reportId);
    });

final stolenStatsProvider = FutureProvider.autoDispose<StolenStats>((ref) {
  return ref.watch(stolenRepositoryProvider).stats();
});
