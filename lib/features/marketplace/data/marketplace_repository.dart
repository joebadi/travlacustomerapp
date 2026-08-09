import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/marketplace/domain/marketplace_models.dart';

class MarketplaceRepository {
  const MarketplaceRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<MarketplaceMeta> meta() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/marketplace/meta',
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('Marketplace settings could not be loaded.');
      }
      return MarketplaceMeta.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> activateSelling() =>
      _mutate(() => _apiClient.dio.post<void>('/marketplace/apply-to-sell'));

  Future<MarketplaceEligibility> eligibility(
    String vehicleId,
    String condition,
  ) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/marketplace/vehicles/$vehicleId/eligibility',
        queryParameters: {'condition': condition},
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure('Vehicle eligibility could not be confirmed.');
      }
      return MarketplaceEligibility.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<MarketplaceListingSummary>> myListings() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/marketplace/my-listings',
      );
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(MarketplaceListingSummary.fromJson)
          .where((listing) => listing.id.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<String> createListing({
    required String vehicleId,
    required String priceNaira,
    required String description,
    required String condition,
    required String transmission,
    required String fuelType,
    required String mileageKm,
    required String location,
    required List<String> features,
    required List<String> visibleExistingImages,
    required List<MarketplaceImageUpload> images,
  }) async {
    final form = FormData();
    form.fields.addAll([
      MapEntry('vehicle_id', vehicleId),
      MapEntry('price_naira', priceNaira),
      MapEntry('condition', condition),
      MapEntry('location', location.trim()),
      MapEntry('existing_images_selection_provided', '1'),
      if (description.trim().isNotEmpty)
        MapEntry('description', description.trim()),
      if (transmission.isNotEmpty) MapEntry('transmission', transmission),
      if (fuelType.isNotEmpty) MapEntry('fuel_type', fuelType),
      if (mileageKm.isNotEmpty) MapEntry('mileage_km', mileageKm),
      ...features.map((feature) => MapEntry('features[]', feature)),
      ...visibleExistingImages.map(
        (image) => MapEntry('visible_existing_images[]', image),
      ),
    ]);
    for (final image in images) {
      form.files.add(
        MapEntry(
          'images[]',
          await MultipartFile.fromFile(image.path, filename: image.name),
        ),
      );
    }
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/marketplace/listings',
        data: form,
      );
      final id = response.data?['data']?['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const ApiFailure(
          'The listing was created but could not be opened.',
        );
      }
      return id;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(ref.watch(apiClientProvider));
});

final marketplaceMetaProvider = FutureProvider.autoDispose<MarketplaceMeta>((
  ref,
) {
  return ref.watch(marketplaceRepositoryProvider).meta();
});

final myMarketplaceListingsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(marketplaceRepositoryProvider).myListings(),
);
