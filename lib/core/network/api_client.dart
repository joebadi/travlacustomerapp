import 'package:dio/dio.dart';
import 'package:travla_customer_app/core/auth/secure_token_store.dart';
import 'package:travla_customer_app/core/config/app_config.dart';

class ApiClient {
  ApiClient(this._tokenStore)
    : dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-App-Type': AppConfig.appType,
          },
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // The token read happens before the request is dispatched, so it sits
          // outside Dio's own timeouts — a stuck secure-storage/keystore read
          // (a known Android issue) would otherwise hang the request forever and
          // spin any screen that makes it. Cap it: on timeout we send the request
          // unauthenticated, which fails fast with a 401 the UI can surface,
          // instead of loading indefinitely.
          String? token;
          try {
            token = await _tokenStore
                .read()
                .timeout(const Duration(seconds: 8));
          } catch (_) {
            token = null;
          }
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final SecureTokenStore _tokenStore;
  final Dio dio;
}
