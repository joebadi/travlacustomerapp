/// The latest known position of one of the user's vehicles, from
/// `GET /tracking/live` — one entry per vehicle that has ever reported.
class LivePosition {
  const LivePosition({
    required this.vehicleId,
    required this.name,
    required this.plateNumber,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    required this.sourceLabel,
    required this.lastPositionAt,
  });

  final String vehicleId;
  final String name;
  final String? plateNumber;
  final double latitude;
  final double longitude;
  final double? speed;
  final double? heading;
  final String? sourceLabel;
  final DateTime? lastPositionAt;

  String get displayName => name.trim().isEmpty ? 'Vehicle' : name.trim();

  factory LivePosition.fromJson(Map<String, dynamic> json) {
    return LivePosition(
      vehicleId: json['vehicle_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      sourceLabel: json['source_label']?.toString(),
      lastPositionAt: DateTime.tryParse(json['last_position_at']?.toString() ?? ''),
    );
  }
}
