/// The vehicle a stolen report is about (subset carried on the report).
class StolenVehicleRef {
  const StolenVehicleRef({
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plateNumber,
    required this.images,
  });

  final String make;
  final String model;
  final int? year;
  final String? color;
  final String? plateNumber;
  final List<String> images;

  String get name => [make, model].where((s) => s.trim().isNotEmpty).join(' ');

  factory StolenVehicleRef.fromJson(Map<String, dynamic> json) {
    final images = json['images'];
    return StolenVehicleRef(
      make: json['make']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      year: json['year'] is num ? (json['year'] as num).toInt() : null,
      color: json['color']?.toString(),
      plateNumber: json['plate_number']?.toString(),
      images: images is List
          ? images.map((e) => e.toString()).toList(growable: false)
          : const [],
    );
  }
}

class VehicleSighting {
  const VehicleSighting({
    required this.id,
    required this.sightingDate,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.driverDescription,
    required this.vehicleState,
    required this.directionOfTravel,
    required this.photos,
    required this.isVerified,
    required this.moderationStatus,
    required this.submittedAnonymously,
    required this.reporterName,
    required this.createdAt,
    required this.dismissedAt,
  });

  final String id;
  final String? sightingDate;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? description;
  final String? driverDescription;
  final String? vehicleState;
  final String? directionOfTravel;
  final List<String> photos;
  final bool isVerified;
  final String? moderationStatus;
  final bool submittedAnonymously;
  final String? reporterName;
  final String? createdAt;
  final String? dismissedAt;

  bool get isDismissed => dismissedAt != null;

  factory VehicleSighting.fromJson(Map<String, dynamic> json) {
    final photos = json['photos'];
    final reporter = json['reporter'];
    return VehicleSighting(
      id: json['id']?.toString() ?? '',
      sightingDate: json['sighting_date']?.toString(),
      location: json['location']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      description: json['description']?.toString(),
      driverDescription: json['driver_description']?.toString(),
      vehicleState: json['vehicle_state']?.toString(),
      directionOfTravel: json['direction_of_travel']?.toString(),
      photos: photos is List
          ? photos.map((e) => e.toString()).toList(growable: false)
          : const [],
      isVerified: json['is_verified'] == true,
      moderationStatus: json['moderation_status']?.toString(),
      submittedAnonymously: json['submitted_anonymously'] == true,
      reporterName: reporter is Map ? reporter['name']?.toString() : null,
      createdAt: json['created_at']?.toString(),
      dismissedAt: json['dismissed_at']?.toString(),
    );
  }
}

class StolenReport {
  const StolenReport({
    required this.id,
    required this.isMine,
    required this.status,
    required this.statusLabel,
    required this.dateReported,
    required this.theftOccurredAt,
    required this.dateRecovered,
    required this.description,
    required this.policeReportNumber,
    required this.lastKnownLocation,
    required this.latitude,
    required this.longitude,
    required this.rewardNaira,
    required this.isPublic,
    required this.contactInfo,
    required this.sightingsCount,
    required this.vehicle,
    required this.reporterName,
    required this.sightings,
  });

  final String id;
  final bool isMine;
  final String status;
  final String statusLabel;
  final String? dateReported;
  final String? theftOccurredAt;
  final String? dateRecovered;
  final String? description;
  final String? policeReportNumber;
  final String? lastKnownLocation;
  final double? latitude;
  final double? longitude;
  final String? rewardNaira;
  final bool isPublic;
  final String? contactInfo;
  final int? sightingsCount;
  final StolenVehicleRef? vehicle;
  final String? reporterName;
  final List<VehicleSighting> sightings;

  bool get isStolen => status == 'STOLEN';

  factory StolenReport.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'];
    final sightings = json['sightings'];
    final reporter = json['reporter'];
    return StolenReport(
      id: json['id']?.toString() ?? '',
      isMine: json['is_mine'] == true,
      status: json['status']?.toString() ?? 'STOLEN',
      statusLabel: json['status_label']?.toString() ?? 'Stolen',
      dateReported: json['date_reported']?.toString(),
      theftOccurredAt: json['theft_occurred_at']?.toString(),
      dateRecovered: json['date_recovered']?.toString(),
      description: json['description']?.toString(),
      policeReportNumber: json['police_report_number']?.toString(),
      lastKnownLocation: json['last_known_location']?.toString(),
      latitude: (json['last_known_latitude'] as num?)?.toDouble(),
      longitude: (json['last_known_longitude'] as num?)?.toDouble(),
      rewardNaira: json['reward_naira']?.toString(),
      isPublic: json['is_public'] == true,
      contactInfo: json['contact_info']?.toString(),
      sightingsCount: json['sightings_count'] is num
          ? (json['sightings_count'] as num).toInt()
          : null,
      vehicle: vehicle is Map
          ? StolenVehicleRef.fromJson(vehicle.cast<String, dynamic>())
          : null,
      reporterName: reporter is Map ? reporter['name']?.toString() : null,
      sightings: sightings is List
          ? sightings
                .whereType<Map>()
                .map((e) => VehicleSighting.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
    );
  }
}

/// Result of a public plate check.
class StolenCheckResult {
  const StolenCheckResult({
    required this.plate,
    required this.isStolen,
    required this.report,
  });

  final String plate;
  final bool isStolen;
  final StolenReport? report;

  factory StolenCheckResult.fromJson(Map<String, dynamic> json) {
    final report = json['report'];
    return StolenCheckResult(
      plate: json['plate']?.toString() ?? '',
      isStolen: json['is_stolen'] == true,
      report: report is Map
          ? StolenReport.fromJson(report.cast<String, dynamic>())
          : null,
    );
  }
}

/// Vehicle-state options for a sighting.
const sightingStateOptions = <({String value, String label})>[
  (value: 'MOVING', label: 'Moving'),
  (value: 'PARKED', label: 'Parked'),
  (value: 'ABANDONED', label: 'Abandoned'),
  (value: 'BEING_TOWED', label: 'Being towed'),
  (value: 'UNKNOWN', label: 'Not sure'),
];
