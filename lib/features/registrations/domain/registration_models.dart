class RegistrationDocumentField {
  const RegistrationDocumentField({
    required this.key,
    required this.name,
    required this.description,
    required this.required,
  });

  final String key;
  final String name;
  final String? description;
  final bool required;

  factory RegistrationDocumentField.fromJson(Map<String, dynamic> json) {
    return RegistrationDocumentField(
      key: json['field_key']?.toString() ?? '',
      name: json['field_name']?.toString() ?? '',
      description: json['description']?.toString(),
      required: json['is_required'] == true,
    );
  }
}

class RegistrationOption {
  const RegistrationOption({
    required this.key,
    required this.name,
    required this.description,
    required this.feeNaira,
  });

  final String key;
  final String name;
  final String? description;
  final String feeNaira;

  factory RegistrationOption.fromJson(Map<String, dynamic> json) {
    return RegistrationOption(
      key: json['option_key']?.toString() ?? '',
      name: json['option_name']?.toString() ?? '',
      description: json['description']?.toString(),
      feeNaira: json['fee_naira']?.toString() ?? '0.00',
    );
  }
}

class ServiceCity {
  const ServiceCity({required this.city, required this.state});

  final String city;
  final String state;

  factory ServiceCity.fromJson(Map<String, dynamic> json) {
    return ServiceCity(
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
    );
  }
}

class RegistrationSetup {
  const RegistrationSetup({
    required this.baseFeeNaira,
    required this.customPlateFeeNaira,
    required this.documentFields,
    required this.options,
    required this.serviceCities,
  });

  final String baseFeeNaira;
  final String customPlateFeeNaira;
  final List<RegistrationDocumentField> documentFields;
  final List<RegistrationOption> options;
  final List<ServiceCity> serviceCities;
}

class RegistrationLineItem {
  const RegistrationLineItem({
    required this.key,
    required this.label,
    required this.description,
    required this.kind,
    required this.amountNaira,
  });

  final String key;
  final String label;
  final String description;
  final String kind;
  final String amountNaira;

  factory RegistrationLineItem.fromJson(Map<String, dynamic> json) {
    return RegistrationLineItem(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'registration',
      amountNaira: json['amount_naira']?.toString() ?? '0.00',
    );
  }
}

class RegistrationQuote {
  const RegistrationQuote({
    required this.vehicleCategory,
    required this.vehicleCategoryLabel,
    required this.totalNaira,
    required this.walletBalanceNaira,
    required this.sufficientBalance,
    required this.shortfallNaira,
    required this.lineItems,
  });

  final String vehicleCategory;
  final String vehicleCategoryLabel;
  final String totalNaira;
  final String walletBalanceNaira;
  final bool sufficientBalance;
  final String shortfallNaira;
  final List<RegistrationLineItem> lineItems;

  factory RegistrationQuote.fromJson(Map<String, dynamic> json) {
    final rawItems = json['line_items'];
    return RegistrationQuote(
      vehicleCategory: json['vehicle_category']?.toString() ?? '',
      vehicleCategoryLabel: json['vehicle_category_label']?.toString() ?? '',
      totalNaira: json['total_naira']?.toString() ?? '0.00',
      walletBalanceNaira: json['wallet_balance_naira']?.toString() ?? '0.00',
      sufficientBalance: json['sufficient_balance'] == true,
      shortfallNaira: json['shortfall_naira']?.toString() ?? '0.00',
      lineItems: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(RegistrationLineItem.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class RegistrationCreated {
  const RegistrationCreated({
    required this.id,
    required this.trackingNumber,
    required this.statusLabel,
    required this.amountNaira,
  });

  final String id;
  final String trackingNumber;
  final String statusLabel;
  final String amountNaira;

  factory RegistrationCreated.fromJson(Map<String, dynamic> json) {
    return RegistrationCreated(
      id: json['id']?.toString() ?? '',
      trackingNumber: json['tracking_number']?.toString() ?? '',
      statusLabel: json['status_label']?.toString() ?? 'Submitted',
      amountNaira: json['amount_naira']?.toString() ?? '0.00',
    );
  }
}
