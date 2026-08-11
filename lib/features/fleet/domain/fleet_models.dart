class FleetOrgRef {
  const FleetOrgRef({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.roleLabel,
    required this.isOwner,
  });

  final String id;
  final String? name;
  final String? registrationNumber;
  final String? roleLabel;
  final bool isOwner;

  factory FleetOrgRef.fromJson(Map<String, dynamic> json) {
    return FleetOrgRef(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      registrationNumber: json['registration_number']?.toString(),
      roleLabel: json['role_label']?.toString(),
      isOwner: json['is_owner'] == true,
    );
  }
}

class FleetInvite {
  const FleetInvite({required this.id, required this.name, required this.roleLabel});

  final String id;
  final String? name;
  final String? roleLabel;

  factory FleetInvite.fromJson(Map<String, dynamic> json) {
    return FleetInvite(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      roleLabel: json['role_label']?.toString(),
    );
  }
}

class FleetHome {
  const FleetHome({required this.organisations, required this.invites});

  final List<FleetOrgRef> organisations;
  final List<FleetInvite> invites;

  factory FleetHome.fromJson(Map<String, dynamic> json) {
    List<T> mapList<T>(Object? raw, T Function(Map<String, dynamic>) fn) =>
        (raw is List ? raw : const [])
            .whereType<Map>()
            .map((e) => fn(e.cast<String, dynamic>()))
            .toList(growable: false);
    return FleetHome(
      organisations: mapList(json['organisations'], FleetOrgRef.fromJson),
      invites: mapList(json['invites'], FleetInvite.fromJson),
    );
  }
}

class FleetKpis {
  const FleetKpis({
    required this.healthScore,
    required this.healthLabel,
    required this.totalVehicles,
    required this.compliantVehicles,
    required this.attentionVehicles,
    required this.trackedVehicles,
    required this.liveVehicles,
    required this.activeMembers,
    required this.pendingInvites,
    required this.fuelBalanceNaira,
    required this.availableFuelNaira,
  });

  final int healthScore;
  final String? healthLabel;
  final int totalVehicles;
  final int compliantVehicles;
  final int attentionVehicles;
  final int trackedVehicles;
  final int liveVehicles;
  final int activeMembers;
  final int pendingInvites;
  final String fuelBalanceNaira;
  final String availableFuelNaira;

  factory FleetKpis.fromJson(Map<String, dynamic> json) {
    final health = json['health'];
    final kpis = json['kpis'];
    int i(Object? m, String k) => (m is Map && m[k] is num) ? (m[k] as num).toInt() : 0;
    String s(Object? m, String k) => (m is Map ? m[k]?.toString() : null) ?? '0.00';
    return FleetKpis(
      healthScore: i(health, 'score'),
      healthLabel: health is Map ? health['label']?.toString() : null,
      totalVehicles: i(kpis, 'total_vehicles'),
      compliantVehicles: i(kpis, 'compliant_vehicles'),
      attentionVehicles: i(kpis, 'attention_vehicles'),
      trackedVehicles: i(kpis, 'tracked_vehicles'),
      liveVehicles: i(kpis, 'live_vehicles'),
      activeMembers: i(kpis, 'active_members'),
      pendingInvites: i(kpis, 'pending_invites'),
      fuelBalanceNaira: s(kpis, 'fuel_balance_naira'),
      availableFuelNaira: s(kpis, 'available_fuel_naira'),
    );
  }
}

class OrgMember {
  const OrgMember({
    required this.id,
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.status,
    required this.seesAllRegions,
  });

  final String id;
  final String? name;
  final String? email;
  final String? roleLabel;
  final String? status;
  final bool seesAllRegions;

  factory OrgMember.fromJson(Map<String, dynamic> json) {
    return OrgMember(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      roleLabel: json['role_label']?.toString(),
      status: json['status']?.toString(),
      seesAllRegions: json['sees_all_regions'] == true,
    );
  }
}

class OrgVehicle {
  const OrgVehicle({
    required this.id,
    required this.name,
    required this.plateNumber,
    required this.imageUrl,
    required this.regionName,
    required this.driverName,
    required this.complianceStatus,
    required this.complianceLabel,
    required this.hasTracker,
  });

  final String id;
  final String name;
  final String? plateNumber;
  final String? imageUrl;
  final String? regionName;
  final String? driverName;
  final String? complianceStatus;
  final String? complianceLabel;
  final bool hasTracker;

  factory OrgVehicle.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'];
    final v = vehicle is Map ? vehicle : const {};
    final region = json['region'];
    final driver = json['driver'];
    final name = [v['make']?.toString() ?? '', v['model']?.toString() ?? '']
        .where((s) => s.isNotEmpty)
        .join(' ');
    return OrgVehicle(
      id: json['id']?.toString() ?? '',
      name: name.isEmpty ? 'Vehicle' : name,
      plateNumber: v['plate_number']?.toString(),
      imageUrl: v['image_url']?.toString(),
      regionName: region is Map ? region['name']?.toString() : null,
      driverName: driver is Map ? driver['full_name']?.toString() : null,
      complianceStatus: json['compliance_status']?.toString(),
      complianceLabel: json['compliance_label']?.toString(),
      hasTracker: json['has_tracker'] == true,
    );
  }
}

class FleetOrgDetail {
  const FleetOrgDetail({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.myRoleLabel,
    required this.fuelBalanceNaira,
    required this.fuelAvailableNaira,
    required this.members,
    required this.vehicles,
    required this.regionCount,
  });

  final String id;
  final String? name;
  final String? registrationNumber;
  final String? myRoleLabel;
  final String fuelBalanceNaira;
  final String fuelAvailableNaira;
  final List<OrgMember> members;
  final List<OrgVehicle> vehicles;
  final int regionCount;

  factory FleetOrgDetail.fromJson(Map<String, dynamic> json) {
    final fuel = json['fuel'];
    final regions = json['regions'];
    List<T> mapList<T>(Object? raw, T Function(Map<String, dynamic>) fn) =>
        (raw is List ? raw : const [])
            .whereType<Map>()
            .map((e) => fn(e.cast<String, dynamic>()))
            .toList(growable: false);
    return FleetOrgDetail(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      registrationNumber: json['registration_number']?.toString(),
      myRoleLabel: json['my_role_label']?.toString(),
      fuelBalanceNaira: fuel is Map ? (fuel['balance_naira']?.toString() ?? '0.00') : '0.00',
      fuelAvailableNaira: fuel is Map ? (fuel['available_naira']?.toString() ?? '0.00') : '0.00',
      members: mapList(json['members'], OrgMember.fromJson),
      vehicles: mapList(json['vehicles'], OrgVehicle.fromJson),
      regionCount: regions is List ? regions.length : 0,
    );
  }
}
