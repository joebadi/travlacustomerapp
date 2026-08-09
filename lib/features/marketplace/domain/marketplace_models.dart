class MarketplaceOption {
  const MarketplaceOption({required this.value, required this.label});
  final String value;
  final String label;
  factory MarketplaceOption.fromJson(Map<String, dynamic> json) =>
      MarketplaceOption(
        value: json['value']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
      );
}

class MarketplaceMeta {
  const MarketplaceMeta({
    required this.canSell,
    required this.conditions,
    required this.transmissions,
    required this.fuelTypes,
  });
  final bool canSell;
  final List<MarketplaceOption> conditions;
  final List<String> transmissions;
  final List<String> fuelTypes;
  factory MarketplaceMeta.fromJson(Map<String, dynamic> json) {
    final conditions = json['conditions'];
    return MarketplaceMeta(
      canSell: json['can_sell'] == true,
      conditions: conditions is List
          ? conditions
                .whereType<Map<String, dynamic>>()
                .map(MarketplaceOption.fromJson)
                .toList(growable: false)
          : const [],
      transmissions: _strings(json['transmissions']),
      fuelTypes: _strings(json['fuel_types']),
    );
  }
}

class MarketplaceMissingDocument {
  const MarketplaceMissingDocument({required this.name, required this.reason});
  final String name;
  final String? reason;
  factory MarketplaceMissingDocument.fromJson(Map<String, dynamic> json) =>
      MarketplaceMissingDocument(
        name: json['name']?.toString() ?? 'Required document',
        reason: json['reason']?.toString(),
      );
  String get message => reason == 'file_missing'
      ? '$name needs its document file'
      : '$name is missing';
}

class MarketplaceEligibility {
  const MarketplaceEligibility({
    required this.isReady,
    required this.documentsExempt,
    required this.missingDocuments,
    required this.expiredDocuments,
    required this.blockers,
  });
  final bool isReady;
  final bool documentsExempt;
  final List<MarketplaceMissingDocument> missingDocuments;
  final List<String> expiredDocuments;
  final List<String> blockers;
  List<String> get problems => [
    ...blockers,
    ...missingDocuments.map((document) => document.message),
  ];
  factory MarketplaceEligibility.fromJson(Map<String, dynamic> json) {
    final missing = json['missing_documents'];
    final expired = json['expired_documents'];
    return MarketplaceEligibility(
      isReady: json['is_ready'] == true,
      documentsExempt: json['documents_exempt'] == true,
      missingDocuments: missing is List
          ? missing
                .whereType<Map<String, dynamic>>()
                .map(MarketplaceMissingDocument.fromJson)
                .toList(growable: false)
          : const [],
      expiredDocuments: expired is List
          ? expired
                .whereType<Map<String, dynamic>>()
                .map((item) => item['name']?.toString() ?? 'Document')
                .toList(growable: false)
          : const [],
      blockers: _strings(json['blockers']),
    );
  }
}

class MarketplaceListingSummary {
  const MarketplaceListingSummary({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.priceNaira,
    required this.status,
  });
  final String id;
  final String vehicleId;
  final String vehicleName;
  final String priceNaira;
  final String status;
  factory MarketplaceListingSummary.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'];
    return MarketplaceListingSummary(
      id: json['id']?.toString() ?? '',
      vehicleId: vehicle is Map ? vehicle['id']?.toString() ?? '' : '',
      vehicleName: vehicle is Map
          ? '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim()
          : 'Vehicle',
      priceNaira: json['price_naira']?.toString() ?? '0.00',
      status: json['status']?.toString() ?? '',
    );
  }
}

class MarketplaceImageUpload {
  const MarketplaceImageUpload({required this.path, required this.name});
  final String path;
  final String name;
}

List<String> _strings(dynamic value) => value is List
    ? value.map((item) => item.toString()).toList(growable: false)
    : const [];
