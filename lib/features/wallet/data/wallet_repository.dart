import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/wallet/domain/wallet_models.dart';

class WalletRepository {
  const WalletRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<WalletWorkspace> workspace() async {
    try {
      final responses = await Future.wait([
        _apiClient.dio.get<Map<String, dynamic>>('/wallet'),
        _apiClient.dio.get<Map<String, dynamic>>('/wallet/methods'),
        _apiClient.dio.get<Map<String, dynamic>>(
          '/wallet/transactions',
          queryParameters: const {'per_page': 50},
        ),
      ]);

      final walletData = _map(responses[0].data?['data']);
      final methodsData = _map(responses[1].data?['data']);
      final transactionEnvelope = responses[2].data;
      final rawTransactions = transactionEnvelope?['data'];
      if (walletData == null ||
          methodsData == null ||
          rawTransactions is! List) {
        throw const ApiFailure(
          'Travla returned an unexpected wallet response.',
        );
      }

      final meta = _map(transactionEnvelope?['meta']);
      final summary = _map(meta?['summary']);
      return WalletWorkspace(
        wallet: WalletBalance.fromJson(walletData),
        methods: WalletMethods.fromJson(methodsData),
        transactions: rawTransactions
            .map(_map)
            .whereType<Map<String, dynamic>>()
            .map(WalletTransaction.fromJson)
            .where((transaction) => transaction.id.isNotEmpty)
            .toList(growable: false),
        summary: summary == null
            ? const WalletTransactionSummary.empty()
            : WalletTransactionSummary.fromJson(summary),
      );
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<WalletTopUpIntent> initializeTopUp({
    required int amountNaira,
    String? gateway,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/wallet/topup',
        data: {
          'amount_naira': amountNaira,
          if (gateway != null && gateway.isNotEmpty) 'gateway': gateway,
        },
      );
      final data = _map(response.data?['data']);
      if (data == null) {
        throw const ApiFailure('The payment checkout could not be prepared.');
      }
      final intent = WalletTopUpIntent.fromJson(data);
      if (intent.reference.isEmpty || intent.authorizationUrl.isEmpty) {
        throw const ApiFailure('The payment checkout could not be opened.');
      }
      return intent;
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }

  Future<WalletTopUpVerification> verifyTopUp(String reference) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/wallet/topup/verify',
        data: {'reference': reference},
      );
      final data = _map(response.data?['data']);
      if (data == null) {
        throw const ApiFailure('Payment status could not be confirmed.');
      }
      return WalletTopUpVerification.fromJson(data);
    } on DioException catch (exception) {
      throw ApiFailure.fromDio(exception);
    }
  }
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return null;
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(apiClientProvider));
});

final walletWorkspaceProvider = FutureProvider.autoDispose<WalletWorkspace>((
  ref,
) {
  return ref.watch(walletRepositoryProvider).workspace();
});
