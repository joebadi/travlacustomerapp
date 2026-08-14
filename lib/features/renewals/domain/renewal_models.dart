class RenewalServiceCity {
  const RenewalServiceCity({required this.city, required this.state});

  final String city;
  final String state;

  factory RenewalServiceCity.fromJson(Map<String, dynamic> json) {
    return RenewalServiceCity(
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
    );
  }
}

class RenewableDocumentOption {
  const RenewableDocumentOption({
    required this.id,
    required this.type,
    required this.name,
    required this.renewalCostNaira,
    required this.eligible,
    required this.reason,
    required this.hasDocument,
    required this.needsUpload,
    required this.expiryDate,
    required this.daysToExpiry,
  });

  final String id;
  final String type;
  final String name;
  final String renewalCostNaira;
  final bool eligible;
  final String? reason;
  final bool hasDocument;
  final bool needsUpload;
  final String? expiryDate;
  final int? daysToExpiry;

  factory RenewableDocumentOption.fromJson(Map<String, dynamic> json) {
    return RenewableDocumentOption(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Vehicle paper',
      renewalCostNaira: json['renewal_cost_naira']?.toString() ?? '0.00',
      eligible: json['eligible'] == true,
      reason: json['reason']?.toString(),
      hasDocument: json['has_document'] == true,
      needsUpload: json['needs_upload'] == true,
      expiryDate: json['expiry_date']?.toString(),
      daysToExpiry: _intOrNull(json['days_to_expiry']),
    );
  }
}

class RenewalQuoteItem {
  const RenewalQuoteItem({
    required this.documentTypeId,
    required this.type,
    required this.name,
    required this.eligible,
    required this.reason,
    required this.priceKobo,
    required this.priceNaira,
  });

  final String documentTypeId;
  final String type;
  final String name;
  final bool eligible;
  final String? reason;
  final int priceKobo;
  final String priceNaira;

  factory RenewalQuoteItem.fromJson(Map<String, dynamic> json) {
    return RenewalQuoteItem(
      documentTypeId: json['document_type_id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Vehicle paper',
      eligible: json['eligible'] == true,
      reason: json['reason']?.toString(),
      priceKobo: _int(json['price_kobo']),
      priceNaira: json['price_naira']?.toString() ?? '0.00',
    );
  }
}

class RenewalQuote {
  const RenewalQuote({
    required this.items,
    required this.documentsKobo,
    required this.documentsNaira,
    required this.insuranceItems,
    required this.insuranceKobo,
    required this.insuranceNaira,
    required this.deliveryFeeKobo,
    required this.deliveryFeeNaira,
    required this.totalKobo,
    required this.totalNaira,
    required this.walletBalanceKobo,
    required this.walletBalanceNaira,
    required this.sufficientBalance,
    required this.shortfallKobo,
    required this.shortfallNaira,
  });

  final List<RenewalQuoteItem> items;
  final int documentsKobo;
  final String documentsNaira;
  final List<RenewalInsuranceQuoteItem> insuranceItems;
  final int insuranceKobo;
  final String insuranceNaira;
  final int deliveryFeeKobo;
  final String deliveryFeeNaira;
  final int totalKobo;
  final String totalNaira;
  final int walletBalanceKobo;
  final String walletBalanceNaira;
  final bool sufficientBalance;
  final int shortfallKobo;
  final String shortfallNaira;

  /// Total line count across documents and insurance — used for the order
  /// summary count and to tell an empty quote apart from a priced one.
  int get itemCount => items.length + insuranceItems.length;

  /// A quote can proceed only when every server-priced document and insurance
  /// line remains eligible. Empty collections are neutral, matching `every`.
  bool get allEligible =>
      items.every((item) => item.eligible) &&
      insuranceItems.every((item) => item.eligible);

  factory RenewalQuote.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawInsuranceItems = json['insurance_items'];
    return RenewalQuote(
      items: rawItems is List
          ? rawItems
                .map(_map)
                .whereType<Map<String, dynamic>>()
                .map(RenewalQuoteItem.fromJson)
                .toList(growable: false)
          : const [],
      documentsKobo: _int(json['documents_kobo']),
      documentsNaira: json['documents_naira']?.toString() ?? '0.00',
      insuranceItems: rawInsuranceItems is List
          ? rawInsuranceItems
                .map(_map)
                .whereType<Map<String, dynamic>>()
                .map(RenewalInsuranceQuoteItem.fromJson)
                .toList(growable: false)
          : const [],
      insuranceKobo: _int(json['insurance_kobo']),
      insuranceNaira: json['insurance_naira']?.toString() ?? '0.00',
      deliveryFeeKobo: _int(json['delivery_fee_kobo']),
      deliveryFeeNaira: json['delivery_fee_naira']?.toString() ?? '0.00',
      totalKobo: _int(json['total_kobo']),
      totalNaira: json['total_naira']?.toString() ?? '0.00',
      walletBalanceKobo: _int(json['wallet_balance_kobo']),
      walletBalanceNaira: json['wallet_balance_naira']?.toString() ?? '0.00',
      sufficientBalance: json['sufficient_balance'] == true,
      shortfallKobo: _int(json['shortfall_kobo']),
      shortfallNaira: json['shortfall_naira']?.toString() ?? '0.00',
    );
  }
}

/// An insurance line item riding in a papers order (agent method only) — a
/// policy renewal or a new-policy buy, priced off the admin's configured
/// Motor Insurance rate. Distinct from [RenewalQuoteItem] because the backend
/// keys it by policy/coverage rather than a document type.
class RenewalInsuranceQuoteItem {
  const RenewalInsuranceQuoteItem({
    required this.kind,
    required this.label,
    required this.eligible,
    required this.reason,
    required this.priceKobo,
    required this.priceNaira,
  });

  final String kind; // 'renew' or 'buy'
  final String label;
  final bool eligible;
  final String? reason;
  final int priceKobo;
  final String priceNaira;

  factory RenewalInsuranceQuoteItem.fromJson(Map<String, dynamic> json) {
    return RenewalInsuranceQuoteItem(
      kind: json['kind']?.toString() ?? 'renew',
      label: json['label']?.toString() ?? 'Insurance',
      eligible: json['eligible'] == true,
      reason: json['reason']?.toString(),
      priceKobo: _int(json['price_kobo']),
      priceNaira: json['price_naira']?.toString() ?? '0.00',
    );
  }
}

class RenewalCreated {
  const RenewalCreated({
    required this.count,
    required this.orderGroupId,
    required this.orderReference,
  });

  final int count;
  final String orderGroupId;
  final String orderReference;

  factory RenewalCreated.fromJson(Map<String, dynamic> json) {
    return RenewalCreated(
      count: _int(json['count']),
      orderGroupId: json['order_group_id']?.toString() ?? '',
      orderReference: json['order_reference']?.toString() ?? '',
    );
  }
}

class RenewalDocumentSnapshot {
  const RenewalDocumentSnapshot({
    required this.documentNumber,
    required this.issuedDate,
    required this.expiryDate,
    required this.originalFilename,
    required this.mimeType,
    required this.documentUrl,
  });

  final String? documentNumber;
  final String? issuedDate;
  final String? expiryDate;
  final String? originalFilename;
  final String? mimeType;
  final String? documentUrl;

  factory RenewalDocumentSnapshot.fromJson(Map<String, dynamic> json) {
    return RenewalDocumentSnapshot(
      documentNumber: json['document_number']?.toString(),
      issuedDate: json['issued_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      originalFilename: json['original_filename']?.toString(),
      mimeType: json['mime_type']?.toString(),
      documentUrl: json['document_url']?.toString(),
    );
  }
}

class RenewalProcessing {
  const RenewalProcessing({
    required this.status,
    required this.processedDate,
    required this.readyForPickup,
  });

  final String status;
  final DateTime? processedDate;
  final bool readyForPickup;

  factory RenewalProcessing.fromJson(Map<String, dynamic> json) {
    return RenewalProcessing(
      status: json['processing_status']?.toString() ?? '',
      processedDate: DateTime.tryParse(
        json['processed_date']?.toString() ?? '',
      ),
      readyForPickup: json['ready_for_pickup'] == true,
    );
  }
}

class RenewalRider {
  const RenewalRider({required this.name, required this.phone});

  final String name;
  final String phone;

  factory RenewalRider.fromJson(Map<String, dynamic> json) {
    return RenewalRider(
      name: json['name']?.toString() ?? 'Travla rider',
      phone: json['phone']?.toString() ?? '',
    );
  }
}

class RenewalDelivery {
  const RenewalDelivery({
    required this.status,
    required this.statusLabel,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.pickupDate,
    required this.deliveryDate,
    required this.handoverOtp,
    required this.rider,
    required this.riderLatitude,
    required this.riderLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });

  final String status;
  final String statusLabel;
  final String? pickupLocation;
  final String? deliveryLocation;
  final DateTime? pickupDate;
  final DateTime? deliveryDate;
  final String? handoverOtp;
  final RenewalRider? rider;
  final double? riderLatitude;
  final double? riderLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;

  int get stage => switch (status) {
    'READY_FOR_PICKUP' => 1,
    'PICKED_UP' => 2,
    'IN_TRANSIT' => 3,
    'DELIVERED' => 4,
    _ => 0,
  };

  factory RenewalDelivery.fromJson(Map<String, dynamic> json) {
    final rider = _map(json['rider']);
    return RenewalDelivery(
      status: json['status']?.toString() ?? 'PENDING',
      statusLabel: json['status_label']?.toString() ?? 'Pending',
      pickupLocation: json['pickup_location']?.toString(),
      deliveryLocation: json['delivery_location']?.toString(),
      pickupDate: DateTime.tryParse(json['pickup_date']?.toString() ?? ''),
      deliveryDate: DateTime.tryParse(json['delivery_date']?.toString() ?? ''),
      handoverOtp: json['handover_otp']?.toString(),
      rider: rider == null ? null : RenewalRider.fromJson(rider),
      riderLatitude: _doubleOrNull(json['rider_latitude']),
      riderLongitude: _doubleOrNull(json['rider_longitude']),
      destinationLatitude: _doubleOrNull(json['destination_latitude']),
      destinationLongitude: _doubleOrNull(json['destination_longitude']),
    );
  }
}

class RenewalActionRequest {
  const RenewalActionRequest({
    required this.reason,
    required this.reasonLabel,
    required this.message,
    required this.raisedAt,
  });

  final String reason;
  final String reasonLabel;
  final String message;
  final DateTime? raisedAt;

  factory RenewalActionRequest.fromJson(Map<String, dynamic> json) {
    return RenewalActionRequest(
      reason: json['reason']?.toString() ?? '',
      reasonLabel: json['reason_label']?.toString() ?? 'Action required',
      message: json['message']?.toString() ?? '',
      raisedAt: DateTime.tryParse(json['raised_at']?.toString() ?? ''),
    );
  }
}

class RenewalVehicle {
  const RenewalVehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.plateNumber,
  });

  final String id;
  final String make;
  final String model;
  final String plateNumber;
  String get displayName => '$make $model'.trim();

  factory RenewalVehicle.fromJson(Map<String, dynamic> json) {
    return RenewalVehicle(
      id: json['id']?.toString() ?? '',
      make: json['make']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString() ?? '',
    );
  }
}

class RenewalRecord {
  const RenewalRecord({
    required this.id,
    required this.orderGroupId,
    required this.orderReference,
    required this.trackingNumber,
    required this.status,
    required this.statusLabel,
    required this.paymentStatus,
    required this.amountKobo,
    required this.amountNaira,
    required this.deliveryFeeKobo,
    required this.deliveryFeeNaira,
    required this.deliveryMethod,
    required this.deliveryMethodLabel,
    required this.deliveryAddress,
    required this.city,
    required this.state,
    required this.notes,
    required this.requestDate,
    required this.completionDate,
    required this.subjectType,
    required this.documentType,
    required this.documentName,
    required this.vehicle,
    required this.currentDocument,
    required this.previousDocument,
    required this.renewedDocument,
    required this.processing,
    required this.delivery,
    required this.actionRequest,
  });

  final String id;
  final String orderGroupId;
  final String orderReference;
  final String trackingNumber;
  final String status;
  final String statusLabel;
  final String paymentStatus;
  final int amountKobo;
  final String amountNaira;
  final int deliveryFeeKobo;
  final String deliveryFeeNaira;
  final String deliveryMethod;
  final String deliveryMethodLabel;
  final String? deliveryAddress;
  final String city;
  final String state;
  final String? notes;
  final DateTime? requestDate;
  final DateTime? completionDate;
  final String subjectType;
  final String documentType;
  final String documentName;
  final RenewalVehicle? vehicle;
  final RenewalDocumentSnapshot? currentDocument;
  final RenewalDocumentSnapshot? previousDocument;
  final RenewalDocumentSnapshot? renewedDocument;
  final RenewalProcessing? processing;
  final RenewalDelivery? delivery;
  final RenewalActionRequest? actionRequest;

  bool get isPending => status == 'PENDING';
  bool get isCompleted => status == 'COMPLETED';

  factory RenewalRecord.fromJson(Map<String, dynamic> json) {
    final type = _map(json['document_type']);
    return RenewalRecord(
      id: json['id']?.toString() ?? '',
      orderGroupId: json['order_group_id']?.toString() ?? '',
      orderReference: json['order_reference']?.toString() ?? '',
      trackingNumber: json['tracking_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString() ?? 'Pending',
      paymentStatus: json['payment_status']?.toString() ?? '',
      amountKobo: _int(json['amount_kobo']),
      amountNaira: json['amount_naira']?.toString() ?? '0.00',
      deliveryFeeKobo: _int(json['delivery_fee_kobo']),
      deliveryFeeNaira: json['delivery_fee_naira']?.toString() ?? '0.00',
      deliveryMethod: json['delivery_method']?.toString() ?? '',
      deliveryMethodLabel:
          json['delivery_method_label']?.toString() ?? 'Pickup',
      deliveryAddress: json['delivery_address']?.toString(),
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      notes: json['notes']?.toString(),
      requestDate: DateTime.tryParse(json['request_date']?.toString() ?? ''),
      completionDate: DateTime.tryParse(
        json['completion_date']?.toString() ?? '',
      ),
      subjectType: json['subject_type']?.toString() ?? 'VEHICLE',
      documentType: type?['type']?.toString() ?? '',
      documentName: type?['name']?.toString() ?? 'Vehicle paper',
      vehicle: _model(json['vehicle'], RenewalVehicle.fromJson),
      currentDocument: _model(
        json['current_document'],
        RenewalDocumentSnapshot.fromJson,
      ),
      previousDocument: _model(
        json['previous_document'],
        RenewalDocumentSnapshot.fromJson,
      ),
      renewedDocument: _model(
        json['renewed_document'],
        RenewalDocumentSnapshot.fromJson,
      ),
      processing: _model(json['processing'], RenewalProcessing.fromJson),
      delivery: _model(json['delivery'], RenewalDelivery.fromJson),
      actionRequest: _model(
        json['action_request'],
        RenewalActionRequest.fromJson,
      ),
    );
  }
}

class RenewalOrderSummary {
  const RenewalOrderSummary({
    required this.groupId,
    required this.reference,
    required this.items,
  });

  final String groupId;
  final String reference;
  final List<RenewalRecord> items;

  RenewalRecord get first => items.first;
  int get totalKobo => items.fold(
    0,
    (total, item) => total + item.amountKobo + item.deliveryFeeKobo,
  );
  String get documentNames => items
      .map((item) => item.documentName)
      .where((name) => name.isNotEmpty)
      .join(', ');
  Set<String> get statuses => items.map((item) => item.status).toSet();
  bool get canCancel =>
      items.isNotEmpty && items.every((item) => item.isPending);
  int get completedCount => items.where((item) => item.isCompleted).length;

  static List<RenewalOrderSummary> group(List<RenewalRecord> records) {
    final grouped = <String, List<RenewalRecord>>{};
    for (final record in records) {
      final key = record.orderGroupId.isEmpty ? record.id : record.orderGroupId;
      grouped.putIfAbsent(key, () => []).add(record);
    }
    return grouped.entries
        .map(
          (entry) => RenewalOrderSummary(
            groupId: entry.key,
            reference: entry.value.first.orderReference.isNotEmpty
                ? entry.value.first.orderReference
                : entry.value.first.trackingNumber,
            items: entry.value,
          ),
        )
        .toList(growable: false);
  }
}

T? _model<T>(Object? value, T Function(Map<String, dynamic>) builder) {
  final map = _map(value);
  return map == null ? null : builder(map);
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return null;
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
