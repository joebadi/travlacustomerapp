/// Coverage tiers offered by Nigerian motor insurers — mirrors the backend
/// `InsuranceCoverageType` enum.
const coverageTypeOptions = <({String value, String label})>[
  (value: 'THIRD_PARTY', label: 'Third-Party'),
  (value: 'THIRD_PARTY_FIRE_THEFT', label: 'Third-Party, Fire & Theft'),
  (value: 'COMPREHENSIVE', label: 'Comprehensive'),
];

class InsuranceCompany {
  const InsuranceCompany({
    required this.id,
    required this.name,
    this.shortName,
  });

  final String id;
  final String name;
  final String? shortName;

  factory InsuranceCompany.fromJson(Map<String, dynamic> json) {
    return InsuranceCompany(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      shortName: json['short_name']?.toString(),
    );
  }
}

class InsurancePolicy {
  const InsurancePolicy({
    required this.id,
    required this.vehicleId,
    required this.provider,
    required this.policyNumber,
    required this.coverageType,
    required this.coverageLabel,
    required this.sourceLabel,
    required this.isVerified,
    required this.startDate,
    required this.endDate,
    required this.premiumNaira,
    required this.excessNaira,
    required this.status,
    required this.statusLabel,
    required this.daysToExpiry,
    required this.isExpired,
    required this.isPending,
    required this.hasDocument,
    required this.documentUrl,
    required this.vehicleName,
    required this.vehiclePlate,
  });

  final String id;
  final String vehicleId;
  final String? provider;
  final String? policyNumber;
  final String? coverageType;
  final String? coverageLabel;
  final String? sourceLabel;
  final bool isVerified;
  final String? startDate;
  final String? endDate;
  final String premiumNaira;
  final String excessNaira;
  final String status;
  final String statusLabel;
  final int? daysToExpiry;
  final bool isExpired;
  final bool isPending;
  final bool hasDocument;
  final String? documentUrl;
  final String? vehicleName;
  final String? vehiclePlate;

  bool get isActive => status == 'ACTIVE' && !isExpired;

  /// Mirrors the backend eligibility (RenewalEligibilityService::checkInsurance):
  /// renewable when not cancelled/pending and either already expired or within
  /// 30 days of expiry. Applies to NIID-found policies too.
  bool get canRenew {
    if (status == 'CANCELLED' || isPending) return false;
    if (isExpired) return true;
    return daysToExpiry != null && daysToExpiry! <= 30;
  }

  factory InsurancePolicy.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'];
    final vehicleJson = vehicle is Map ? vehicle : const {};
    final make = vehicleJson['make']?.toString() ?? '';
    final model = vehicleJson['model']?.toString() ?? '';
    final name = [make, model].where((s) => s.isNotEmpty).join(' ');

    return InsurancePolicy(
      id: json['id']?.toString() ?? '',
      vehicleId: json['vehicle_id']?.toString() ?? '',
      provider: json['provider']?.toString(),
      policyNumber: json['policy_number']?.toString(),
      coverageType: json['coverage_type']?.toString(),
      coverageLabel: json['coverage_label']?.toString(),
      sourceLabel: json['source_label']?.toString(),
      isVerified: json['is_verified'] == true,
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      premiumNaira: json['premium_naira']?.toString() ?? '0.00',
      excessNaira: json['excess_naira']?.toString() ?? '0.00',
      status: json['status']?.toString() ?? 'ACTIVE',
      statusLabel: json['status_label']?.toString() ?? 'Active',
      daysToExpiry: json['days_to_expiry'] is num
          ? (json['days_to_expiry'] as num).toInt()
          : null,
      isExpired: json['is_expired'] == true,
      isPending: json['is_pending'] == true,
      hasDocument: json['has_document'] == true,
      documentUrl: json['document_url']?.toString(),
      vehicleName: name.isEmpty ? null : name,
      vehiclePlate: vehicleJson['plate_number']?.toString(),
    );
  }
}

/// Cached third-party (NIID) verification for a vehicle. [outcome] is null when
/// the vehicle has never been checked.
class InsuranceVerification {
  const InsuranceVerification({
    required this.outcome,
    required this.outcomeLabel,
    required this.provider,
    required this.policiesFound,
    required this.checkedAt,
    required this.nextCheckAt,
    required this.isDue,
    required this.errorMessage,
    required this.hasValidPlate,
  });

  final String? outcome;
  final String? outcomeLabel;
  final String? provider;
  final int policiesFound;
  final String? checkedAt;
  final String? nextCheckAt;
  final bool isDue;
  final String? errorMessage;
  final bool hasValidPlate;

  bool get hasRun => outcome != null;

  factory InsuranceVerification.fromJson(Map<String, dynamic> json) {
    return InsuranceVerification(
      outcome: json['outcome']?.toString(),
      outcomeLabel: json['outcome_label']?.toString(),
      provider: json['provider']?.toString(),
      policiesFound: json['policies_found'] is num
          ? (json['policies_found'] as num).toInt()
          : 0,
      checkedAt: json['checked_at']?.toString(),
      nextCheckAt: json['next_check_at']?.toString(),
      isDue: json['is_due'] == true,
      errorMessage: json['error_message']?.toString(),
      hasValidPlate: json['has_valid_plate'] == true,
    );
  }
}

/// A vehicle's verification status and its saved policies, in one payload —
/// matches the `/vehicles/{id}/insurance-verification` response.
class VehicleInsurance {
  const VehicleInsurance({required this.verification, required this.policies});

  final InsuranceVerification verification;
  final List<InsurancePolicy> policies;
}

/// Quote for renewing an existing policy (`/insurance-renewals/quote`).
class InsuranceRenewalQuote {
  const InsuranceRenewalQuote({
    required this.eligible,
    required this.reason,
    required this.automated,
    required this.priceNaira,
    required this.deliveryFeeNaira,
    required this.totalNaira,
    required this.walletBalanceNaira,
    required this.sufficientBalance,
    required this.shortfallNaira,
  });

  final bool eligible;
  final String? reason;
  final bool automated;
  final String priceNaira;
  final String deliveryFeeNaira;
  final String totalNaira;
  final String walletBalanceNaira;
  final bool sufficientBalance;
  final String shortfallNaira;

  factory InsuranceRenewalQuote.fromJson(Map<String, dynamic> json) {
    return InsuranceRenewalQuote(
      eligible: json['eligible'] == true,
      reason: json['reason']?.toString(),
      automated: json['automated'] == true,
      priceNaira: json['price_naira']?.toString() ?? '0.00',
      deliveryFeeNaira: json['delivery_fee_naira']?.toString() ?? '0.00',
      totalNaira: json['total_naira']?.toString() ?? '0.00',
      walletBalanceNaira: json['wallet_balance_naira']?.toString() ?? '0.00',
      sufficientBalance: json['sufficient_balance'] == true,
      shortfallNaira: json['shortfall_naira']?.toString() ?? '0.00',
    );
  }
}

/// Quote for buying a fresh policy (`/vehicles/{id}/insurance-purchase/quote`).
class InsuranceBuyQuote {
  const InsuranceBuyQuote({
    required this.available,
    required this.reason,
    required this.automated,
    required this.providerLabel,
    required this.priceNaira,
    required this.deliveryFeeNaira,
    required this.totalNaira,
    required this.walletBalanceNaira,
    required this.sufficientBalance,
    required this.shortfallNaira,
  });

  final bool available;
  final String? reason;
  final bool automated;
  final String? providerLabel;
  final String priceNaira;
  final String deliveryFeeNaira;
  final String totalNaira;
  final String walletBalanceNaira;
  final bool sufficientBalance;
  final String shortfallNaira;

  factory InsuranceBuyQuote.fromJson(Map<String, dynamic> json) {
    return InsuranceBuyQuote(
      available: json['available'] == true,
      reason: json['reason']?.toString(),
      automated: json['automated'] == true,
      providerLabel: json['provider_label']?.toString(),
      priceNaira: json['price_naira']?.toString() ?? '0.00',
      deliveryFeeNaira: json['delivery_fee_naira']?.toString() ?? '0.00',
      totalNaira: json['total_naira']?.toString() ?? '0.00',
      walletBalanceNaira: json['wallet_balance_naira']?.toString() ?? '0.00',
      sufficientBalance: json['sufficient_balance'] == true,
      shortfallNaira: json['shortfall_naira']?.toString() ?? '0.00',
    );
  }
}
