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
    required this.matchedTrail,
    required this.isMatched,
    required this.isMine,
    required this.visibility,
    required this.shareToken,
    required this.shareExpiresAt,
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

  /// Road-snapped path from OSRM map-matching, when available. Prefer this
  /// over [trail] for display so driving journeys follow real roads.
  final List<LatLngPoint> matchedTrail;
  final bool isMatched;

  /// True when the signed-in user owns this journey (owner sees full trace +
  /// share/delete controls; others get a trimmed, read-only view).
  final bool isMine;
  final String visibility; // PRIVATE | LINK | ORGANISATION | PUBLIC
  final String? shareToken; // present only for the owner of a shared journey
  final String? shareExpiresAt;

  bool get isShared => visibility == 'LINK' || visibility == 'PUBLIC' || visibility == 'ORGANISATION';

  /// The shareable link for this journey (opens the journey in Travla).
  String? get shareUrl =>
      isShared ? 'https://travla.com.ng/journeys/$id' : null;

  /// The best path to draw: the road-snapped one when present, else the raw
  /// recorded trail.
  List<LatLngPoint> get displayTrail =>
      matchedTrail.length >= 2 ? matchedTrail : trail;

  String get durationLabel {
    final h = durationS ~/ 3600;
    final m = (durationS % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${durationS}s';
  }

  static List<LatLngPoint> _pairs(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<List>()
        .where((e) => e.length >= 2)
        .map((e) => LatLngPoint((e[0] as num).toDouble(), (e[1] as num).toDouble()))
        .toList(growable: false);
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
      matchedTrail: _pairs(json['matched_path']),
      isMatched: json['is_matched'] == true,
      isMine: json['is_mine'] != false, // absent (older payloads) ⇒ treat as mine
      visibility: json['visibility']?.toString() ?? 'PRIVATE',
      shareToken: json['share_token']?.toString(),
      shareExpiresAt: json['share_expires_at']?.toString(),
    );
  }
}

/// `GET /journeys/{id}/health` — how stale a saved route is and how many
/// active road reports now sit along it, so we can prompt a review before
/// following.
class JourneyHealth {
  const JourneyHealth({
    required this.ageDays,
    required this.reportsAlongTrail,
    required this.recordedAt,
  });

  final int? ageDays;
  final int reportsAlongTrail;
  final String? recordedAt;

  bool get isStale => (ageDays ?? 0) >= 90;
  bool get hasChanges => reportsAlongTrail > 0;

  /// A short human summary like "Recorded 3 months ago · 2 road changes along
  /// this route", or null when there's nothing worth flagging.
  String? get summary {
    final parts = <String>[];
    final age = ageDays;
    if (age != null) {
      if (age < 1) {
        parts.add('Recorded today');
      } else if (age < 30) {
        parts.add('Recorded ${age}d ago');
      } else if (age < 365) {
        parts.add('Recorded ${(age / 30).round()} month${age < 60 ? '' : 's'} ago');
      } else {
        parts.add('Recorded ${(age / 365).round()} year${age < 730 ? '' : 's'} ago');
      }
    }
    if (reportsAlongTrail > 0) {
      parts.add('$reportsAlongTrail road change${reportsAlongTrail == 1 ? '' : 's'} along this route');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  factory JourneyHealth.fromJson(Map<String, dynamic> json) {
    return JourneyHealth(
      ageDays: (json['age_days'] as num?)?.toInt(),
      reportsAlongTrail: (json['reports_along_trail'] as num?)?.toInt() ?? 0,
      recordedAt: json['recorded_at']?.toString(),
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

class ReportMedia {
  const ReportMedia({required this.kind, required this.url, this.mime});

  final String kind; // PHOTO | AUDIO | VIDEO
  final String url;
  final String? mime;

  bool get isPhoto => kind == 'PHOTO';
  bool get isAudio => kind == 'AUDIO';
  bool get isVideo => kind == 'VIDEO';

  factory ReportMedia.fromJson(Map<String, dynamic> json) {
    return ReportMedia(
      kind: json['kind']?.toString() ?? 'PHOTO',
      url: json['url']?.toString() ?? '',
      mime: json['mime']?.toString(),
    );
  }
}

class NearbyRoadReport {
  const NearbyRoadReport({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.category,
    required this.isDirectional,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.verificationLabel,
    required this.media,
  });

  final String id;
  final String type;
  final String typeLabel;
  final String? category;

  /// Directional restrictions (one-way, no-entry, …) are shown as advisory
  /// markers only — v1 never fires an automatic wrong-way alert for them.
  final bool isDirectional;
  final double latitude;
  final double longitude;
  final String? description;
  final String? verificationLabel;
  final List<ReportMedia> media;

  bool get hasMedia => media.isNotEmpty;

  factory NearbyRoadReport.fromJson(Map<String, dynamic> json) {
    final media = json['media'];
    return NearbyRoadReport(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      typeLabel: json['type_label']?.toString() ?? json['type']?.toString() ?? 'Report',
      category: json['category']?.toString(),
      isDirectional: json['is_directional'] == true,
      latitude: (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? (json['lng'] as num?)?.toDouble() ?? 0,
      description: json['description']?.toString(),
      verificationLabel: json['verification_label']?.toString(),
      media: media is List
          ? media
              .whereType<Map>()
              .map((m) => ReportMedia.fromJson(m.cast<String, dynamic>()))
              .toList(growable: false)
          : const [],
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
