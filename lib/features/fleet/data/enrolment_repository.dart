import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/domain/enrolment_models.dart';

/// Client for the fleet enrolment-consent flow — org-side requests and the
/// owner-side approve/decline/revoke actions.
class EnrolmentRepository {
  const EnrolmentRepository(this._apiClient);

  final ApiClient _apiClient;

  /* ------------------------------ Org side ------------------------------ */

  Future<VehicleEnrolment> request(
    String organisationId, {
    required String plateNumber,
    String? regionId,
    String? department,
    String? message,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/fleet/$organisationId/enrolments',
        data: {
          'plate_number': plateNumber.trim(),
          if (regionId != null && regionId.isNotEmpty) 'org_region_id': regionId,
          if (department != null && department.trim().isNotEmpty)
            'department': department.trim(),
          if (message != null && message.trim().isNotEmpty)
            'message': message.trim(),
        },
      );
      return VehicleEnrolment.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<VehicleEnrolment>> forOrg(String organisationId) async {
    return _list('/fleet/$organisationId/enrolments');
  }

  Future<void> cancel(String organisationId, String enrolmentId) async {
    try {
      await _apiClient.dio.delete<Map<String, dynamic>>(
        '/fleet/$organisationId/enrolments/$enrolmentId',
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /* ----------------------------- Owner side ----------------------------- */

  Future<List<VehicleEnrolment>> pending() => _list('/vehicle-enrolments/pending');

  Future<List<VehicleEnrolment>> mine() => _list('/vehicle-enrolments');

  Future<VehicleEnrolment> approve(String id) => _action(id, 'approve');
  Future<VehicleEnrolment> decline(String id) => _action(id, 'decline');
  Future<VehicleEnrolment> revoke(String id) => _action(id, 'revoke');

  Future<VehicleEnrolment> _action(String id, String verb) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/vehicle-enrolments/$id/$verb',
      );
      return VehicleEnrolment.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<VehicleEnrolment>> _list(String path) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(path);
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((e) => VehicleEnrolment.fromJson(e.map((k, v) => MapEntry('$k', v))))
          .where((e) => e.id.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry('$k', v));
    throw const ApiFailure('Travla returned an unexpected enrolment response.');
  }
}

final enrolmentRepositoryProvider = Provider<EnrolmentRepository>((ref) {
  return EnrolmentRepository(ref.watch(apiClientProvider));
});

/// Requests awaiting the signed-in owner's decision.
final pendingEnrolmentsProvider =
    FutureProvider.autoDispose<List<VehicleEnrolment>>((ref) {
      return ref.watch(enrolmentRepositoryProvider).pending();
    });

/// Every enrolment touching a vehicle the owner owns (history + active links).
final myEnrolmentsProvider =
    FutureProvider.autoDispose<List<VehicleEnrolment>>((ref) {
      return ref.watch(enrolmentRepositoryProvider).mine();
    });

/// Enrolment requests raised by an organisation.
final orgEnrolmentsProvider = FutureProvider.autoDispose
    .family<List<VehicleEnrolment>, String>((ref, orgId) {
      return ref.watch(enrolmentRepositoryProvider).forOrg(orgId);
    });
