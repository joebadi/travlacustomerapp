class LatLngPoint {
  const LatLngPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

class Journey {
  const Journey({
    required this.id,
    required this.title,
    required this.description,
    required this.transportMode,
    required this.transportModeLabel,
    required this.distanceKm,
    required this.durationS,
    required this.pointCount,
    required this.recordedAt,
    required this.createdAt,
    required this.vehiclePlate,
    required this.trail,
  });

  final String id;
  final String title;
  final String? description;
  final String? transportMode;
  final String? transportModeLabel;
  final double distanceKm;
  final int durationS;
  final int pointCount;
  final String? recordedAt;
  final String? createdAt;
  final String? vehiclePlate;
  final List<LatLngPoint> trail;

  String get durationLabel {
    final h = durationS ~/ 3600;
    final m = (durationS % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${durationS}s';
  }

  factory Journey.fromJson(Map<String, dynamic> json) {
    final points = json['points'];
    return Journey(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Journey',
      description: json['description']?.toString(),
      transportMode: json['transport_mode']?.toString(),
      transportModeLabel: json['transport_mode_label']?.toString(),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationS: (json['duration_s'] as num?)?.toInt() ?? 0,
      pointCount: (json['point_count'] as num?)?.toInt() ?? 0,
      recordedAt: json['recorded_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      vehiclePlate: json['vehicle'] is Map ? (json['vehicle'] as Map)['plate_number']?.toString() : null,
      trail: points is List
          ? points
              .whereType<Map>()
              .map((p) => LatLngPoint((p['lat'] as num?)?.toDouble() ?? 0, (p['lng'] as num?)?.toDouble() ?? 0))
              .toList(growable: false)
          : const [],
    );
  }
}

class RoadReportType {
  const RoadReportType({
    required this.value,
    required this.label,
    required this.category,
    required this.isDirectional,
  });

  final String value;
  final String label;
  final String? category;
  final bool isDirectional;

  factory RoadReportType.fromJson(Map<String, dynamic> json) {
    return RoadReportType(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      category: json['category']?.toString(),
      isDirectional: json['is_directional'] == true,
    );
  }
}

class NearbyRoadReport {
  const NearbyRoadReport({
    required this.id,
    required this.typeLabel,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  final String id;
  final String typeLabel;
  final double latitude;
  final double longitude;
  final String? description;

  factory NearbyRoadReport.fromJson(Map<String, dynamic> json) {
    return NearbyRoadReport(
      id: json['id']?.toString() ?? '',
      typeLabel: json['type_label']?.toString() ?? json['type']?.toString() ?? 'Report',
      latitude: (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? (json['lng'] as num?)?.toDouble() ?? 0,
      description: json['description']?.toString(),
    );
  }
}

const transportModeOptions = <({String value, String label})>[
  (value: 'DRIVING', label: 'Driving'),
  (value: 'BUS', label: 'Bus'),
  (value: 'MOTORCYCLE', label: 'Motorcycle'),
  (value: 'WALKING', label: 'Walking'),
  (value: 'OTHER', label: 'Other'),
];
