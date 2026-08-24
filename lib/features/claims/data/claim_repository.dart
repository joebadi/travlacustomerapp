import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/claims/domain/claim_models.dart';

/// Thrown when the claims feature is gated off for this user (staged rollout).
class ClaimsUnavailable implements Exception {
  const ClaimsUnavailable();
}

class ClaimRepository {
  const ClaimRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ClaimMeta> meta() async {
    return _guard(() async {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/claims/meta',
      );
      return ClaimMeta.fromJson(_dataMap(response.data));
    });
  }

  Future<List<InsuranceClaim>> list() async {
    return _guard(() async {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/claims');
      return _dataList(response.data)
          .map(InsuranceClaim.fromJson)
          .toList(growable: false);
    });
  }

  Future<InsuranceClaim> show(String claimId) async {
    return _guard(() async {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/claims/$claimId',
      );
      return InsuranceClaim.fromJson(_dataMap(response.data));
    });
  }

  Future<InsuranceClaim> createDraft({
    required String vehicleId,
    required Map<String, dynamic> payload,
  }) async {
    return _guard(() async {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/vehicles/$vehicleId/claims',
        data: payload,
      );
      return InsuranceClaim.fromJson(_dataMap(response.data));
    });
  }

  Future<InsuranceClaim> updateDraft({
    required String claimId,
    required Map<String, dynamic> payload,
  }) async {
    return _guard(() async {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/claims/$claimId',
        data: payload,
      );
      return InsuranceClaim.fromJson(_dataMap(response.data));
    });
  }

  Future<InsuranceClaim> uploadEvidence({
    required String claimId,
    required PlatformFile file,
    required String fileType,
    String? docSlug,
    String? description,
  }) async {
    return _guard(() async {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path!, filename: file.name),
        'file_type': fileType,
        'doc_slug': ?docSlug,
        'description': ?description,
      });
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/claims/$claimId/evidence',
        data: form,
      );
      return InsuranceClaim.fromJson(_dataMap(response.data));
    });
  }

  Future<void> removeEvidence(String evidenceId) async {
    return _guard(() async {
      await _apiClient.dio.delete('/claims/evidence/$evidenceId');
    });
  }

  Future<InsuranceClaim> submit(String claimId) async {
    return _guard(() async {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/claims/$claimId/submit',
      );
      return InsuranceClaim.fromJson(_dataMap(response.data));
    });
  }

  Future<void> destroy(String claimId) async {
    return _guard(() async {
      await _apiClient.dio.delete('/claims/$claimId');
    });
  }

  Future<ClaimThread> messages(String claimId) async {
    return _guard(() async {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/claims/$claimId/messages',
      );
      final data = _dataMap(response.data);
      final messages = data['messages'];
      return ClaimThread(
        alias: data['alias']?.toString(),
        messages: (messages is List ? messages : const [])
            .whereType<Map>()
            .map((e) => ClaimMessage.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false),
      );
    });
  }

  Future<void> postMessage({
    required String claimId,
    required String body,
    String? subject,
  }) async {
    return _guard(() async {
      await _apiClient.dio.post(
        '/claims/$claimId/messages',
        data: {'body': body.trim(), 'subject': ?subject},
      );
    });
  }

  Future<void> openDispute({
    required String claimId,
    required String reason,
    required String description,
  }) async {
    return _guard(() async {
      await _apiClient.dio.post(
        '/claims/$claimId/disputes',
        data: {'reason': reason.trim(), 'description': description.trim()},
      );
    });
  }

  Future<void> escalateDispute(String disputeId) async {
    return _guard(() async {
      await _apiClient.dio.post('/claims/disputes/$disputeId/escalate');
    });
  }

  /// Authoritative pre-flight verdict: can a claim on [vehicleId] actually
  /// benefit the user, given fault and whether the other party is insured?
  Future<ClaimEligibility> eligibility({
    required String vehicleId,
    required bool thirdPartyInvolved,
    String? fault,
    required bool otherPartyInsured,
    String? claimType,
  }) async {
    return _guard(() async {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/vehicles/$vehicleId/claim-eligibility',
        data: {
          'third_party_involved': thirdPartyInvolved,
          'fault': ?fault,
          'other_party_insured': otherPartyInsured,
          'claim_type': ?claimType,
        },
      );
      return ClaimEligibility.fromJson(_dataMap(response.data));
    });
  }

  /// Uploads a locally-captured file (camera photo/video, gallery pick) to a
  /// claim draft. Used by the scene-capture step, which holds media on-device
  /// until the draft exists.
  Future<void> uploadEvidencePath({
    required String claimId,
    required String path,
    required String filename,
    required String fileType,
  }) async {
    return _guard(() async {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: filename),
        'file_type': fileType,
      });
      await _apiClient.dio.post('/claims/$claimId/evidence', data: form);
    });
  }

  Future<PlateCheckResult> plateCheck(String plate) async {
    return _guard(() async {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/claims/plate-check',
        data: {'plate': plate.trim()},
      );
      return PlateCheckResult.fromJson(_dataMap(response.data));
    });
  }

  /// Runs [action], mapping a rollout 403 to [ClaimsUnavailable] and any other
  /// Dio error to an [ApiFailure].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (exception) {
      final response = exception.response;
      final payload = response?.data;
      if (response?.statusCode == 403 &&
          payload is Map &&
          payload['coming_soon'] == true) {
        throw const ClaimsUnavailable();
      }
      throw ApiFailure.fromDio(exception);
    }
  }

  List<Map<String, dynamic>> _dataList(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is! List) return const [];
    return data.map(_map).whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic>? envelope) {
    final data = _map(envelope?['data']);
    if (data == null) {
      throw const ApiFailure('Travla returned an unexpected claims response.');
    }
    return data;
  }
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return null;
}

final claimRepositoryProvider = Provider<ClaimRepository>((ref) {
  return ClaimRepository(ref.watch(apiClientProvider));
});

final claimMetaProvider = FutureProvider.autoDispose<ClaimMeta>((ref) {
  return ref.watch(claimRepositoryProvider).meta();
});

final claimsListProvider = FutureProvider.autoDispose<List<InsuranceClaim>>((
  ref,
) {
  return ref.watch(claimRepositoryProvider).list();
});

final claimDetailProvider = FutureProvider.autoDispose
    .family<InsuranceClaim, String>((ref, claimId) {
      return ref.watch(claimRepositoryProvider).show(claimId);
    });

final claimThreadProvider = FutureProvider.autoDispose
    .family<ClaimThread, String>((ref, claimId) {
      return ref.watch(claimRepositoryProvider).messages(claimId);
    });
