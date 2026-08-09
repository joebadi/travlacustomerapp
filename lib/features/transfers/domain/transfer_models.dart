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
  const TransferSetup({required this.cities, required this.fieldsByBasis});
  final List<TransferCity> cities;
  final Map<String, List<TransferDocumentField>> fieldsByBasis;

  List<TransferDocumentField> fieldsFor(String basis, {bool tinted = false}) {
    return (fieldsByBasis[basis] ?? const [])
        .map((field) {
          if (field.key == 'tinted_permit' && tinted) {
            return field.copyWith(
              required: true,
              conditionalNote:
                  'Required because this vehicle is marked as tinted.',
            );
          }
          return field;
        })
        .toList(growable: false);
  }
}

class TransferDocumentField {
  const TransferDocumentField({
    required this.key,
    required this.label,
    required this.category,
    required this.required,
    required this.requiresMetadata,
    required this.conditionalNote,
  });
  final String key;
  final String label;
  final String category;
  final bool required;
  final bool requiresMetadata;
  final String? conditionalNote;
  factory TransferDocumentField.fromJson(Map<String, dynamic> json) =>
      TransferDocumentField(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? 'Transfer document',
        category: json['category']?.toString() ?? 'OTHER',
        required: json['required'] == true,
        requiresMetadata: json['requires_metadata'] == true,
        conditionalNote: json['conditional_note']?.toString(),
      );
  TransferDocumentField copyWith({bool? required, String? conditionalNote}) =>
      TransferDocumentField(
        key: key,
        label: label,
        category: category,
        required: required ?? this.required,
        requiresMetadata: requiresMetadata,
        conditionalNote: conditionalNote ?? this.conditionalNote,
      );
}

class TransferEvidenceUpload {
  const TransferEvidenceUpload({
    required this.key,
    required this.path,
    required this.name,
    required this.documentNumber,
    required this.issuer,
    required this.issueDate,
  });
  final String key;
  final String path;
  final String name;
  final String documentNumber;
  final String issuer;
  final DateTime? issueDate;
  bool completeFor(TransferDocumentField field) =>
      path.isNotEmpty &&
      (!field.requiresMetadata ||
          (documentNumber.trim().isNotEmpty &&
              issuer.trim().isNotEmpty &&
              issueDate != null));
}

class TransferRecord {
  const TransferRecord({
    required this.id,
    required this.trackingNumber,
    required this.status,
    required this.statusLabel,
    required this.transferMode,
    required this.transferModeLabel,
    required this.transferBasis,
    required this.transferBasisLabel,
    required this.reviewStatus,
    required this.reviewStatusLabel,
    required this.paymentStatus,
    required this.amountKobo,
    required this.amountNaira,
    required this.deliveryFeeKobo,
    required this.deliveryFeeNaira,
    required this.deliveryMethod,
    required this.deliveryMethodLabel,
    required this.collectionCity,
    required this.jurisdictionState,
    required this.consentVerified,
    required this.recipientInvited,
    required this.createdAt,
    required this.legalTransferVerifiedAt,
    required this.reviewNotes,
    required this.amISender,
    required this.amIRecipient,
    required this.canCancel,
    required this.cancellationReopensMarketplace,
    required this.recipient,
    required this.currentOwner,
    required this.vehicle,
    required this.delivery,
    required this.history,
    required this.documents,
  });

  final String id;
  final String trackingNumber;
  final String status;
  final String statusLabel;
  final String transferMode;
  final String transferModeLabel;
  final String transferBasis;
  final String transferBasisLabel;
  final String reviewStatus;
  final String reviewStatusLabel;
  final String paymentStatus;
  final int amountKobo;
  final String amountNaira;
  final int deliveryFeeKobo;
  final String deliveryFeeNaira;
  final String deliveryMethod;
  final String deliveryMethodLabel;
  final String collectionCity;
  final String jurisdictionState;
  final bool consentVerified;
  final bool recipientInvited;
  final DateTime? createdAt;
  final DateTime? legalTransferVerifiedAt;
  final String? reviewNotes;
  final bool amISender;
  final bool amIRecipient;
  final bool canCancel;
  final bool cancellationReopensMarketplace;
  final TransferParty recipient;
  final TransferParty? currentOwner;
  final TransferVehicle? vehicle;
  final TransferDelivery? delivery;
  final List<TransferHistoryEvent> history;
  final List<TransferEvidenceDocument> documents;

  bool get isFinished =>
      status == 'COMPLETED' || status == 'CANCELLED' || status == 'REJECTED';
  bool get awaitsMyConsent =>
      amIRecipient &&
      reviewStatus == 'AWAITING_RECIPIENT' &&
      !consentVerified &&
      !isFinished;
  String get directionLabel => amISender ? 'Sent' : 'Received';

  factory TransferRecord.fromJson(Map<String, dynamic> json) {
    final history = json['history'];
    final documents = json['documents'];
    final recipient = _asStringMap(json['recipient']);
    final currentOwner = _asStringMap(json['current_owner']);
    final vehicle = _asStringMap(json['vehicle']);
    final delivery = _asStringMap(json['delivery']);
    return TransferRecord(
      id: json['id']?.toString() ?? '',
      trackingNumber: json['tracking_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString() ?? 'Transfer pending',
      transferMode: json['transfer_mode']?.toString() ?? 'MANAGED',
      transferModeLabel:
          json['transfer_mode_label']?.toString() ?? 'Travla managed',
      transferBasis: json['transfer_basis']?.toString() ?? '',
      transferBasisLabel:
          json['transfer_basis_label']?.toString() ?? 'Ownership change',
      reviewStatus: json['review_status']?.toString() ?? '',
      reviewStatusLabel:
          json['review_status_label']?.toString() ?? 'Pending review',
      paymentStatus: json['payment_status']?.toString() ?? '',
      amountKobo: _intValue(json['amount_kobo']),
      amountNaira: json['amount_naira']?.toString() ?? '0.00',
      deliveryFeeKobo: _intValue(json['delivery_fee_kobo']),
      deliveryFeeNaira: json['delivery_fee_naira']?.toString() ?? '0.00',
      deliveryMethod: json['delivery_method']?.toString() ?? 'PICKUP',
      deliveryMethodLabel:
          json['delivery_method_label']?.toString() ?? 'Office pickup',
      collectionCity: json['collection_city']?.toString() ?? '',
      jurisdictionState: json['jurisdiction_state']?.toString() ?? '',
      consentVerified: json['consent_verified'] == true,
      recipientInvited: json['recipient_invited'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      legalTransferVerifiedAt: DateTime.tryParse(
        json['legal_transfer_verified_at']?.toString() ?? '',
      ),
      reviewNotes: json['review_notes']?.toString(),
      amISender: json['am_i_sender'] == true,
      amIRecipient: json['am_i_recipient'] == true,
      canCancel: json['can_cancel'] == true,
      cancellationReopensMarketplace:
          json['cancellation_reopens_marketplace'] == true,
      recipient: TransferParty.fromJson(recipient),
      currentOwner: currentOwner.isEmpty
          ? null
          : TransferParty.fromJson(currentOwner),
      vehicle: vehicle.isEmpty ? null : TransferVehicle.fromJson(vehicle),
      delivery: delivery.isEmpty ? null : TransferDelivery.fromJson(delivery),
      history: history is List
          ? history
                .whereType<Map<String, dynamic>>()
                .map(TransferHistoryEvent.fromJson)
                .toList(growable: false)
          : const [],
      documents: documents is List
          ? documents
                .whereType<Map<String, dynamic>>()
                .map(TransferEvidenceDocument.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class TransferParty {
  const TransferParty({required this.name, required this.email});
  final String name;
  final String email;
  factory TransferParty.fromJson(Map<String, dynamic> json) => TransferParty(
    name: json['name']?.toString().trim().isNotEmpty == true
        ? json['name'].toString()
        : '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
    email: json['email']?.toString() ?? '',
  );
}

class TransferVehicle {
  const TransferVehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plateNumber,
  });
  final String id;
  final String make;
  final String model;
  final int? year;
  final String color;
  final String plateNumber;
  String get displayName => '$make $model'.trim();
  factory TransferVehicle.fromJson(Map<String, dynamic> json) =>
      TransferVehicle(
        id: json['id']?.toString() ?? '',
        make: json['make']?.toString() ?? '',
        model: json['model']?.toString() ?? '',
        year: _nullableInt(json['year']),
        color: json['color']?.toString() ?? '',
        plateNumber: json['plate_number']?.toString() ?? '',
      );
}

class TransferDelivery {
  const TransferDelivery({required this.status, required this.statusLabel});
  final String status;
  final String statusLabel;
  factory TransferDelivery.fromJson(Map<String, dynamic> json) =>
      TransferDelivery(
        status: json['status']?.toString() ?? '',
        statusLabel: json['status_label']?.toString() ?? '',
      );
}

class TransferHistoryEvent {
  const TransferHistoryEvent({
    required this.eventType,
    required this.label,
    required this.description,
    required this.createdAt,
  });
  final String eventType;
  final String label;
  final String description;
  final DateTime? createdAt;
  factory TransferHistoryEvent.fromJson(Map<String, dynamic> json) =>
      TransferHistoryEvent(
        eventType: json['event_type']?.toString() ?? '',
        label: json['label']?.toString() ?? 'Transfer activity',
        description: json['description']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

class TransferEvidenceDocument {
  const TransferEvidenceDocument({
    required this.id,
    required this.label,
    required this.category,
    required this.filename,
    required this.verificationStatus,
    required this.documentNumber,
    required this.expiryDate,
    required this.url,
    required this.published,
  });
  final String id;
  final String label;
  final String? category;
  final String? filename;
  final String verificationStatus;
  final String? documentNumber;
  final String? expiryDate;
  final String url;
  final bool published;
  factory TransferEvidenceDocument.fromJson(Map<String, dynamic> json) =>
      TransferEvidenceDocument(
        id: json['id']?.toString() ?? '',
        label: json['document_label']?.toString() ?? 'Transfer document',
        category: json['document_category']?.toString(),
        filename: json['original_filename']?.toString(),
        verificationStatus:
            json['verification_status']?.toString() ?? 'PENDING',
        documentNumber: json['document_number']?.toString(),
        expiryDate: json['expiry_date']?.toString(),
        url: json['document_url']?.toString() ?? '',
        published: json['published_at'] != null,
      );
}

Map<String, dynamic> _asStringMap(dynamic value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : const <String, dynamic>{};

int _intValue(dynamic value) => _nullableInt(value) ?? 0;
int? _nullableInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
