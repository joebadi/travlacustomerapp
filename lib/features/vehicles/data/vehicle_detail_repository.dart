import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_detail.dart';

class VehicleDetailRepository {
  VehicleDetailRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<VehicleDetail> load(String vehicleId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/vehicles/$vehicleId',
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('Travla returned an unexpected vehicle record.');
      }
      return VehicleDetail.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<AvailableDocumentType>> availableDocumentTypes(
    String vehicleId,
  ) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/vehicles/$vehicleId/available-document-types',
      );
      final data = response.data?['data'];
      if (data is! List) {
        throw const ApiFailure(
          'Travla returned an unexpected document catalogue.',
        );
      }
      return data
          .whereType<Map<String, dynamic>>()
          .map(AvailableDocumentType.fromJson)
          .where((type) => type.type.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> uploadDocument({
    required String vehicleId,
    required String documentType,
    String? documentNumber,
    String? issuingAuthority,
    DateTime? issuedDate,
    String? filePath,
    String? fileName,
  }) async {
    final form = FormData();
    form.fields.add(MapEntry('document_type', documentType));
    if (documentNumber?.trim().isNotEmpty == true) {
      form.fields.add(MapEntry('document_number', documentNumber!.trim()));
    }
    if (issuingAuthority?.trim().isNotEmpty == true) {
      form.fields.add(MapEntry('issuing_authority', issuingAuthority!.trim()));
    }
    if (issuedDate != null) {
      form.fields.add(MapEntry('issued_date', apiDate(issuedDate)));
    }
    if (filePath != null && filePath.isNotEmpty) {
      form.files.add(
        MapEntry(
          'file',
          await MultipartFile.fromFile(filePath, filename: fileName),
        ),
      );
    }

    try {
      await _apiClient.dio.post<void>(
        '/vehicles/$vehicleId/documents',
        data: form,
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> setAutoRenew({
    required String vehicleId,
    required String documentId,
    required bool enabled,
  }) async {
    try {
      await _apiClient.dio.patch<void>(
        '/vehicles/$vehicleId/documents/$documentId/auto-renew',
        data: {'auto_renew': enabled},
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> deleteDocument({
    required String vehicleId,
    required String documentId,
  }) async {
    try {
      await _apiClient.dio.delete<void>(
        '/vehicles/$vehicleId/documents/$documentId',
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }
}

final vehicleDetailRepositoryProvider = Provider<VehicleDetailRepository>((
  ref,
) {
  return VehicleDetailRepository(ref.watch(apiClientProvider));
});

final vehicleDetailProvider = FutureProvider.autoDispose
    .family<VehicleDetail, String>((ref, vehicleId) {
      return ref.watch(vehicleDetailRepositoryProvider).load(vehicleId);
    });

final availableDocumentTypesProvider = FutureProvider.autoDispose
    .family<List<AvailableDocumentType>, String>((ref, vehicleId) {
      return ref
          .watch(vehicleDetailRepositoryProvider)
          .availableDocumentTypes(vehicleId);
    });

void refreshVehicleWorkspace(Ref ref, String vehicleId) {
  ref.invalidate(vehicleDetailProvider(vehicleId));
  ref.invalidate(availableDocumentTypesProvider(vehicleId));
  ref.invalidate(garageProvider);
}
