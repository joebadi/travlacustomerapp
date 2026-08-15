class CheckpointState {
  const CheckpointState({
    required this.eligible,
    required this.active,
    required this.disclaimer,
    this.eligibilityMessage,
    this.credential,
    this.snapshot,
  });

  factory CheckpointState.fromJson(Map<String, dynamic> json) {
    return CheckpointState(
      eligible: json['eligible'] == true,
      active: json['active'] == true,
      disclaimer: json['disclaimer']?.toString() ?? '',
      eligibilityMessage: json['eligibility_message']?.toString(),
      credential: json['credential'] is Map
          ? CheckpointCredential.fromJson(
              Map<String, dynamic>.from(json['credential'] as Map),
            )
          : null,
      snapshot: json['snapshot'] is Map
          ? CheckpointSnapshot.fromJson(
              Map<String, dynamic>.from(json['snapshot'] as Map),
            )
          : null,
    );
  }

  final bool eligible;
  final bool active;
  final String disclaimer;
  final String? eligibilityMessage;
  final CheckpointCredential? credential;
  final CheckpointSnapshot? snapshot;
}

class CheckpointCredential {
  const CheckpointCredential({
    required this.id,
    required this.version,
    required this.displayCode,
    required this.publicUrl,
    required this.printUrls,
    this.enabledAt,
    this.snapshotUpdatedAt,
  });

  factory CheckpointCredential.fromJson(Map<String, dynamic> json) {
    final printUrls = json['print_urls'] is Map
        ? Map<String, dynamic>.from(json['print_urls'] as Map)
        : const <String, dynamic>{};
    return CheckpointCredential(
      id: json['id']?.toString() ?? '',
      version: int.tryParse(json['version']?.toString() ?? '') ?? 1,
      displayCode: json['display_code']?.toString() ?? '',
      publicUrl: json['public_url']?.toString() ?? '',
      enabledAt: DateTime.tryParse(json['enabled_at']?.toString() ?? ''),
      snapshotUpdatedAt: DateTime.tryParse(
        json['snapshot_updated_at']?.toString() ?? '',
      ),
      printUrls: CheckpointPrintUrls(
        a4: printUrls['a4']?.toString() ?? '',
        compact: printUrls['compact']?.toString() ?? '',
      ),
    );
  }

  final String id;
  final int version;
  final String displayCode;
  final String publicUrl;
  final DateTime? enabledAt;
  final DateTime? snapshotUpdatedAt;
  final CheckpointPrintUrls printUrls;
}

class CheckpointPrintUrls {
  const CheckpointPrintUrls({required this.a4, required this.compact});
  final String a4;
  final String compact;
}

class CheckpointSnapshot {
  const CheckpointSnapshot({
    required this.vehicle,
    required this.documents,
    required this.security,
    this.insurance,
    this.generatedAt,
  });

  factory CheckpointSnapshot.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'] ?? json['vehicle_summary'];
    final documents = json['documents'] ?? json['document_summary'];
    final insurance = json['insurance'] ?? json['insurance_summary'];
    final security = json['security'] ?? json['security_summary'];
    return CheckpointSnapshot(
      vehicle: CheckpointVehicle.fromJson(
        vehicle is Map ? Map<String, dynamic>.from(vehicle) : const {},
      ),
      documents: documents is List
          ? documents
                .whereType<Map>()
                .map(
                  (item) => CheckpointDocument.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      insurance: insurance is Map ? Map<String, dynamic>.from(insurance) : null,
      security: CheckpointSecurity.fromJson(
        security is Map ? Map<String, dynamic>.from(security) : const {},
      ),
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? ''),
    );
  }

  final CheckpointVehicle vehicle;
  final List<CheckpointDocument> documents;
  final Map<String, dynamic>? insurance;
  final CheckpointSecurity security;
  final DateTime? generatedAt;
}

class CheckpointVehicle {
  const CheckpointVehicle({
    required this.plateNumber,
    required this.make,
    required this.model,
    required this.colour,
    this.year,
    this.category,
  });

  factory CheckpointVehicle.fromJson(Map<String, dynamic> json) {
    return CheckpointVehicle(
      plateNumber: json['plate_number']?.toString() ?? '',
      make: json['make']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      year: int.tryParse(json['year']?.toString() ?? ''),
      colour: json['colour']?.toString() ?? '',
      category: json['category']?.toString(),
    );
  }

  final String plateNumber;
  final String make;
  final String model;
  final int? year;
  final String colour;
  final String? category;
}

class CheckpointDocument {
  const CheckpointDocument({
    required this.name,
    required this.validity,
    required this.authenticity,
  });

  factory CheckpointDocument.fromJson(Map<String, dynamic> json) {
    return CheckpointDocument(
      name: json['document_type']?.toString() ?? 'Vehicle document',
      validity: CheckpointStatus.fromJson(
        json['validity'] is Map
            ? Map<String, dynamic>.from(json['validity'] as Map)
            : const {},
      ),
      authenticity: CheckpointStatus.fromJson(
        json['authenticity'] is Map
            ? Map<String, dynamic>.from(json['authenticity'] as Map)
            : const {},
      ),
    );
  }

  final String name;
  final CheckpointStatus validity;
  final CheckpointStatus authenticity;
}

class CheckpointStatus {
  const CheckpointStatus({
    required this.status,
    required this.label,
    this.expiryDate,
    this.evidenceLabel,
  });

  factory CheckpointStatus.fromJson(Map<String, dynamic> json) {
    return CheckpointStatus(
      status: json['status']?.toString() ?? 'NOT_REQUESTED',
      label: json['status_label']?.toString() ?? 'Not checked',
      expiryDate: json['expiry_date']?.toString(),
      evidenceLabel: json['evidence_level_label']?.toString(),
    );
  }

  final String status;
  final String label;
  final String? expiryDate;
  final String? evidenceLabel;
}

class CheckpointSecurity {
  const CheckpointSecurity({
    required this.status,
    required this.label,
    required this.source,
  });

  factory CheckpointSecurity.fromJson(Map<String, dynamic> json) {
    return CheckpointSecurity(
      status: json['travla_stolen_status']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
    );
  }

  final String status;
  final String label;
  final String source;
}

class CheckpointPreview {
  const CheckpointPreview({required this.snapshot, required this.disclaimer});

  factory CheckpointPreview.fromJson(Map<String, dynamic> json) {
    return CheckpointPreview(
      snapshot: CheckpointSnapshot.fromJson(
        json['snapshot'] is Map
            ? Map<String, dynamic>.from(json['snapshot'] as Map)
            : const {},
      ),
      disclaimer: json['disclaimer']?.toString() ?? '',
    );
  }

  final CheckpointSnapshot snapshot;
  final String disclaimer;
}
