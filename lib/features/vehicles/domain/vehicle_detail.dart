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
    required this.categoryLabel,
    required this.isTinted,
    required this.hasValidPlateNumber,
    required this.status,
    required this.statusLabel,
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
  final String categoryLabel;
  final bool isTinted;
  final bool hasValidPlateNumber;
  final String? status;
  final String? statusLabel;
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
      categoryLabel: category['label']?.toString() ?? 'Not specified',
      isTinted: json['is_tinted'] == true,
      hasValidPlateNumber: json['has_valid_plate_number'] == true,
      status: json['status']?.toString(),
      statusLabel: json['status_label']?.toString(),
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
