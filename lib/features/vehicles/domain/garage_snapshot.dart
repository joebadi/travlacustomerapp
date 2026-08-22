class VehicleSummary {
  const VehicleSummary({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plateNumber,
    required this.status,
    required this.statusLabel,
    this.documentsComplete = false,
    this.requiredDocumentsCount = 3,
    this.missingRequiredDocumentsCount = 0,
    this.missingRequiredDocumentNames = const [],
    required this.expiredDocumentsCount,
    required this.expiringSoonCount,
    required this.documentsCount,
    required this.images,
  });

  final String id;
  final String make;
  final String model;
  final int? year;
  final String color;
  final String? plateNumber;
  final String? status;
  final String? statusLabel;
  final bool documentsComplete;
  final int requiredDocumentsCount;
  final int missingRequiredDocumentsCount;
  final List<String> missingRequiredDocumentNames;
  final int expiredDocumentsCount;
  final int expiringSoonCount;
  final int documentsCount;
  final List<String> images;

  String get displayName => '$make $model'.trim();

  /// Paper-level readiness for the vehicle's required particulars. Missing
  /// papers consume their own slots; the remaining uploaded required papers
  /// are then divided into expired, expiring and up-to-date. This deliberately
  /// uses [requiredDocumentsCount] rather than every file in the vault, so an
  /// optional receipt or other document cannot inflate readiness.
  VehiclePaperReadiness get paperReadiness {
    final total = requiredDocumentsCount < 0 ? 0 : requiredDocumentsCount;
    final missing = missingRequiredDocumentsCount.clamp(0, total).toInt();
    final uploaded = total - missing;
    final expired = expiredDocumentsCount.clamp(0, uploaded).toInt();
    final afterExpired = uploaded - expired;
    final expiring = expiringSoonCount.clamp(0, afterExpired).toInt();

    return VehiclePaperReadiness(
      upToDate: afterExpired - expiring,
      expiring: expiring,
      expired: expired,
      missing: missing,
    );
  }

  factory VehicleSummary.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    return VehicleSummary(
      id: json['id']?.toString() ?? '',
      make: json['make']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      year: (json['year'] as num?)?.toInt(),
      color: json['color']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString(),
      status: json['status']?.toString(),
      statusLabel: json['status_label']?.toString(),
      documentsComplete: json['documents_complete'] == true,
      requiredDocumentsCount:
          (json['required_documents_count'] as num?)?.toInt() ?? 3,
      missingRequiredDocumentsCount:
          (json['missing_required_documents_count'] as num?)?.toInt() ?? 0,
      missingRequiredDocumentNames: _missingDocumentNames(json),
      expiredDocumentsCount:
          (json['expired_documents_count'] as num?)?.toInt() ?? 0,
      expiringSoonCount: (json['expiring_soon_count'] as num?)?.toInt() ?? 0,
      documentsCount: (json['documents_count'] as num?)?.toInt() ?? 0,
      images: rawImages is List
          ? rawImages
                .whereType<String>()
                .where((image) => image.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class IncomingTransferSummary {
  const IncomingTransferSummary({
    required this.id,
    required this.trackingNumber,
    required this.reviewStatus,
    required this.reviewStatusLabel,
    required this.consentVerified,
    required this.vehicleId,
    required this.vehicleName,
    required this.plateNumber,
    required this.currentOwnerName,
  });

  final String id;
  final String trackingNumber;
  final String reviewStatus;
  final String reviewStatusLabel;
  final bool consentVerified;
  final String? vehicleId;
  final String vehicleName;
  final String? plateNumber;
  final String currentOwnerName;

  factory IncomingTransferSummary.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'];
    final owner = json['current_owner'];
    final vehicleJson = vehicle is Map<String, dynamic>
        ? vehicle
        : const <String, dynamic>{};
    final ownerJson = owner is Map<String, dynamic>
        ? owner
        : const <String, dynamic>{};
    final make = vehicleJson['make']?.toString() ?? '';
    final model = vehicleJson['model']?.toString() ?? '';

    return IncomingTransferSummary(
      id: json['id']?.toString() ?? '',
      trackingNumber: json['tracking_number']?.toString() ?? '',
      reviewStatus: json['review_status']?.toString() ?? '',
      reviewStatusLabel: json['review_status_label']?.toString() ?? '',
      consentVerified: json['consent_verified'] == true,
      vehicleId: vehicleJson['id']?.toString(),
      vehicleName: '$make $model'.trim(),
      plateNumber: vehicleJson['plate_number']?.toString(),
      currentOwnerName: ownerJson['name']?.toString() ?? 'Current owner',
    );
  }
}

class GarageSnapshot {
  const GarageSnapshot({
    required this.vehicles,
    required this.pendingTransfers,
    required this.incomingVehicles,
  });

  final List<VehicleSummary> vehicles;
  final List<IncomingTransferSummary> pendingTransfers;
  final List<IncomingTransferSummary> incomingVehicles;

  int get validCount =>
      vehicles.where((vehicle) => vehicle.status == 'VALID').length;
  int get expiringCount =>
      vehicles.where((vehicle) => vehicle.status == 'EXPIRING_SOON').length;
  int get expiredCount =>
      vehicles.where((vehicle) => vehicle.status == 'EXPIRED').length;
  int get missingCount =>
      vehicles.where((vehicle) => vehicle.status == 'MISSING_DOCUMENTS').length;

  /// Aggregate paper readiness across every vehicle, not vehicle-status
  /// counts. A fleet of two non-tinted vehicles therefore represents six
  /// required paper slots, while a tinted vehicle contributes four.
  VehiclePaperReadiness get paperReadiness => vehicles.fold(
    VehiclePaperReadiness.zero,
    (total, vehicle) => total + vehicle.paperReadiness,
  );
}

class VehiclePaperReadiness {
  const VehiclePaperReadiness({
    required this.upToDate,
    required this.expiring,
    required this.expired,
    required this.missing,
  });

  static const zero = VehiclePaperReadiness(
    upToDate: 0,
    expiring: 0,
    expired: 0,
    missing: 0,
  );

  final int upToDate;
  final int expiring;
  final int expired;
  final int missing;

  int get total => upToDate + expiring + expired + missing;

  VehiclePaperReadiness operator +(VehiclePaperReadiness other) {
    return VehiclePaperReadiness(
      upToDate: upToDate + other.upToDate,
      expiring: expiring + other.expiring,
      expired: expired + other.expired,
      missing: missing + other.missing,
    );
  }
}

List<String> _missingDocumentNames(Map<String, dynamic> json) {
  final documents = json['missing_required_documents'];
  if (documents is! List) return const [];
  return documents
      .whereType<Map<String, dynamic>>()
      .map((document) => document['name']?.toString() ?? '')
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
}
