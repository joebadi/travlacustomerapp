import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/wallet/domain/wallet_models.dart';

void main() {
  test('wallet transaction keeps every ledger field and credit direction', () {
    final transaction = WalletTransaction.fromJson({
      'id': 'txn-1',
      'direction': 'credit',
      'type': 'wallet_funding',
      'type_label': 'Wallet funding',
      'amount_kobo': 500000,
      'amount_naira': '5000.00',
      'balance_after_kobo': 750000,
      'balance_after_naira': '7500.00',
      'reference': 'TRV-123',
      'status': 'success',
      'description': 'Paystack wallet funding',
      'created_at': '2026-08-09T10:15:00.000Z',
    });

    expect(transaction.isCredit, isTrue);
    expect(transaction.typeLabel, 'Wallet funding');
    expect(transaction.amountKobo, 500000);
    expect(transaction.balanceAfterNaira, '7500.00');
    expect(transaction.createdAt, isNotNull);
  });

  test('wallet methods expose gateway and virtual account', () {
    final methods = WalletMethods.fromJson({
      'can_fund': true,
      'can_withdraw': false,
      'automated_enabled': true,
      'default_gateway': 'paystack',
      'gateways': [
        {'name': 'paystack', 'label': 'Paystack'},
      ],
      'virtual_account': {
        'bank_name': 'Travla Bank',
        'account_number': '0123456789',
        'account_name': 'JOE TRAVLA',
      },
    });

    expect(methods.canFund, isTrue);
    expect(methods.gateways.single.name, 'paystack');
    expect(methods.virtualAccount?.accountNumber, '0123456789');
  });

  test('top-up verification completes when backend credits the wallet', () {
    final verification = WalletTopUpVerification.fromJson({
      'status': 'success',
      'credited': true,
    });

    expect(verification.isComplete, isTrue);
  });
}
