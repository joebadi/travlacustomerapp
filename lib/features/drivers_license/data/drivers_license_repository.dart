import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/drivers_license/domain/drivers_license.dart';

class DriversLicenseRepository {
  const DriversLicenseRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<DriversLicense>> list() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/drivers-licenses',
      );
      final data = response.data?['data'];
      if (data is! List) {
        throw const ApiFailure('Your driver\'s licences could not be loaded.');
      }
      return data
          .map(_map)
          .whereType<Map<String, dynamic>>()
          .map(DriversLicense.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<DriversLicense> create({
    required String licenseNumber,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String address,
    required String city,
    required String state,
    required String licenseClass,
    required String issueDate,
    required String expiryDate,
    PlatformFile? document,
  }) async {
    try {
      final form = FormData.fromMap({
        'license_number': licenseNumber.trim(),
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'date_of_birth': dateOfBirth,
        'address': address.trim(),
        'city': city.trim(),
        'state': state,
        'license_class': licenseClass,
        'issue_date': issueDate,
        'expiry_date': expiryDate,
        if (document?.path != null)
          'document': await MultipartFile.fromFile(
            document!.path!,
            filename: document.name,
          ),
      });
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/drivers-licenses',
        data: form,
      );
      return DriversLicense.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<LicenseRenewalQuote> quote({
    required String licenseId,
    required String state,
    required String deliveryMethod,
    required String city,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/license-renewals/quote',
        data: {
          'drivers_license_id': licenseId,
          'state': state,
          'delivery_method': deliveryMethod,
          'city': city,
        },
      );
      return LicenseRenewalQuote.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /// Creates the renewal and returns the order group id to open its order screen.
  Future<String> createRenewal({
    required String licenseId,
    required String deliveryMethod,
    required String city,
    required String state,
    required String address,
    required String notes,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/license-renewals',
        data: {
          'drivers_license_id': licenseId,
          'delivery_method': deliveryMethod,
          'delivery_address': deliveryMethod == 'DELIVERY'
              ? address.trim()
              : null,
          'city': city,
          'state': state,
          'notes': notes.trim().isEmpty ? null : notes.trim(),
        },
      );
      final data = _dataMap(response.data);
      return data['order_group_id']?.toString() ?? '';
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic>? envelope) {
    final data = _map(envelope?['data']);
    if (data == null) {
      throw const ApiFailure('Travla returned an unexpected licence response.');
    }
    return data;
  }
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return null;
}

final driversLicenseRepositoryProvider = Provider<DriversLicenseRepository>((
  ref,
) {
  return DriversLicenseRepository(ref.watch(apiClientProvider));
});

final driversLicensesProvider =
    FutureProvider.autoDispose<List<DriversLicense>>((ref) {
      return ref.watch(driversLicenseRepositoryProvider).list();
    });
