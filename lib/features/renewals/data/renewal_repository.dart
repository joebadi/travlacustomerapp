import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/renewals/domain/renewal_models.dart';

class RenewalRepository {
  const RenewalRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RenewalServiceCity>> serviceCities() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/catalogue/service-cities',
      );
      final data = response.data?['data'];
      if (data is! List) {
        throw const ApiFailure('Covered renewal cities could not be loaded.');
      }
      return data
          .map(_map)
          .whereType<Map<String, dynamic>>()
          .map(RenewalServiceCity.fromJson)
          .where((item) => item.city.isNotEmpty && item.state.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<RenewableDocumentOption>> renewableDocuments(
    String vehicleId,
  ) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/vehicles/$vehicleId/renewable-documents',
      );
      final data = response.data?['data'];
      if (data is! List) {
        throw const ApiFailure('Renewable papers could not be loaded.');
      }
      return data
          .map(_map)
          .whereType<Map<String, dynamic>>()
          .map(RenewableDocumentOption.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<RenewalQuote> quote({
    required String vehicleId,
    required List<String> documentTypeIds,
    required String state,
    required String deliveryMethod,
    required String city,
    List<String> insuranceRenewPolicyIds = const [],
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/renewals/quote',
        data: {
          'vehicle_id': vehicleId,
          'document_type_ids': documentTypeIds,
          'state': state,
          'delivery_method': deliveryMethod,
          'city': city,
          if (insuranceRenewPolicyIds.isNotEmpty)
            'insurance_renew_policy_ids': insuranceRenewPolicyIds,
        },
      );
      return RenewalQuote.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<RenewalCreated> create({
    required String vehicleId,
    required List<String> documentTypeIds,
    required String deliveryMethod,
    required String city,
    required String state,
    required String address,
    required String notes,
    List<String> insuranceRenewPolicyIds = const [],
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/renewals',
        data: {
          'vehicle_id': vehicleId,
          'document_type_ids': documentTypeIds,
          'delivery_method': deliveryMethod,
          'delivery_address': deliveryMethod == 'DELIVERY'
              ? address.trim()
              : null,
          'city': city,
          'state': state,
          'notes': notes.trim().isEmpty ? null : notes.trim(),
          if (insuranceRenewPolicyIds.isNotEmpty)
            'insurance_renew_policy_ids': insuranceRenewPolicyIds,
        },
      );
      return RenewalCreated.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<RenewalRecord>> list() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/renewals',
        queryParameters: const {'per_page': 50},
      );
      return _records(response.data?['data']);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<RenewalRecord>> order(String groupId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/renewals/orders/$groupId',
      );
      return _records(response.data?['data']);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<RenewalRecord>> cancelOrder(String groupId) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/renewals/orders/$groupId/cancel',
      );
      return _records(response.data?['data']);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  List<RenewalRecord> _records(Object? value) {
    if (value is! List) {
      throw const ApiFailure('Renewal records could not be loaded.');
    }
    return value
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .map(RenewalRecord.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic>? envelope) {
    final data = _map(envelope?['data']);
    if (data == null) {
      throw const ApiFailure('Travla returned an unexpected renewal response.');
    }
    return data;
  }
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return null;
}

final renewalRepositoryProvider = Provider<RenewalRepository>((ref) {
  return RenewalRepository(ref.watch(apiClientProvider));
});

final renewalServiceCitiesProvider =
    FutureProvider.autoDispose<List<RenewalServiceCity>>((ref) {
      return ref.watch(renewalRepositoryProvider).serviceCities();
    });

final renewableDocumentsProvider = FutureProvider.autoDispose
    .family<List<RenewableDocumentOption>, String>((ref, vehicleId) {
      return ref.watch(renewalRepositoryProvider).renewableDocuments(vehicleId);
    });

final renewalOrdersProvider = FutureProvider.autoDispose<List<RenewalRecord>>((
  ref,
) {
  return ref.watch(renewalRepositoryProvider).list();
});

final renewalOrderProvider = FutureProvider.autoDispose
    .family<List<RenewalRecord>, String>((ref, groupId) {
      return ref.watch(renewalRepositoryProvider).order(groupId);
    });
