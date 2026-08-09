class VehicleModelOption {
  const VehicleModelOption({required this.name, required this.category});

  final String name;
  final String category;

  factory VehicleModelOption.fromJson(Map<String, dynamic> json) {
    return VehicleModelOption(
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
    );
  }
}

class VehicleMakeOption {
  const VehicleMakeOption({required this.name, required this.models});

  final String name;
  final List<VehicleModelOption> models;

  factory VehicleMakeOption.fromJson(Map<String, dynamic> json) {
    final rawModels = json['models'];
    return VehicleMakeOption(
      name: json['name']?.toString() ?? '',
      models: rawModels is List
          ? rawModels
                .whereType<Map<String, dynamic>>()
                .map(VehicleModelOption.fromJson)
                .where((model) => model.name.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class VehicleCategoryOption {
  const VehicleCategoryOption({
    required this.value,
    required this.label,
    required this.registrationFeeNaira,
  });

  final String value;
  final String label;
  final String registrationFeeNaira;

  factory VehicleCategoryOption.fromJson(Map<String, dynamic> json) {
    return VehicleCategoryOption(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      registrationFeeNaira:
          json['effective_registration_fee_naira']?.toString() ?? '0.00',
    );
  }
}

class VehicleCatalogue {
  const VehicleCatalogue({
    required this.makes,
    required this.categories,
    required this.fallbackCategory,
  });

  final List<VehicleMakeOption> makes;
  final List<VehicleCategoryOption> categories;
  final String fallbackCategory;

  VehicleCategoryOption? category(String? value) {
    for (final category in categories) {
      if (category.value == value) return category;
    }
    return null;
  }

  factory VehicleCatalogue.fromJson(
    Map<String, dynamic> json,
    List<dynamic> rawCategories,
  ) {
    final rawMakes = json['makes'];
    return VehicleCatalogue(
      makes: rawMakes is List
          ? rawMakes
                .whereType<Map<String, dynamic>>()
                .map(VehicleMakeOption.fromJson)
                .where((make) => make.name.isNotEmpty)
                .toList(growable: false)
          : const [],
      categories: rawCategories
          .whereType<Map<String, dynamic>>()
          .map(VehicleCategoryOption.fromJson)
          .where((category) => category.value.isNotEmpty)
          .toList(growable: false),
      fallbackCategory: json['fallback_category']?.toString() ?? 'other',
    );
  }
}

class AddedVehicleResult {
  const AddedVehicleResult({required this.id, this.stolenMatch});

  final String id;
  final Map<String, dynamic>? stolenMatch;
}
