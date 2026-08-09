class VehicleTrackerSource {
  const VehicleTrackerSource({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.label,
    required this.isActive,
    required this.isPush,
    required this.apiKeyLast4,
    required this.uniqueId,
    required this.lastLatitude,
    required this.lastLongitude,
    required this.lastSpeed,
    required this.lastPositionAt,
  });

  final String id;
  final String type;
  final String typeLabel;
  final String? label;
  final bool isActive;
  final bool isPush;
  final String? apiKeyLast4;
  final String? uniqueId;
  final double? lastLatitude;
  final double? lastLongitude;
  final double? lastSpeed;
  final DateTime? lastPositionAt;

  String get displayLabel =>
      label?.trim().isNotEmpty == true ? label! : typeLabel;
  bool get hasPosition => lastLatitude != null && lastLongitude != null;

  factory VehicleTrackerSource.fromJson(Map<String, dynamic> json) {
    return VehicleTrackerSource(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      typeLabel: json['type_label']?.toString() ?? 'Tracking source',
      label: json['label']?.toString(),
      isActive: json['is_active'] == true,
      isPush: json['is_push'] == true,
      apiKeyLast4: json['api_key_last4']?.toString(),
      uniqueId: json['unique_id']?.toString(),
      lastLatitude: (json['last_latitude'] as num?)?.toDouble(),
      lastLongitude: (json['last_longitude'] as num?)?.toDouble(),
      lastSpeed: (json['last_speed'] as num?)?.toDouble(),
      lastPositionAt: DateTime.tryParse(
        json['last_position_at']?.toString() ?? '',
      ),
    );
  }
}

class VehicleTrailPoint {
  const VehicleTrailPoint({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final double? speed;
  final DateTime? recordedAt;

  factory VehicleTrailPoint.fromJson(Map<String, dynamic> json) {
    return VehicleTrailPoint(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble(),
      recordedAt: DateTime.tryParse(json['recorded_at']?.toString() ?? ''),
    );
  }
}

class VehicleTrackingWorkspace {
  const VehicleTrackingWorkspace({
    required this.sources,
    required this.latest,
    required this.trail,
  });

  final List<VehicleTrackerSource> sources;
  final VehicleTrackerSource? latest;
  final List<VehicleTrailPoint> trail;

  bool get hasActiveSource => sources.any((source) => source.isActive);

  factory VehicleTrackingWorkspace.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    final rawLatest = json['latest'];
    final rawTrail = json['trail'];
    return VehicleTrackingWorkspace(
      sources: rawSources is List
          ? rawSources
                .whereType<Map<String, dynamic>>()
                .map(VehicleTrackerSource.fromJson)
                .where((source) => source.id.isNotEmpty)
                .toList(growable: false)
          : const [],
      latest: rawLatest is Map<String, dynamic>
          ? VehicleTrackerSource.fromJson(rawLatest)
          : null,
      trail: rawTrail is List
          ? rawTrail
                .whereType<Map<String, dynamic>>()
                .map(VehicleTrailPoint.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class CreatedTrackerSource {
  const CreatedTrackerSource({required this.source, required this.apiKey});

  final VehicleTrackerSource source;
  final String? apiKey;
}
