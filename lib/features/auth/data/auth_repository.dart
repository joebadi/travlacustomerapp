import 'package:dio/dio.dart';
import 'package:travla_customer_app/core/auth/secure_token_store.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/auth/domain/app_user.dart';

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStore);

  final ApiClient _apiClient;
  final SecureTokenStore _tokenStore;

  Future<bool> hasSession() async {
    final token = await _tokenStore.read();
    return token != null && token.isNotEmpty;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password, 'portal': 'user'},
      );
      final data = _dataFrom(response.data);
      final token = data['token']?.toString();
      final userJson = data['user'];

      if (token == null || token.isEmpty || userJson is! Map<String, dynamic>) {
        throw const ApiFailure('Travla returned an incomplete login response.');
      }

      final user = AppUser.fromJson(userJson);
      _assertCustomer(user);
      await _tokenStore.write(token);
      return user;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<AppUser> currentUser() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/auth/me',
      );
      final user = AppUser.fromJson(_dataFrom(response.data));
      _assertCustomer(user);
      return user;
    } on DioException catch (exception) {
      if (exception.response?.statusCode == 401) {
        await _tokenStore.clear();
      }
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post<void>('/auth/logout');
    } on DioException {
      // A local logout must still succeed if the token expired or the device
      // is temporarily offline.
    } finally {
      await _tokenStore.clear();
    }
  }

  Map<String, dynamic> _dataFrom(Map<String, dynamic>? envelope) {
    final data = envelope?['data'];
    if (data is Map<String, dynamic>) return data;
    throw const ApiFailure('Travla returned an unexpected response.');
  }

  void _assertCustomer(AppUser user) {
    if (user.systemRole != 'USER') {
      throw const ApiFailure(
        'This app is for Travla vehicle owners. Please use the portal for your account role.',
        statusCode: 403,
      );
    }
  }
}
