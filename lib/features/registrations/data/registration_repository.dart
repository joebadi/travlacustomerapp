import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/registrations/domain/registration_models.dart';

class RegistrationRepository {
  const RegistrationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<RegistrationSetup> setup() async {
    try {
      final responses = await Future.wait([
        _apiClient.dio.get<Map<String, dynamic>>('/registrations/config'),
        _apiClient.dio.get<Map<String, dynamic>>('/catalogue/service-cities'),
      ]);
      final config = responses[0].data?['data'];
      final cities = responses[1].data?['data'];
      if (config is! Map<String, dynamic> || cities is! List) {
        throw const ApiFailure(
          'Travla returned invalid registration settings.',
        );
      }
      final rawFields = config['document_fields'];
      final rawOptions = config['options'];
      return RegistrationSetup(
        baseFeeNaira: config['base_fee_naira']?.toString() ?? '0.00',
        customPlateFeeNaira:
            config['custom_plate_fee_naira']?.toString() ?? '0.00',
        documentFields: rawFields is List
            ? rawFields
                  .whereType<Map<String, dynamic>>()
                  .map(RegistrationDocumentField.fromJson)
                  .where((field) => field.key.isNotEmpty)
                  .toList(growable: false)
            : const [],
        options: rawOptions is List
            ? rawOptions
                  .whereType<Map<String, dynamic>>()
                  .map(RegistrationOption.fromJson)
                  .where((option) => option.key.isNotEmpty)
                  .toList(growable: false)
            : const [],
        serviceCities: cities
            .whereType<Map<String, dynamic>>()
            .map(ServiceCity.fromJson)
            .where((city) => city.city.isNotEmpty && city.state.isNotEmpty)
            .toList(growable: false),
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<RegistrationQuote> quote({
    required String make,
    required String model,
    required String plateType,
    required List<String> options,
    required String deliveryMethod,
    required String city,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/registrations/quote',
        data: {
          'make': make,
          'model': model,
          'plate_type': plateType,
          'options': options,
          'delivery_method': deliveryMethod,
          'city': city,
        },
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure(
          'Travla returned an invalid registration quote.',
        );
      }
      return RegistrationQuote.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<RegistrationCreated> create({
    required Map<String, String> fields,
    required List<String> options,
    required List<PlatformFile> images,
    required Map<String, PlatformFile> documents,
  }) async {
    try {
      final form = FormData();
      fields.forEach((key, value) {
        if (value.isNotEmpty) form.fields.add(MapEntry(key, value));
      });
      for (final option in options) {
        form.fields.add(MapEntry('options[]', option));
      }
      for (final image in images) {
        form.files.add(MapEntry('images[]', await _multipartFile(image)));
      }
      for (final document in documents.entries) {
        form.files.add(
          MapEntry(
            'documents[${document.key}]',
            await _multipartFile(document.value),
          ),
        );
      }
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/registrations',
        data: form,
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure(
          'The registration was submitted but could not be opened.',
        );
      }
      return RegistrationCreated.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<MultipartFile> _multipartFile(PlatformFile file) async {
    if (file.path?.isNotEmpty == true) {
      return MultipartFile.fromFile(file.path!, filename: file.name);
    }
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }
    throw ApiFailure('${file.name} could not be read. Please select it again.');
  }
}

final registrationRepositoryProvider = Provider<RegistrationRepository>((ref) {
  return RegistrationRepository(ref.watch(apiClientProvider));
});

final registrationSetupProvider = FutureProvider.autoDispose<RegistrationSetup>(
  (ref) => ref.watch(registrationRepositoryProvider).setup(),
);
