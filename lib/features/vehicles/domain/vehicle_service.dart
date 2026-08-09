class VehicleServiceCatalogueItem {
  const VehicleServiceCatalogueItem({
    required this.value,
    required this.label,
    required this.description,
    required this.requirements,
    required this.estimatedPriceNaira,
    required this.isFixedPrice,
  });

  final String value;
  final String label;
  final String description;
  final List<String> requirements;
  final String estimatedPriceNaira;
  final bool isFixedPrice;

  factory VehicleServiceCatalogueItem.fromJson(Map<String, dynamic> json) {
    final rawRequirements = json['requirements'];
    return VehicleServiceCatalogueItem(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Vehicle service',
      description: json['description']?.toString() ?? '',
      requirements: rawRequirements is List
          ? rawRequirements
                .map((item) => item.toString())
                .toList(growable: false)
          : const [],
      estimatedPriceNaira: json['estimated_price_naira']?.toString() ?? '0.00',
      isFixedPrice: json['is_fixed_price'] == true,
    );
  }
}

class VehicleServiceOrder {
  const VehicleServiceOrder({
    required this.id,
    required this.serviceType,
    required this.serviceLabel,
    required this.isFixedPrice,
    required this.status,
    required this.statusLabel,
    required this.details,
    required this.estimatedPriceNaira,
    required this.quotedPriceNaira,
    required this.amountDueNaira,
    required this.deliveryFeeNaira,
    required this.isPaid,
    required this.deliveryMethod,
    required this.city,
    required this.preferredDate,
    required this.adminNote,
    required this.trackingNumber,
    required this.isOpen,
    required this.createdAt,
  });

  final String id;
  final String serviceType;
  final String serviceLabel;
  final bool isFixedPrice;
  final String status;
  final String statusLabel;
  final Map<String, String> details;
  final String estimatedPriceNaira;
  final String? quotedPriceNaira;
  final String amountDueNaira;
  final String deliveryFeeNaira;
  final bool isPaid;
  final String? deliveryMethod;
  final String? city;
  final String? preferredDate;
  final String? adminNote;
  final String? trackingNumber;
  final bool isOpen;
  final DateTime? createdAt;

  bool get canPay =>
      !isPaid &&
      !isFixedPrice &&
      quotedPriceNaira != null &&
      status != 'CANCELLED' &&
      status != 'REJECTED';
  bool get canCancel => status == 'PENDING';

  factory VehicleServiceOrder.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    return VehicleServiceOrder(
      id: json['id']?.toString() ?? '',
      serviceType: json['service_type']?.toString() ?? '',
      serviceLabel: json['service_label']?.toString() ?? 'Vehicle service',
      isFixedPrice: json['is_fixed_price'] == true,
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString() ?? 'Pending',
      details: rawDetails is Map
          ? rawDetails.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      estimatedPriceNaira: json['estimated_price_naira']?.toString() ?? '0.00',
      quotedPriceNaira: json['quoted_price_naira']?.toString(),
      amountDueNaira: json['amount_due_naira']?.toString() ?? '0.00',
      deliveryFeeNaira: json['delivery_fee_naira']?.toString() ?? '0.00',
      isPaid: json['is_paid'] == true,
      deliveryMethod: json['delivery_method']?.toString(),
      city: json['city']?.toString(),
      preferredDate: json['preferred_date']?.toString(),
      adminNote: json['admin_note']?.toString(),
      trackingNumber: json['tracking_number']?.toString(),
      isOpen: json['is_open'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class VehicleServiceCity {
  const VehicleServiceCity({required this.city, required this.state});

  final String city;
  final String state;

  factory VehicleServiceCity.fromJson(Map<String, dynamic> json) {
    return VehicleServiceCity(
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
    );
  }
}

class VehicleServiceWorkspace {
  const VehicleServiceWorkspace({
    required this.catalogue,
    required this.orders,
    required this.cities,
  });

  final List<VehicleServiceCatalogueItem> catalogue;
  final List<VehicleServiceOrder> orders;
  final List<VehicleServiceCity> cities;

  int get activeOrders => orders.where((order) => order.isOpen).length;
}
