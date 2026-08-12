import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';

class InsuranceRepository {
  const InsuranceRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<InsuranceCompany>> insurers() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/insurance/insurers',
      );
      return _list(response.data).map(InsuranceCompany.fromJson).toList();
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<InsurancePolicy>> expiring({int days = 45}) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/insurance/policies/expiring',
        queryParameters: {'days': days},
      );
      return _list(response.data).map(InsurancePolicy.fromJson).toList();
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /// Verification status + saved policies for a vehicle. Opening the tab runs a
  /// cache-aware check; the backend only calls the external source when due.
  Future<VehicleInsurance> forVehicle(String vehicleId) =>
      _verification('/vehicles/$vehicleId/insurance-verification', post: false);

  /// Force a fresh third-party check ("Check now").
  Future<VehicleInsurance> verify(String vehicleId) =>
      _verification('/vehicles/$vehicleId/insurance-verification', post: true);

  Future<VehicleInsurance> _verification(
    String path, {
    required bool post,
  }) async {
    try {
      final response = post
          ? await _apiClient.dio.post<Map<String, dynamic>>(path)
          : await _apiClient.dio.get<Map<String, dynamic>>(path);
      final data = _dataMap(response.data);
      final verification = _map(data['verification']) ?? const {};
      final policies = data['policies'];
      return VehicleInsurance(
        verification: InsuranceVerification.fromJson(
          verification.cast<String, dynamic>(),
        ),
        policies: (policies is List ? policies : const [])
            .map(_map)
            .whereType<Map<String, dynamic>>()
            .map(InsurancePolicy.fromJson)
            .toList(growable: false),
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<InsurancePolicy> addPolicy({
    required String vehicleId,
    String? insuranceCompanyId,
    required String provider,
    required String policyNumber,
    required String coverageType,
    required String startDate,
    required String endDate,
    int? premiumKobo,
    int? excessKobo,
    PlatformFile? document,
  }) async {
    try {
      final form = FormData.fromMap({
        if (insuranceCompanyId != null && insuranceCompanyId.isNotEmpty)
          'insurance_company_id': insuranceCompanyId,
        'provider': provider.trim(),
        'policy_number': policyNumber.trim(),
        'coverage_type': coverageType,
        'start_date': startDate,
        'end_date': endDate,
        'premium_kobo': ?premiumKobo,
        'excess_kobo': ?excessKobo,
        if (document?.path != null)
          'document': await MultipartFile.fromFile(
            document!.path!,
            filename: document.name,
          ),
      });
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/vehicles/$vehicleId/insurance-policies',
        data: form,
      );
      return InsurancePolicy.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /// Edits a saved policy — including NIID-verified ones — and optionally
  /// attaches/replaces its certificate. Sent as POST with `_method=PATCH`
  /// (Laravel method-spoofing): PHP does not populate uploaded files for a
  /// genuine multipart PATCH request, only POST, so a real PATCH verb would
  /// silently drop the document. Mirrors the web's useUpdatePolicy exactly.
  Future<InsurancePolicy> updatePolicy({
    required String policyId,
    String? insuranceCompanyId,
    String? provider,
    String? policyNumber,
    String? coverageType,
    String? startDate,
    String? endDate,
    int? premiumKobo,
    int? excessKobo,
    PlatformFile? document,
  }) async {
    try {
      final form = FormData.fromMap({
        '_method': 'PATCH',
        'insurance_company_id': ?insuranceCompanyId,
        if (provider != null) 'provider': provider.trim(),
        if (policyNumber != null) 'policy_number': policyNumber.trim(),
        'coverage_type': ?coverageType,
        'start_date': ?startDate,
        'end_date': ?endDate,
        'premium_kobo': ?premiumKobo,
        'excess_kobo': ?excessKobo,
        if (document?.path != null)
          'document': await MultipartFile.fromFile(
            document!.path!,
            filename: document.name,
          ),
      });
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/insurance/policies/$policyId',
        data: form,
      );
      return InsurancePolicy.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /// Whether insurance is fulfilled instantly (automated provider) or by an
  /// agent (physical handover, delivery fee) — drives the checkout UI.
  Future<bool> renewalAutomated() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/insurance/renewal-method',
      );
      return _dataMap(response.data)['automated'] == true;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<InsuranceRenewalQuote> renewQuote({
    required String policyId,
    required String state,
    required String deliveryMethod,
    required String city,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/insurance-renewals/quote',
        data: {
          'insurance_policy_id': policyId,
          'state': state,
          'delivery_method': deliveryMethod,
          'city': city,
        },
      );
      return InsuranceRenewalQuote.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  /// Creates the renewal and returns the order group id to open its order screen.
  Future<String> renew({
    required String policyId,
    required String deliveryMethod,
    required String city,
    required String state,
    required String address,
    required String notes,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/insurance-renewals',
        data: {
          'insurance_policy_id': policyId,
          'delivery_method': deliveryMethod,
          'delivery_address': deliveryMethod == 'DELIVERY'
              ? address.trim()
              : null,
          'city': city,
          'state': state,
          'notes': notes.trim().isEmpty ? null : notes.trim(),
        },
      );
      return _dataMap(response.data)['order_group_id']?.toString() ?? '';
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<InsuranceBuyQuote> buyQuote({
    required String vehicleId,
    required String coverageType,
    required bool automated,
    String state = '',
    String deliveryMethod = 'PICKUP',
    String city = '',
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/vehicles/$vehicleId/insurance-purchase/quote',
        data: {
          'coverage_type': coverageType,
          if (!automated) 'state': state,
          if (!automated) 'delivery_method': deliveryMethod,
          if (!automated) 'city': city,
        },
      );
      return InsuranceBuyQuote.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<String> buy({
    required String vehicleId,
    required String coverageType,
    required bool automated,
    String deliveryMethod = 'PICKUP',
    String city = '',
    String state = '',
    String address = '',
    String notes = '',
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/vehicles/$vehicleId/insurance-purchase',
        data: {
          'coverage_type': coverageType,
          if (!automated) 'delivery_method': deliveryMethod,
          if (!automated) 'city': city,
          if (!automated) 'state': state,
          if (!automated && deliveryMethod == 'DELIVERY')
            'delivery_address': address.trim(),
          if (!automated && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      return _dataMap(response.data)['order_group_id']?.toString() ?? '';
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is! List) return const [];
    return data.map(_map).whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic>? envelope) {
    final data = _map(envelope?['data']);
    if (data == null) {
      throw const ApiFailure('Travla returned an unexpected insurance response.');
    }
    return data;
  }
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return null;
}

final insuranceRepositoryProvider = Provider<InsuranceRepository>((ref) {
  return InsuranceRepository(ref.watch(apiClientProvider));
});

final expiringPoliciesProvider =
    FutureProvider.autoDispose<List<InsurancePolicy>>((ref) {
      return ref.watch(insuranceRepositoryProvider).expiring();
    });

final vehicleInsuranceProvider = FutureProvider.autoDispose
    .family<VehicleInsurance, String>((ref, vehicleId) {
      return ref.watch(insuranceRepositoryProvider).forVehicle(vehicleId);
    });

final insurersProvider = FutureProvider.autoDispose<List<InsuranceCompany>>((
  ref,
) {
  return ref.watch(insuranceRepositoryProvider).insurers();
});

/// True when insurance is issued instantly by an automated provider (no rider
/// delivery); false when an agent fulfils it physically.
final insuranceAutomatedProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(insuranceRepositoryProvider).renewalAutomated();
});
