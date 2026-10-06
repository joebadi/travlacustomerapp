import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/domain/fleet_models.dart';

class FleetRepository {
  const FleetRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<FleetHome> home() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>('/fleet');
      return FleetHome.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<String> createOrganisation({
    required String name,
    String? registrationNumber,
    String? billingAddress,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/fleet',
        data: {
          'name': name.trim(),
          if (registrationNumber != null &&
              registrationNumber.trim().isNotEmpty)
            'registration_number': registrationNumber.trim(),
          if (billingAddress != null && billingAddress.trim().isNotEmpty)
            'billing_address': billingAddress.trim(),
        },
      );
      return _dataMap(response.data)['id']?.toString() ?? '';
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> accept(String organisationId) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/fleet/$organisationId/accept',
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetOrgDetail> show(String organisationId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/fleet/$organisationId',
        queryParameters: {'include_vehicles': false},
      );
      final detail = FleetOrgDetail.fromJson(_dataMap(response.data));
      if (detail.id != organisationId) {
        throw const ApiFailure(
          'Travla returned the wrong fleet workspace. Please try again.',
        );
      }
      return detail;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetKpis> dashboard(String organisationId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/fleet/$organisationId/dashboard',
      );
      final dashboard = FleetKpis.fromJson(_dataMap(response.data));
      if (dashboard.organisationId != organisationId) {
        throw const ApiFailure(
          'Travla returned the wrong fleet workspace. Please try again.',
        );
      }
      return dashboard;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetVehiclesPage> vehicles(
    String organisationId, {
    int page = 1,
    String? query,
    String? regionId,
    String? driverStatus,
    String? tracking,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/fleet/$organisationId/vehicles',
        queryParameters: {
          'page': page,
          'per_page': 20,
          if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
          if (regionId?.isNotEmpty == true) 'region_id': regionId,
          if (driverStatus?.isNotEmpty == true) 'driver_status': driverStatus,
          if (tracking?.isNotEmpty == true) 'tracking': tracking,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final data = body['data'];
      final meta = body['meta'];
      final items = data is List
          ? data
                .whereType<Map>()
                .map(
                  (item) => OrgVehicle.fromJson(item.cast<String, dynamic>()),
                )
                .toList(growable: false)
          : const <OrgVehicle>[];
      final metaMap = meta is Map ? meta.cast<String, dynamic>() : null;
      return FleetVehiclesPage(
        items: items,
        page: (metaMap?['current_page'] as num?)?.toInt() ?? page,
        lastPage: (metaMap?['last_page'] as num?)?.toInt() ?? page,
        total: (metaMap?['total'] as num?)?.toInt() ?? items.length,
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<OrgVehicle> vehicle(String organisationId, String orgVehicleId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/fleet/$organisationId/vehicles/$orgVehicleId',
      );
      final vehicle = OrgVehicle.fromJson(_dataMap(response.data));
      if (vehicle.id != orgVehicleId) {
        throw const ApiFailure(
          'Travla returned the wrong fleet vehicle. Please try again.',
        );
      }
      return vehicle;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetTrackingSnapshot> tracking(String organisationId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/fleet/$organisationId/tracking',
      );
      final snapshot = FleetTrackingSnapshot.fromJson(_dataMap(response.data));
      if (snapshot.organisationId != organisationId) {
        throw const ApiFailure(
          'Travla returned tracking for the wrong fleet workspace. Please try again.',
        );
      }
      return snapshot;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<FleetRegionRef>> regions(String organisationId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/fleet/$organisationId/regions',
      );
      final data = _dataMap(response.data);
      final organisation = data['organisation'];
      if (organisation is! Map ||
          organisation['id']?.toString() != organisationId) {
        throw const ApiFailure(
          'Travla returned regions for the wrong fleet workspace. Please try again.',
        );
      }
      final rawRegions = data['regions'];
      return (rawRegions is List ? rawRegions : const [])
          .whereType<Map>()
          .map(
            (region) => FleetRegionRef.fromJson(region.cast<String, dynamic>()),
          )
          .where((region) => region.id.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetDriversPage> drivers(
    String organisationId, {
    String? query,
    String? regionId,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/fleet/$organisationId/drivers',
        queryParameters: {
          'per_page': 100,
          if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
          if (regionId?.isNotEmpty == true) 'region_id': regionId,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final organisation = body['organisation'];
      if (organisation is! Map ||
          organisation['id']?.toString() != organisationId) {
        throw const ApiFailure(
          'Travla returned drivers for the wrong fleet workspace. Please try again.',
        );
      }
      final data = body['data'];
      final meta = body['meta'];
      final items = data is List
          ? data
                .whereType<Map>()
                .map(
                  (driver) =>
                      FleetDriver.fromJson(driver.cast<String, dynamic>()),
                )
                .where((driver) => driver.id.isNotEmpty)
                .toList(growable: false)
          : const <FleetDriver>[];
      final metaMap = meta is Map ? meta.cast<String, dynamic>() : null;
      return FleetDriversPage(
        items: items,
        page: (metaMap?['current_page'] as num?)?.toInt() ?? 1,
        lastPage: (metaMap?['last_page'] as num?)?.toInt() ?? 1,
        total: (metaMap?['total'] as num?)?.toInt() ?? items.length,
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> assignDriver(
    String organisationId,
    String orgVehicleId,
    String? driverId,
  ) async {
    try {
      await _apiClient.dio.patch<Map<String, dynamic>>(
        '/fleet/$organisationId/vehicles/$orgVehicleId/driver',
        data: {'driver_id': driverId},
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> updateVehiclePlacement(
    String organisationId,
    String orgVehicleId, {
    required String? regionId,
    required String? department,
  }) async {
    try {
      await _apiClient.dio.patch<Map<String, dynamic>>(
        '/fleet/$organisationId/vehicles/$orgVehicleId/placement',
        data: {
          'org_region_id': regionId,
          'department': department?.trim().isNotEmpty == true
              ? department!.trim()
              : null,
        },
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetFuelCardReceipt> issueFuelCard(
    String organisationId,
    String orgVehicleId,
  ) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/fleet/$organisationId/vehicles/$orgVehicleId/card',
      );
      final data = _dataMap(response.data);
      final rawReceipt = data['fuel_card_receipt'];
      if (rawReceipt is! Map) {
        throw const ApiFailure(
          'The card was issued but Travla did not return its receipt. Refresh this vehicle before trying again.',
        );
      }
      final receipt = FleetFuelCardReceipt.fromJson(
        rawReceipt.cast<String, dynamic>(),
      );
      if (receipt.orgVehicleId != orgVehicleId ||
          receipt.cardLastFour.length != 4 ||
          receipt.status != 'ACTIVE') {
        throw const ApiFailure(
          'Travla returned an unexpected fuel-card receipt.',
        );
      }
      return receipt;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetAllocationReceipt> topUpVehicleAllocation(
    String organisationId,
    String orgVehicleId, {
    required int amountNaira,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/fleet/$organisationId/vehicles/$orgVehicleId/allocation',
        data: {'amount_naira': amountNaira},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      final data = _dataMap(response.data);
      final rawReceipt = data['allocation_receipt'];
      if (rawReceipt is! Map) {
        throw const ApiFailure(
          'The allocation changed but Travla did not return its receipt. Refresh this vehicle before trying again.',
        );
      }
      final receipt = FleetAllocationReceipt.fromJson(
        rawReceipt.cast<String, dynamic>(),
      );
      if (receipt.orgVehicleId != orgVehicleId ||
          receipt.requestId.isEmpty ||
          receipt.grantedKobo != amountNaira * 100) {
        throw const ApiFailure(
          'Travla returned an unexpected allocation receipt.',
        );
      }
      return receipt;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetFuelSummary> fuelSummary(String organisationId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/fleet/$organisationId/fuel/summary',
      );
      final summary = FleetFuelSummary.fromJson(_dataMap(response.data));
      if (summary.organisationId != organisationId) {
        throw const ApiFailure(
          'Travla returned fuel information for the wrong fleet workspace. Please try again.',
        );
      }
      return summary;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetFundingStepUp> createFundingStepUp(
    String organisationId, {
    required int amountNaira,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/fleet/$organisationId/fuel/fund/step-up',
        data: {'amount_naira': amountNaira, 'password': password},
      );
      final challenge = FleetFundingStepUp.fromJson(_dataMap(response.data));
      if (challenge.token.isEmpty) {
        throw const ApiFailure(
          'Travla could not verify this transfer. Please try again.',
        );
      }
      return challenge;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetFundingReceipt> fundFuel(
    String organisationId, {
    required int amountNaira,
    required String stepUpToken,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/fleet/$organisationId/fuel/fund',
        data: {'amount_naira': amountNaira},
        options: Options(
          headers: {
            'Idempotency-Key': idempotencyKey,
            'X-Fleet-Step-Up': stepUpToken,
          },
        ),
      );
      final data = _dataMap(response.data);
      final rawReceipt = data['funding_receipt'];
      if (rawReceipt is! Map) {
        throw const ApiFailure(
          'The transfer completed but Travla did not return its receipt. Refresh your Fleet balance before trying again.',
        );
      }
      final receipt = FleetFundingReceipt.fromJson(
        rawReceipt.cast<String, dynamic>(),
      );
      if (receipt.requestId.isEmpty || receipt.status != 'COMPLETED') {
        throw const ApiFailure(
          'Travla returned an unexpected Fleet funding receipt.',
        );
      }
      return receipt;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetFuelTransactionsPage> fuelTransactions(
    String organisationId, {
    int page = 1,
    String? query,
    String? status,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/fleet/$organisationId/fuel/transactions',
        queryParameters: {
          'page': page,
          'per_page': 20,
          if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
          if (status?.isNotEmpty == true) 'status': status,
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final organisation = body['organisation'];
      if (organisation is! Map ||
          organisation['id']?.toString() != organisationId) {
        throw const ApiFailure(
          'Travla returned fuel activity for the wrong fleet workspace. Please try again.',
        );
      }
      final data = body['data'];
      final meta = body['meta'];
      final items = data is List
          ? data
                .whereType<Map>()
                .map(
                  (item) => FleetFuelTransaction.fromJson(
                    item.cast<String, dynamic>(),
                  ),
                )
                .where((item) => item.id.isNotEmpty)
                .toList(growable: false)
          : const <FleetFuelTransaction>[];
      final metaMap = meta is Map ? meta.cast<String, dynamic>() : null;
      return FleetFuelTransactionsPage(
        items: items,
        page: (metaMap?['current_page'] as num?)?.toInt() ?? page,
        lastPage: (metaMap?['last_page'] as num?)?.toInt() ?? page,
        total: (metaMap?['total'] as num?)?.toInt() ?? items.length,
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<FleetFuelTransaction> fuelTransaction(
    String organisationId,
    String transactionId,
  ) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/fleet/$organisationId/fuel/transactions/$transactionId',
      );
      final data = _dataMap(response.data);
      final organisation = data['organisation'];
      if (organisation is! Map ||
          organisation['id']?.toString() != organisationId) {
        throw const ApiFailure(
          'Travla returned a fuel transaction for the wrong fleet workspace. Please try again.',
        );
      }
      final raw = data['transaction'];
      if (raw is! Map) {
        throw const ApiFailure(
          'Travla returned an unexpected fuel transaction.',
        );
      }
      final transaction = FleetFuelTransaction.fromJson(
        raw.cast<String, dynamic>(),
      );
      if (transaction.id != transactionId) {
        throw const ApiFailure(
          'Travla returned the wrong fuel transaction. Please try again.',
        );
      }
      return transaction;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> addRegion(
    String organisationId, {
    required String name,
    String? state,
  }) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/fleet/$organisationId/regions',
        data: {
          'name': name.trim(),
          if (state?.trim().isNotEmpty == true) 'state': state!.trim(),
        },
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry('$k', v));
    throw const ApiFailure('Travla returned an unexpected fleet response.');
  }
}

final fleetRepositoryProvider = Provider<FleetRepository>((ref) {
  return FleetRepository(ref.watch(apiClientProvider));
});

final fleetHomeProvider = FutureProvider.autoDispose<FleetHome>((ref) {
  return ref.watch(fleetRepositoryProvider).home();
});

final fleetOrgProvider = FutureProvider.autoDispose
    .family<FleetOrgDetail, String>((ref, id) {
      return ref.watch(fleetRepositoryProvider).show(id);
    });

final fleetDashboardProvider = FutureProvider.autoDispose
    .family<FleetKpis, String>((ref, id) {
      return ref.watch(fleetRepositoryProvider).dashboard(id);
    });

final fleetVehicleProvider = FutureProvider.autoDispose
    .family<OrgVehicle, ({String organisationId, String orgVehicleId})>((
      ref,
      key,
    ) {
      return ref
          .watch(fleetRepositoryProvider)
          .vehicle(key.organisationId, key.orgVehicleId);
    });

final fleetTrackingProvider = FutureProvider.autoDispose
    .family<FleetTrackingSnapshot, String>((ref, organisationId) {
      return ref.watch(fleetRepositoryProvider).tracking(organisationId);
    });

final fleetRegionsProvider = FutureProvider.autoDispose
    .family<List<FleetRegionRef>, String>((ref, organisationId) {
      return ref.watch(fleetRepositoryProvider).regions(organisationId);
    });

final fleetFuelSummaryProvider = FutureProvider.autoDispose
    .family<FleetFuelSummary, String>((ref, organisationId) {
      return ref.watch(fleetRepositoryProvider).fuelSummary(organisationId);
    });

final fleetFuelTransactionProvider = FutureProvider.autoDispose
    .family<
      FleetFuelTransaction,
      ({String organisationId, String transactionId})
    >((ref, key) {
      return ref
          .watch(fleetRepositoryProvider)
          .fuelTransaction(key.organisationId, key.transactionId);
    });
