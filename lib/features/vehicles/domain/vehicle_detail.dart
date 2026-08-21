class VehicleDetail {
  const VehicleDetail({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plateNumber,
    required this.chassisNumber,
    required this.engineNumber,
    required this.categoryValue,
    required this.categoryLabel,
    required this.description,
    required this.isTinted,
    required this.hasValidPlateNumber,
    required this.status,
    required this.statusLabel,
    this.documentsComplete = false,
    this.requiredDocumentsCount = 3,
    this.missingRequiredDocumentsCount = 0,
    this.missingRequiredDocumentNames = const [],
    required this.expiredDocumentsCount,
    required this.expiringSoonCount,
    required this.images,
    required this.documents,
  });

  final String id;
  final String make;
  final String model;
  final int? year;
  final String color;
  final String plateNumber;
  final String chassisNumber;
  final String engineNumber;
  final String categoryValue;
  final String categoryLabel;
  final String description;
  final bool isTinted;
  final bool hasValidPlateNumber;
  final String? status;
  final String? statusLabel;
  final bool documentsComplete;
  final int requiredDocumentsCount;
  final int missingRequiredDocumentsCount;
  final List<String> missingRequiredDocumentNames;
  final int expiredDocumentsCount;
  final int expiringSoonCount;
  final List<String> images;
  final List<VehicleDocument> documents;

  String get displayName => '$make $model'.trim();

  List<VehicleDocument> get renewableDocuments => documents
      .where((document) => document.isRenewable)
      .toList(growable: false);

  List<VehicleDocument> get otherDocuments => documents
      .where((document) => !document.isRenewable)
      .toList(growable: false);

  factory VehicleDetail.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category'];
    final category = rawCategory is Map<String, dynamic>
        ? rawCategory
        : const <String, dynamic>{};
    final rawImages = json['images'];
    final rawDocuments = json['documents'];

    return VehicleDetail(
      id: json['id']?.toString() ?? '',
      make: json['make']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      year: (json['year'] as num?)?.toInt(),
      color: json['color']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString() ?? '',
      chassisNumber: json['chassis_number']?.toString() ?? '',
      engineNumber: json['engine_number']?.toString() ?? '',
      categoryValue: category['value']?.toString() ?? '',
      categoryLabel: category['label']?.toString() ?? 'Not specified',
      description: json['description']?.toString() ?? '',
      isTinted: json['is_tinted'] == true,
      hasValidPlateNumber: json['has_valid_plate_number'] == true,
      status: json['status']?.toString(),
      statusLabel: json['status_label']?.toString(),
      documentsComplete: json['documents_complete'] == true,
      requiredDocumentsCount:
          (json['required_documents_count'] as num?)?.toInt() ?? 3,
      missingRequiredDocumentsCount:
          (json['missing_required_documents_count'] as num?)?.toInt() ?? 0,
      missingRequiredDocumentNames: _missingRequiredDocumentNames(json),
      expiredDocumentsCount:
          (json['expired_documents_count'] as num?)?.toInt() ?? 0,
      expiringSoonCount: (json['expiring_soon_count'] as num?)?.toInt() ?? 0,
      images: rawImages is List
          ? rawImages
                .whereType<String>()
                .where((value) => value.trim().isNotEmpty)
                .toList(growable: false)
          : const [],
      documents: rawDocuments is List
          ? rawDocuments
                .whereType<Map<String, dynamic>>()
                .map(VehicleDocument.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

List<String> _missingRequiredDocumentNames(Map<String, dynamic> json) {
  final documents = json['missing_required_documents'];
  if (documents is! List) return const [];
  return documents
      .whereType<Map<String, dynamic>>()
      .map((document) => document['name']?.toString() ?? '')
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
}

class VehicleDocument {
  const VehicleDocument({
    required this.id,
    required this.type,
    required this.name,
    required this.category,
    required this.documentNumber,
    required this.issuedDate,
    required this.expiryDate,
    required this.daysUntilExpiry,
    required this.issuingAuthority,
    required this.documentUrl,
    required this.originalFilename,
    required this.mimeType,
    required this.status,
    required this.statusLabel,
    required this.verification,
    required this.autoRenew,
    required this.versions,
  });

  final String id;
  final String type;
  final String name;
  final String category;
  final String? documentNumber;
  final String? issuedDate;
  final String? expiryDate;
  final int? daysUntilExpiry;
  final String? issuingAuthority;
  final String? documentUrl;
  final String? originalFilename;
  final String? mimeType;
  final String status;
  final String statusLabel;
  final DocumentVerificationSummary? verification;
  final bool autoRenew;
  final List<DocumentVersion> versions;

  bool get isRenewable => category == 'RENEWABLE';
  bool get isExpired => (daysUntilExpiry ?? 0) < 0 || status == 'EXPIRED';
  bool get hasFile => documentUrl?.isNotEmpty == true;

  List<DocumentVersion> get displayVersions {
    if (versions.isNotEmpty) return versions;
    if (!hasFile) return const [];
    return [
      DocumentVersion(
        id: id,
        documentNumber: documentNumber,
        issuedDate: issuedDate,
        expiryDate: expiryDate,
        originalFilename: originalFilename,
        mimeType: mimeType,
        isOriginal: true,
        isCurrent: true,
        recordedAt: null,
        documentUrl: documentUrl,
      ),
    ];
  }

  factory VehicleDocument.fromJson(Map<String, dynamic> json) {
    final rawType = json['document_type'];
    final type = rawType is Map<String, dynamic>
        ? rawType
        : const <String, dynamic>{};
    final rawVersions = json['versions'];

    return VehicleDocument(
      id: json['id']?.toString() ?? '',
      type: type['type']?.toString() ?? '',
      name: type['name']?.toString() ?? 'Vehicle document',
      category: type['document_category']?.toString() ?? 'OTHER',
      documentNumber: json['document_number']?.toString(),
      issuedDate: json['issued_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      daysUntilExpiry: (json['days_until_expiry'] as num?)?.toInt(),
      issuingAuthority: json['issuing_authority']?.toString(),
      documentUrl: json['document_url']?.toString(),
      originalFilename: json['original_filename']?.toString(),
      mimeType: json['mime_type']?.toString(),
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString() ?? 'On file',
      verification: json['verification'] is Map
          ? DocumentVerificationSummary.fromJson(
              Map<String, dynamic>.from(json['verification'] as Map),
            )
          : null,
      autoRenew: json['auto_renew'] == true,
      versions: rawVersions is List
          ? rawVersions
                .whereType<Map<String, dynamic>>()
                .map(DocumentVersion.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class DocumentVerificationSummary {
  const DocumentVerificationSummary({
    required this.attemptId,
    required this.status,
    required this.statusLabel,
    required this.authorityRecordStatusLabel,
    required this.evidenceLevelLabel,
    required this.verificationMethodLabel,
    required this.checkedAt,
    required this.nextCheckAt,
    required this.message,
    required this.authority,
    required this.reviewDisposition,
    required this.reviewReason,
    required this.manualUrl,
    required this.manualInstructions,
    required this.disclaimer,
  });

  final String? attemptId;
  final String status;
  final String statusLabel;
  final String? authorityRecordStatusLabel;
  final String? evidenceLevelLabel;
  final String? verificationMethodLabel;
  final String? checkedAt;
  final String? nextCheckAt;
  final String? message;
  final String? authority;
  final String? reviewDisposition;
  final String? reviewReason;
  final String? manualUrl;
  final String? manualInstructions;
  final String disclaimer;

  bool get isPending => status == 'QUEUED' || status == 'PROCESSING';
  bool get isPositive => status == 'VERIFIED' || status == 'ADMIN_REVIEWED';
  bool get isNegative =>
      status == 'MISMATCH' ||
      status == 'NO_RECORD' ||
      status == 'SOURCE_REJECTED';

  factory DocumentVerificationSummary.fromJson(Map<String, dynamic> json) {
    final review = json['review'] is Map
        ? Map<String, dynamic>.from(json['review'] as Map)
        : const <String, dynamic>{};
    final manual = json['manual_verification'] is Map
        ? Map<String, dynamic>.from(json['manual_verification'] as Map)
        : const <String, dynamic>{};
    return DocumentVerificationSummary(
      attemptId: json['attempt_id']?.toString(),
      status: json['status']?.toString() ?? 'NOT_REQUESTED',
      statusLabel: json['status_label']?.toString() ?? 'Not checked',
      authorityRecordStatusLabel: json['authority_record_status_label']
          ?.toString(),
      evidenceLevelLabel: json['evidence_level_label']?.toString(),
      verificationMethodLabel: json['verification_method_label']?.toString(),
      checkedAt: json['checked_at']?.toString(),
      nextCheckAt: json['next_check_at']?.toString(),
      message: json['message']?.toString(),
      authority: json['authority']?.toString(),
      reviewDisposition: review['disposition']?.toString(),
      reviewReason: review['reason']?.toString(),
      manualUrl: manual['url']?.toString(),
      manualInstructions: manual['instructions']?.toString(),
      disclaimer:
          json['disclaimer']?.toString() ??
          'Travla does not replace the issuing authority or original papers.',
    );
  }
}

class DocumentVerificationComparisonResult {
  const DocumentVerificationComparisonResult({
    required this.field,
    required this.label,
    required this.outcome,
    required this.comparison,
    required this.isCritical,
    required this.confidence,
  });

  final String field;
  final String label;
  final String outcome;
  final String? comparison;
  final bool isCritical;
  final double? confidence;

  factory DocumentVerificationComparisonResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return DocumentVerificationComparisonResult(
      field: json['field']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Document field',
      outcome: json['outcome']?.toString() ?? 'NOT_RETURNED',
      comparison: json['comparison']?.toString(),
      isCritical: json['is_critical'] == true,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

class DocumentVerificationDetail {
  const DocumentVerificationDetail({
    required this.summary,
    required this.reference,
    required this.officialSourceHost,
    required this.nextCheckAt,
    required this.comparisons,
  });

  final DocumentVerificationSummary summary;
  final String reference;
  final String? officialSourceHost;
  final String? nextCheckAt;
  final List<DocumentVerificationComparisonResult> comparisons;

  factory DocumentVerificationDetail.fromJson(Map<String, dynamic> json) {
    final rawSummary = json['summary'];
    final rawComparisons = json['comparisons'];
    return DocumentVerificationDetail(
      summary: DocumentVerificationSummary.fromJson(
        rawSummary is Map
            ? Map<String, dynamic>.from(rawSummary)
            : const <String, dynamic>{},
      ),
      reference: json['reference']?.toString() ?? '',
      officialSourceHost: json['official_source_host']?.toString(),
      nextCheckAt: json['next_check_at']?.toString(),
      comparisons: rawComparisons is List
          ? rawComparisons
                .whereType<Map>()
                .map(
                  (item) => DocumentVerificationComparisonResult.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class DocumentVerificationWorkspace {
  const DocumentVerificationWorkspace({
    required this.current,
    required this.history,
    required this.isFromCache,
    required this.cachedAt,
  });

  final DocumentVerificationDetail? current;
  final List<DocumentVerificationSummary> history;
  final bool isFromCache;
  final DateTime? cachedAt;

  bool get isStale =>
      isFromCache &&
      (cachedAt == null ||
          DateTime.now().difference(cachedAt!) > const Duration(minutes: 15));

  factory DocumentVerificationWorkspace.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
    DateTime? cachedAt,
  }) {
    final rawCurrent = json['current'];
    final rawHistory = json['history'];
    return DocumentVerificationWorkspace(
      current: rawCurrent is Map
          ? DocumentVerificationDetail.fromJson(
              Map<String, dynamic>.from(rawCurrent),
            )
          : null,
      history: rawHistory is List
          ? rawHistory
                .whereType<Map>()
                .map(
                  (item) => DocumentVerificationSummary.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      isFromCache: isFromCache,
      cachedAt: cachedAt,
    );
  }
}

class DocumentVersion {
  const DocumentVersion({
    required this.id,
    required this.documentNumber,
    required this.issuedDate,
    required this.expiryDate,
    required this.originalFilename,
    required this.mimeType,
    required this.isOriginal,
    required this.isCurrent,
    required this.recordedAt,
    required this.documentUrl,
  });

  final String id;
  final String? documentNumber;
  final String? issuedDate;
  final String? expiryDate;
  final String? originalFilename;
  final String? mimeType;
  final bool isOriginal;
  final bool isCurrent;
  final DateTime? recordedAt;
  final String? documentUrl;

  factory DocumentVersion.fromJson(Map<String, dynamic> json) {
    return DocumentVersion(
      id: json['id']?.toString() ?? '',
      documentNumber: json['document_number']?.toString(),
      issuedDate: json['issued_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      originalFilename: json['original_filename']?.toString(),
      mimeType: json['mime_type']?.toString(),
      isOriginal: json['is_original'] == true,
      isCurrent: json['is_current'] == true,
      recordedAt: DateTime.tryParse(json['recorded_at']?.toString() ?? ''),
      documentUrl: json['document_url']?.toString(),
    );
  }
}

class AvailableDocumentType {
  const AvailableDocumentType({
    required this.type,
    required this.name,
    required this.description,
    required this.category,
    required this.requiresUpload,
    required this.alreadyAdded,
  });

  final String type;
  final String name;
  final String? description;
  final String category;
  final bool requiresUpload;
  final bool alreadyAdded;

  bool get isRenewable => category == 'RENEWABLE';
  bool get fileRequired => !isRenewable || requiresUpload;

  factory AvailableDocumentType.fromJson(Map<String, dynamic> json) {
    return AvailableDocumentType(
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Document',
      description: json['description']?.toString(),
      category: json['document_category']?.toString() ?? 'OTHER',
      requiresUpload: json['requires_upload'] == true,
      alreadyAdded: json['already_added'] == true,
    );
  }
}

class IssuingAuthorityOption {
  const IssuingAuthorityOption({
    required this.id,
    required this.code,
    required this.name,
    required this.shortName,
    required this.jurisdiction,
    required this.state,
  });

  final String id;
  final String code;
  final String name;
  final String? shortName;
  final String jurisdiction;
  final String? state;

  String get displayName =>
      shortName?.isNotEmpty == true ? '$name ($shortName)' : name;

  factory IssuingAuthorityOption.fromJson(Map<String, dynamic> json) {
    return IssuingAuthorityOption(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Issuing authority',
      shortName: json['short_name']?.toString(),
      jurisdiction: json['jurisdiction']?.toString() ?? '',
      state: json['state']?.toString(),
    );
  }
}

DateTime? parseDateOnly(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split('-').map(int.tryParse).toList(growable: false);
  if (parts.length != 3 || parts.any((part) => part == null)) return null;
  return DateTime(parts[0]!, parts[1]!, parts[2]!);
}

DateTime oneYearAfterNoOverflow(DateTime issued) {
  final candidate = DateTime(issued.year + 1, issued.month, issued.day);
  if (candidate.month == issued.month) return candidate;
  return DateTime(issued.year + 1, issued.month + 1, 0);
}

String apiDate(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
}
