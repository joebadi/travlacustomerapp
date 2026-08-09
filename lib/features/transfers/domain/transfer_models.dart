class TransferDocumentStatus {
  const TransferDocumentStatus({required this.name, required this.expiryDate});
  final String name;
  final String? expiryDate;
  factory TransferDocumentStatus.fromJson(Map<String, dynamic> json) =>
      TransferDocumentStatus(
        name: json['name']?.toString() ?? 'Vehicle document',
        expiryDate: json['expiry_date']?.toString(),
      );
}

class TransferReadiness {
  const TransferReadiness({
    required this.isReady,
    required this.missingDocuments,
    required this.expiredDocuments,
    required this.blockers,
    required this.processingFeeNaira,
    required this.deliveryFeeNaira,
    required this.totalFeeNaira,
    required this.totalFeeKobo,
    required this.categoryLabel,
  });
  final bool isReady;
  final List<String> missingDocuments;
  final List<TransferDocumentStatus> expiredDocuments;
  final List<String> blockers;
  final String processingFeeNaira;
  final String deliveryFeeNaira;
  final String totalFeeNaira;
  final int totalFeeKobo;
  final String categoryLabel;
  List<String> get problems => [...blockers, ...missingDocuments];
  factory TransferReadiness.fromJson(Map<String, dynamic> json) {
    final missing = json['missing_documents'];
    final expired = json['expired_documents'];
    return TransferReadiness(
      isReady: json['is_ready'] == true,
      missingDocuments: missing is List
          ? missing
                .whereType<Map<String, dynamic>>()
                .map((item) => '${item['name'] ?? 'Document'} is missing')
                .toList(growable: false)
          : const [],
      expiredDocuments: expired is List
          ? expired
                .whereType<Map<String, dynamic>>()
                .map(TransferDocumentStatus.fromJson)
                .toList(growable: false)
          : const [],
      blockers: json['blockers'] is List
          ? (json['blockers'] as List)
                .map((item) => item.toString())
                .toList(growable: false)
          : const [],
      processingFeeNaira: json['fee_naira']?.toString() ?? '0.00',
      deliveryFeeNaira: json['delivery_fee_naira']?.toString() ?? '0.00',
      totalFeeNaira: json['total_fee_naira']?.toString() ?? '0.00',
      totalFeeKobo: (json['total_fee_kobo'] as num?)?.toInt() ?? 0,
      categoryLabel: json['vehicle_category_label']?.toString() ?? 'Vehicle',
    );
  }
}

class TransferRecipientMatch {
  const TransferRecipientMatch({
    required this.matched,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.ninOnFile,
    required this.message,
  });
  final bool matched;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final bool ninOnFile;
  final String message;
  factory TransferRecipientMatch.fromJson(Map<String, dynamic> json) =>
      TransferRecipientMatch(
        matched: json['matched'] == true,
        firstName: json['first_name']?.toString() ?? '',
        lastName: json['last_name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        ninOnFile: json['nin_on_file'] == true,
        message: json['message']?.toString() ?? '',
      );
}

class TransferCity {
  const TransferCity({required this.city, required this.state});
  final String city;
  final String state;
  factory TransferCity.fromJson(Map<String, dynamic> json) => TransferCity(
    city: json['city']?.toString() ?? '',
    state: json['state']?.toString() ?? '',
  );
}

class TransferSetup {
  const TransferSetup({required this.cities});
  final List<TransferCity> cities;
}
