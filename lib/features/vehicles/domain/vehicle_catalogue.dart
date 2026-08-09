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

class VehicleCatalogue {
  const VehicleCatalogue({required this.makes, required this.fallbackCategory});

  final List<VehicleMakeOption> makes;
  final String fallbackCategory;

  factory VehicleCatalogue.fromJson(Map<String, dynamic> json) {
    final rawMakes = json['makes'];
    return VehicleCatalogue(
      makes: rawMakes is List
          ? rawMakes
                .whereType<Map<String, dynamic>>()
                .map(VehicleMakeOption.fromJson)
                .where((make) => make.name.isNotEmpty)
                .toList(growable: false)
          : const [],
      fallbackCategory: json['fallback_category']?.toString() ?? 'other',
    );
  }
}

class AddedVehicleResult {
  const AddedVehicleResult({required this.id, this.stolenMatch});

  final String id;
  final Map<String, dynamic>? stolenMatch;
}
