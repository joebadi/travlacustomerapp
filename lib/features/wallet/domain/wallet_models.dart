class WalletWorkspace {
  const WalletWorkspace({
    required this.wallet,
    required this.methods,
    required this.transactions,
    required this.summary,
  });

  final WalletBalance wallet;
  final WalletMethods methods;
  final List<WalletTransaction> transactions;
  final WalletTransactionSummary summary;
}

class WalletBalance {
  const WalletBalance({
    required this.balanceKobo,
    required this.balanceNaira,
    required this.currency,
  });

  final int balanceKobo;
  final String balanceNaira;
  final String currency;

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      balanceKobo: _asInt(json['balance_kobo']),
      balanceNaira: json['balance_naira']?.toString() ?? '0.00',
      currency: json['currency']?.toString() ?? 'NGN',
    );
  }
}

class WalletMethods {
  const WalletMethods({
    required this.canFund,
    required this.canWithdraw,
    required this.automatedEnabled,
    required this.gateways,
    this.defaultGateway,
    this.virtualAccount,
  });

  final bool canFund;
  final bool canWithdraw;
  final bool automatedEnabled;
  final List<WalletGateway> gateways;
  final String? defaultGateway;
  final WalletVirtualAccount? virtualAccount;

  factory WalletMethods.fromJson(Map<String, dynamic> json) {
    final rawGateways = json['gateways'];
    final account = _asMap(json['virtual_account']);
    return WalletMethods(
      canFund: json['can_fund'] == true,
      canWithdraw: json['can_withdraw'] == true,
      automatedEnabled: json['automated_enabled'] == true,
      gateways: rawGateways is List
          ? rawGateways
                .map(_asMap)
                .whereType<Map<String, dynamic>>()
                .map(WalletGateway.fromJson)
                .where((gateway) => gateway.name.isNotEmpty)
                .toList(growable: false)
          : const [],
      defaultGateway: json['default_gateway']?.toString(),
      virtualAccount: account == null
          ? null
          : WalletVirtualAccount.fromJson(account),
    );
  }
}

class WalletGateway {
  const WalletGateway({required this.name, required this.label});

  final String name;
  final String label;

  factory WalletGateway.fromJson(Map<String, dynamic> json) {
    return WalletGateway(
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? json['name']?.toString() ?? '',
    );
  }
}

class WalletVirtualAccount {
  const WalletVirtualAccount({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  final String bankName;
  final String accountNumber;
  final String accountName;

  factory WalletVirtualAccount.fromJson(Map<String, dynamic> json) {
    return WalletVirtualAccount(
      bankName: json['bank_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
    );
  }
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.direction,
    required this.type,
    required this.typeLabel,
    required this.amountKobo,
    required this.amountNaira,
    required this.balanceAfterKobo,
    required this.balanceAfterNaira,
    required this.reference,
    required this.status,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String direction;
  final String type;
  final String typeLabel;
  final int amountKobo;
  final String amountNaira;
  final int balanceAfterKobo;
  final String balanceAfterNaira;
  final String reference;
  final String status;
  final String description;
  final DateTime? createdAt;

  bool get isCredit => direction.toLowerCase() == 'credit';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      direction: json['direction']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      typeLabel: json['type_label']?.toString() ?? 'Transaction',
      amountKobo: _asInt(json['amount_kobo']),
      amountNaira: json['amount_naira']?.toString() ?? '0.00',
      balanceAfterKobo: _asInt(json['balance_after_kobo']),
      balanceAfterNaira: json['balance_after_naira']?.toString() ?? '0.00',
      reference: json['reference']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class WalletTransactionSummary {
  const WalletTransactionSummary({
    required this.totalCount,
    required this.totalCreditKobo,
    required this.totalCreditNaira,
    required this.totalDebitKobo,
    required this.totalDebitNaira,
  });

  const WalletTransactionSummary.empty()
    : totalCount = 0,
      totalCreditKobo = 0,
      totalCreditNaira = '0.00',
      totalDebitKobo = 0,
      totalDebitNaira = '0.00';

  final int totalCount;
  final int totalCreditKobo;
  final String totalCreditNaira;
  final int totalDebitKobo;
  final String totalDebitNaira;

  factory WalletTransactionSummary.fromJson(Map<String, dynamic> json) {
    return WalletTransactionSummary(
      totalCount: _asInt(json['total_count']),
      totalCreditKobo: _asInt(json['total_credit_kobo']),
      totalCreditNaira: json['total_credit_naira']?.toString() ?? '0.00',
      totalDebitKobo: _asInt(json['total_debit_kobo']),
      totalDebitNaira: json['total_debit_naira']?.toString() ?? '0.00',
    );
  }
}

class WalletTopUpIntent {
  const WalletTopUpIntent({
    required this.authorizationUrl,
    required this.reference,
    required this.amountNaira,
    required this.inline,
  });

  final String authorizationUrl;
  final String reference;
  final String amountNaira;
  final bool inline;

  factory WalletTopUpIntent.fromJson(Map<String, dynamic> json) {
    return WalletTopUpIntent(
      authorizationUrl: json['authorization_url']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      amountNaira: json['amount_naira']?.toString() ?? '0.00',
      inline: json['inline'] == true,
    );
  }
}

class WalletTopUpVerification {
  const WalletTopUpVerification({required this.status, required this.credited});

  final String status;
  final bool credited;

  bool get isComplete => credited || status.toUpperCase() == 'SUCCESS';

  factory WalletTopUpVerification.fromJson(Map<String, dynamic> json) {
    return WalletTopUpVerification(
      status: json['status']?.toString() ?? 'PENDING',
      credited: json['credited'] == true,
    );
  }
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return null;
}
