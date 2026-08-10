class DriversLicense {
  const DriversLicense({
    required this.id,
    required this.licenseNumber,
    required this.holderName,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.address,
    required this.city,
    required this.state,
    required this.licenseClass,
    required this.licenseClassLabel,
    required this.issueDate,
    required this.expiryDate,
    required this.issuingAuthority,
    required this.status,
    required this.statusLabel,
    required this.daysToExpiry,
    required this.renewable,
    required this.hasDocument,
    required this.documentUrl,
    required this.canManage,
  });

  final String id;
  final String licenseNumber;
  final String holderName;
  final String firstName;
  final String lastName;
  final String? dateOfBirth;
  final String address;
  final String city;
  final String state;
  final String? licenseClass;
  final String? licenseClassLabel;
  final String? issueDate;
  final String? expiryDate;
  final String? issuingAuthority;
  final String status;
  final String statusLabel;
  final int? daysToExpiry;
  final bool renewable;
  final bool hasDocument;
  final String? documentUrl;
  final bool canManage;

  factory DriversLicense.fromJson(Map<String, dynamic> json) {
    return DriversLicense(
      id: json['id']?.toString() ?? '',
      licenseNumber: json['license_number']?.toString() ?? '',
      holderName: json['holder_name']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      dateOfBirth: json['date_of_birth']?.toString(),
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      licenseClass: json['license_class']?.toString(),
      licenseClassLabel: json['license_class_label']?.toString(),
      issueDate: json['issue_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      issuingAuthority: json['issuing_authority']?.toString(),
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString() ?? '',
      daysToExpiry: (json['days_to_expiry'] as num?)?.toInt(),
      renewable: json['renewable'] == true,
      hasDocument: json['has_document'] == true,
      documentUrl: json['document_url']?.toString(),
      canManage: json['can_manage'] == true,
    );
  }
}

/// The seven Nigerian FRSC licence classes, matching the backend `LicenseClass`.
const licenseClassOptions = <({String value, String label})>[
  (value: 'A', label: 'Class A — Motorcycles & tricycles'),
  (value: 'B', label: 'Class B — Cars & light vehicles'),
  (value: 'C', label: 'Class C — Commercial vehicles'),
  (value: 'D', label: 'Class D — Articulated vehicles'),
  (value: 'E', label: 'Class E — Buses (PSV)'),
  (value: 'F', label: 'Class F — Agricultural machinery'),
  (value: 'G', label: 'Class G — Special/earth-moving equipment'),
];

/// Price + eligibility preview for a licence renewal (server is the source of truth).
class LicenseRenewalQuote {
  const LicenseRenewalQuote({
    required this.eligible,
    required this.reason,
    required this.priceNaira,
    required this.deliveryFeeNaira,
    required this.totalNaira,
    required this.totalKobo,
    required this.walletBalanceNaira,
    required this.sufficientBalance,
    required this.shortfallNaira,
  });

  final bool eligible;
  final String? reason;
  final String priceNaira;
  final String deliveryFeeNaira;
  final String totalNaira;
  final int totalKobo;
  final String walletBalanceNaira;
  final bool sufficientBalance;
  final String shortfallNaira;

  factory LicenseRenewalQuote.fromJson(Map<String, dynamic> json) {
    return LicenseRenewalQuote(
      eligible: json['eligible'] == true,
      reason: json['reason']?.toString(),
      priceNaira: json['price_naira']?.toString() ?? '0.00',
      deliveryFeeNaira: json['delivery_fee_naira']?.toString() ?? '0.00',
      totalNaira: json['total_naira']?.toString() ?? '0.00',
      totalKobo: (json['total_kobo'] as num?)?.toInt() ?? 0,
      walletBalanceNaira: json['wallet_balance_naira']?.toString() ?? '0.00',
      sufficientBalance: json['sufficient_balance'] == true,
      shortfallNaira: json['shortfall_naira']?.toString() ?? '0.00',
    );
  }
}
