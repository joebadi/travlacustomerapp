import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/transfers/domain/transfer_models.dart';

class TransferRepository {
  const TransferRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<TransferSetup> setup() async {
    try {
      final responses = await Future.wait([
        _apiClient.dio.get<Map<String, dynamic>>('/catalogue/service-cities'),
        _apiClient.dio.get<Map<String, dynamic>>('/transfer-config'),
      ]);
      final data = responses[0].data?['data'];
      final config = responses[1].data?['data'];
      if (data is! List || config is! Map<String, dynamic>) {
        throw const ApiFailure('Transfer cities could not be loaded.');
      }
      final rawFields = config['document_fields_by_basis'];
      final fields = <String, List<TransferDocumentField>>{};
      if (rawFields is Map) {
        for (final entry in rawFields.entries) {
          final value = entry.value;
          fields[entry.key.toString()] = value is List
              ? value
                    .whereType<Map<String, dynamic>>()
                    .map(TransferDocumentField.fromJson)
                    .where((item) => item.key.isNotEmpty)
                    .toList(growable: false)
              : const [];
        }
      }
      return TransferSetup(
        cities: data
            .whereType<Map<String, dynamic>>()
            .map(TransferCity.fromJson)
            .where((item) => item.city.isNotEmpty)
            .toList(growable: false),
        fieldsByBasis: fields,
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<TransferRecord>> list() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/transfers',
        queryParameters: const {'per_page': 50},
      );
      final data = response.data?['data'];
      if (data is! List) {
        throw const ApiFailure('Your ownership transfers could not be loaded.');
      }
      return data
          .whereType<Map<String, dynamic>>()
          .map(TransferRecord.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<TransferRecord> detail(String transferId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/transfers/$transferId',
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('This ownership transfer could not be loaded.');
      }
      return TransferRecord.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> cancel(String transferId) =>
      _postAction('/transfers/$transferId/cancel');

  Future<void> verifyConsent(String transferId, String otp) =>
      _postAction('/transfers/$transferId/verify-consent', data: {'otp': otp});

  Future<void> resendConsent(String transferId) =>
      _postAction('/transfers/$transferId/resend-consent');

  Future<void> _postAction(String path, {Map<String, dynamic>? data}) async {
    try {
      await _apiClient.dio.post<void>(path, data: data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<TransferReadiness> readiness({
    required String vehicleId,
    required String mode,
    required String deliveryMethod,
    required String city,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/vehicles/$vehicleId/transfer-readiness',
        queryParameters: {
          'mode': mode,
          'delivery_method': deliveryMethod,
          if (city.isNotEmpty) 'city': city,
        },
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('Transfer readiness could not be confirmed.');
      }
      return TransferReadiness.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<TransferRecipientMatch> lookup({
    required String phone,
    String? email,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/transfers/recipient-lookup',
        data: {
          'phone': phone.trim(),
          if (email?.trim().isNotEmpty == true) 'email': email!.trim(),
        },
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('The recipient lookup could not be completed.');
      }
      return TransferRecipientMatch.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<String> create(
    Map<String, dynamic> payload, {
    List<TransferEvidenceUpload> evidence = const [],
  }) async {
    final form = FormData();
    for (final entry in payload.entries) {
      form.fields.add(MapEntry(entry.key, entry.value.toString()));
    }
    for (final item in evidence) {
      form.files.add(
        MapEntry(
          'documents[${item.key}]',
          await MultipartFile.fromFile(item.path, filename: item.name),
        ),
      );
      if (item.documentNumber.trim().isNotEmpty) {
        form.fields.add(
          MapEntry(
            'document_metadata[${item.key}][document_number]',
            item.documentNumber.trim(),
          ),
        );
      }
      if (item.issuer.trim().isNotEmpty) {
        form.fields.add(
          MapEntry(
            'document_metadata[${item.key}][issuer]',
            item.issuer.trim(),
          ),
        );
      }
      if (item.issueDate != null) {
        form.fields.add(
          MapEntry(
            'document_metadata[${item.key}][issue_date]',
            _apiDate(item.issueDate!),
          ),
        );
      }
    }
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/transfers',
        data: form,
      );
      final id = response.data?['data']?['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const ApiFailure(
          'The transfer was submitted but could not be opened.',
        );
      }
      return id;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }
}

String _apiDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

final transferRepositoryProvider = Provider<TransferRepository>(
  (ref) => TransferRepository(ref.watch(apiClientProvider)),
);
final transferSetupProvider = FutureProvider.autoDispose<TransferSetup>(
  (ref) => ref.watch(transferRepositoryProvider).setup(),
);
final transferListProvider = FutureProvider.autoDispose<List<TransferRecord>>(
  (ref) => ref.watch(transferRepositoryProvider).list(),
);
final transferDetailProvider = FutureProvider.autoDispose
    .family<TransferRecord, String>(
      (ref, transferId) =>
          ref.watch(transferRepositoryProvider).detail(transferId),
    );
