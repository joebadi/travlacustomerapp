import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/auth/domain/app_user.dart';
import 'package:travla_customer_app/features/profile/domain/profile_models.dart';

class ProfileRepository {
  const ProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AppUser> update(ProfileUpdate input) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/profile',
        data: input.toJson(),
      );
      return AppUser.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<AppUser> uploadAvatar({
    required String path,
    required String name,
  }) async {
    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(path, filename: name),
    });
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/profile/avatar',
        data: form,
      );
      return AppUser.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<List<NigerianBank>> banks() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/profile/banks',
      );
      final data = response.data?['data'];
      if (data is! List) {
        throw const ApiFailure('The Nigerian bank directory is unavailable.');
      }
      return data
          .map(_map)
          .whereType<Map<String, dynamic>>()
          .map(NigerianBank.fromJson)
          .where((bank) => bank.code.isNotEmpty && bank.name.isNotEmpty)
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
      if (data is! List) return const [];
      return data
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<AppUser> verifyBank({
    required String bankCode,
    required String accountNumber,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/profile/verify-bank',
        data: {'bank_code': bankCode, 'account_number': accountNumber},
      );
      return AppUser.fromJson(_dataMap(response.data));
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String confirmation,
  }) async {
    try {
      await _apiClient.dio.post<void>(
        '/profile/password',
        data: {
          'current_password': currentPassword,
          'password': password,
          'password_confirmation': confirmation,
        },
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic>? envelope) {
    final data = _map(envelope?['data']);
    if (data == null) {
      throw const ApiFailure('Travla returned an unexpected profile response.');
    }
    return data;
  }
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return null;
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

final profileBanksProvider = FutureProvider.autoDispose<List<NigerianBank>>((
  ref,
) {
  return ref.watch(profileRepositoryProvider).banks();
});

final profileStatesProvider = FutureProvider.autoDispose<List<String>>((ref) {
  return ref.watch(profileRepositoryProvider).states();
});
