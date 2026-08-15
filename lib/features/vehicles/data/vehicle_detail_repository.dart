import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_detail.dart';

class VehicleDetailRepository {
  VehicleDetailRepository(this._apiClient);

  final ApiClient _apiClient;

  static const _verificationCachePrefix = 'document_verification_cache_v1';
  static const _verificationCacheLifetime = Duration(days: 7);

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

  Future<List<String>> states() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/catalogue/states',
      );
      final data = response.data?['data'];
      if (data is! List) {
        throw const ApiFailure('Travla returned an unexpected state list.');
      }
      return data
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<IssuingAuthorityOption>> issuingAuthorities({
    required String documentType,
    required String state,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/catalogue/issuing-authorities',
        queryParameters: {'document_type': documentType, 'state': state},
      );
      final data = response.data?['data'];
      if (data is! List) {
        throw const ApiFailure(
          'Travla returned an unexpected authority catalogue.',
        );
      }
      return data
          .whereType<Map>()
          .map(
            (item) => IssuingAuthorityOption.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.id.isNotEmpty)
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
    String? issuingAuthorityId,
    String? issuingState,
    DateTime? issuedDate,
    String? filePath,
    String? fileName,
    ProgressCallback? onProgress,
  }) async {
    final form = FormData();
    form.fields.add(MapEntry('document_type', documentType));
    if (documentNumber?.trim().isNotEmpty == true) {
      form.fields.add(MapEntry('document_number', documentNumber!.trim()));
    }
    if (issuingAuthority?.trim().isNotEmpty == true) {
      form.fields.add(MapEntry('issuing_authority', issuingAuthority!.trim()));
    }
    if (issuingAuthorityId?.trim().isNotEmpty == true) {
      form.fields.add(
        MapEntry('issuing_authority_id', issuingAuthorityId!.trim()),
      );
    }
    if (issuingState?.trim().isNotEmpty == true) {
      form.fields.add(MapEntry('issuing_state', issuingState!.trim()));
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
        onSendProgress: onProgress,
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

  Future<DocumentVerificationWorkspace> loadDocumentVerification({
    required String vehicleId,
    required String documentId,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/vehicles/$vehicleId/documents/$documentId/verification',
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure(
          'Travla returned an unexpected verification record.',
        );
      }
      final cachedAt = DateTime.now().toUtc();
      await _writeVerificationCache(
        vehicleId: vehicleId,
        documentId: documentId,
        data: data,
        cachedAt: cachedAt,
      );
      return DocumentVerificationWorkspace.fromJson(data, cachedAt: cachedAt);
    } on DioException catch (exception) {
      final status = exception.response?.statusCode;
      final mayUseCache = exception.response == null || (status ?? 0) >= 500;
      if (mayUseCache) {
        final cached = await _readVerificationCache(
          vehicleId: vehicleId,
          documentId: documentId,
        );
        if (cached != null) return cached;
      }
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> _writeVerificationCache({
    required String vehicleId,
    required String documentId,
    required Map<String, dynamic> data,
    required DateTime cachedAt,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _verificationCacheKey(vehicleId, documentId),
        jsonEncode({'cached_at': cachedAt.toIso8601String(), 'data': data}),
      );
    } catch (_) {
      // Caching is a convenience; a device storage failure must never block
      // the live verification response.
    }
  }

  Future<DocumentVerificationWorkspace?> _readVerificationCache({
    required String vehicleId,
    required String documentId,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = _verificationCacheKey(vehicleId, documentId);
      final encoded = preferences.getString(key);
      if (encoded == null) return null;
      final wrapper = jsonDecode(encoded);
      if (wrapper is! Map) return null;
      final cachedAt = DateTime.tryParse(
        wrapper['cached_at']?.toString() ?? '',
      );
      final rawData = wrapper['data'];
      if (cachedAt == null ||
          DateTime.now().toUtc().difference(cachedAt) >
              _verificationCacheLifetime ||
          rawData is! Map) {
        await preferences.remove(key);
        return null;
      }
      return DocumentVerificationWorkspace.fromJson(
        Map<String, dynamic>.from(rawData),
        isFromCache: true,
        cachedAt: cachedAt,
      );
    } catch (_) {
      return null;
    }
  }

  String _verificationCacheKey(String vehicleId, String documentId) =>
      '$_verificationCachePrefix:$vehicleId:$documentId';

  Future<DocumentVerificationSummary> recheckDocument({
    required String vehicleId,
    required String documentId,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/vehicles/$vehicleId/documents/$documentId/verification/recheck',
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure(
          'Travla could not confirm the verification request.',
        );
      }
      return DocumentVerificationSummary.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> updateVehicle({
    required String vehicleId,
    required String make,
    required String model,
    required int year,
    required String color,
    required String plateNumber,
    required String engineNumber,
    required String category,
    required bool isTinted,
    required String description,
    required String changeReason,
    required List<VehicleImageUpload> newImages,
    required List<String> removedImages,
  }) async {
    final form = FormData();
    form.fields.addAll([
      const MapEntry('_method', 'PATCH'),
      MapEntry('make', make.trim()),
      MapEntry('model', model.trim()),
      MapEntry('year', year.toString()),
      MapEntry('color', color.trim()),
      MapEntry('plate_number', plateNumber.trim()),
      MapEntry('engine_number', engineNumber.trim()),
      MapEntry('vehicle_category', category),
      MapEntry('is_tinted', isTinted ? '1' : '0'),
      MapEntry('description', description.trim()),
      MapEntry('change_reason', changeReason.trim()),
    ]);
    for (final image in newImages) {
      form.files.add(
        MapEntry(
          'images[]',
          await MultipartFile.fromFile(image.path, filename: image.name),
        ),
      );
    }
    for (final imageUrl in removedImages) {
      form.fields.add(MapEntry('remove_images[]', imageUrl));
    }

    try {
      await _apiClient.dio.post<void>('/vehicles/$vehicleId', data: form);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }
}

class VehicleImageUpload {
  const VehicleImageUpload({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;
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

final vehicleDocumentStatesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) {
  return ref.watch(vehicleDetailRepositoryProvider).states();
});

typedef IssuingAuthorityKey = ({String documentType, String state});

final issuingAuthoritiesProvider = FutureProvider.autoDispose
    .family<List<IssuingAuthorityOption>, IssuingAuthorityKey>((ref, key) {
      return ref
          .watch(vehicleDetailRepositoryProvider)
          .issuingAuthorities(documentType: key.documentType, state: key.state);
    });

typedef DocumentVerificationKey = ({String vehicleId, String documentId});

final documentVerificationProvider = FutureProvider.autoDispose
    .family<DocumentVerificationWorkspace, DocumentVerificationKey>((ref, key) {
      return ref
          .watch(vehicleDetailRepositoryProvider)
          .loadDocumentVerification(
            vehicleId: key.vehicleId,
            documentId: key.documentId,
          );
    });

void refreshVehicleWorkspace(Ref ref, String vehicleId) {
  ref.invalidate(vehicleDetailProvider(vehicleId));
  ref.invalidate(availableDocumentTypesProvider(vehicleId));
  ref.invalidate(garageProvider);
}
