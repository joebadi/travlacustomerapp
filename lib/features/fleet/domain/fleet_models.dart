class FleetCapabilities {
  const FleetCapabilities({
    this.manageOrg = false,
    this.manageMembers = false,
    this.manageRegions = false,
    this.manageVehicles = false,
    this.manageDrivers = false,
    this.viewTracking = false,
    this.viewFuelFinancials = false,
    this.fundFleet = false,
    this.manageFuelSettings = false,
    this.manageFuelCards = false,
    this.manageVehicleAllocations = false,
    this.viewAudit = false,
    this.seesAllRegions = false,
  });

  final bool manageOrg;
  final bool manageMembers;
  final bool manageRegions;
  final bool manageVehicles;
  final bool manageDrivers;
  final bool viewTracking;
  final bool viewFuelFinancials;
  final bool fundFleet;
  final bool manageFuelSettings;
  final bool manageFuelCards;
  final bool manageVehicleAllocations;
  final bool viewAudit;
  final bool seesAllRegions;

  factory FleetCapabilities.fromJson(Object? raw) {
    final json = raw is Map ? raw : const <String, dynamic>{};
    bool flag(String key) => json[key] == true;
    return FleetCapabilities(
      manageOrg: flag('manage_org'),
      manageMembers: flag('manage_members'),
      manageRegions: flag('manage_regions'),
      manageVehicles: flag('manage_vehicles'),
      manageDrivers: flag('manage_drivers'),
      viewTracking: flag('view_tracking'),
      viewFuelFinancials: flag('view_fuel_financials'),
      fundFleet: flag('fund_fleet'),
      manageFuelSettings: flag('manage_fuel_settings'),
      manageFuelCards: flag('manage_fuel_cards'),
      manageVehicleAllocations: flag('manage_vehicle_allocations'),
      viewAudit: flag('view_audit'),
      seesAllRegions: flag('sees_all_regions'),
    );
  }
}

class FleetScope {
  const FleetScope({
    required this.label,
    required this.seesAllRegions,
    required this.regionIds,
  });

  final String label;
  final bool seesAllRegions;
  final List<String> regionIds;

  factory FleetScope.fromJson(Object? raw) {
    final json = raw is Map ? raw : const <String, dynamic>{};
    return FleetScope(
      label: json['label']?.toString() ?? 'Assigned regions',
      seesAllRegions: json['sees_all_regions'] == true,
      regionIds:
          (json['region_ids'] is List ? json['region_ids'] as List : const [])
              .map((id) => id.toString())
              .toList(growable: false),
    );
  }
}

class FleetOrgRef {
  const FleetOrgRef({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.registrationVerificationStatus,
    required this.role,
    required this.roleLabel,
    required this.isOwner,
  });

  final String id;
  final String? name;
  final String? registrationNumber;
  final String registrationVerificationStatus;
  final String? role;
  final String? roleLabel;
  final bool isOwner;

  factory FleetOrgRef.fromJson(Map<String, dynamic> json) {
    return FleetOrgRef(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      registrationNumber: json['registration_number']?.toString(),
      registrationVerificationStatus:
          json['registration_verification_status']?.toString() ??
          'NOT_PROVIDED',
      role: json['role']?.toString(),
      roleLabel: json['role_label']?.toString(),
      isOwner: json['is_owner'] == true,
    );
  }
}

class FleetInvite {
  const FleetInvite({
    required this.id,
    required this.name,
    required this.role,
    required this.roleLabel,
  });

  final String id;
  final String? name;
  final String? role;
  final String? roleLabel;

  factory FleetInvite.fromJson(Map<String, dynamic> json) {
    return FleetInvite(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      role: json['role']?.toString(),
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
    required this.organisationId,
    required this.capabilities,
    required this.scope,
    required this.totalVehicles,
    required this.compliantVehicles,
    required this.attentionVehicles,
    required this.trackedVehicles,
    required this.liveVehicles,
    required this.activeMembers,
    required this.pendingInvites,
    required this.fuelBalanceNaira,
    required this.availableFuelNaira,
    required this.alerts,
    required this.renewalPlanning,
  });

  final String organisationId;
  final FleetCapabilities capabilities;
  final FleetScope scope;
  final int healthScore;
  final String? healthLabel;
  final int totalVehicles;
  final int compliantVehicles;
  final int attentionVehicles;
  final int trackedVehicles;
  final int liveVehicles;
  final int activeMembers;
  final int pendingInvites;
  final String? fuelBalanceNaira;
  final String? availableFuelNaira;
  final List<FleetAlert> alerts;
  final FleetRenewalPlanning renewalPlanning;

  factory FleetKpis.fromJson(Map<String, dynamic> json) {
    final health = json['health'];
    final kpis = json['kpis'];
    final organisation = json['organisation'];
    final organisationId = organisation is Map
        ? organisation['id']?.toString() ?? ''
        : '';
    int i(Object? m, String k) =>
        (m is Map && m[k] is num) ? (m[k] as num).toInt() : 0;
    String? s(Object? m, String k) => m is Map ? m[k]?.toString() : null;
    List<T> mapList<T>(Object? raw, T Function(Map<String, dynamic>) fn) =>
        (raw is List ? raw : const [])
            .whereType<Map>()
            .map((entry) => fn(entry.cast<String, dynamic>()))
            .toList(growable: false);
    return FleetKpis(
      organisationId: organisationId,
      capabilities: FleetCapabilities.fromJson(json['capabilities']),
      scope: FleetScope.fromJson(json['scope']),
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
      alerts: mapList(json['alerts'], FleetAlert.fromJson)
          .where((alert) => alert.organisationId == organisationId)
          .toList(growable: false),
      renewalPlanning: FleetRenewalPlanning.fromJson(json['renewal_planning']),
    );
  }
}

class FleetRenewalPlanning {
  const FleetRenewalPlanning({
    required this.totalPapers,
    required this.expiringSoon,
    required this.expired,
    required this.inProgress,
    required this.due30Days,
    required this.due90Days,
    required this.due30CostNaira,
    required this.due90CostNaira,
    required this.walletBalanceNaira,
    required this.shortfallNaira,
    required this.sufficientBalance,
    required this.otherOwnerDueCount,
    required this.schedule,
  });

  final int totalPapers;
  final int expiringSoon;
  final int expired;
  final int inProgress;
  final int due30Days;
  final int due90Days;
  final String due30CostNaira;
  final String due90CostNaira;
  final String walletBalanceNaira;
  final String shortfallNaira;
  final bool sufficientBalance;
  final int otherOwnerDueCount;
  final List<FleetRenewalItem> schedule;

  factory FleetRenewalPlanning.fromJson(Object? raw) {
    final json = raw is Map ? raw : const <String, dynamic>{};
    final summaryRaw = json['summary'];
    final fundingRaw = json['funding'];
    final summary = summaryRaw is Map ? summaryRaw : const {};
    final funding = fundingRaw is Map ? fundingRaw : const {};
    int integer(Map map, String key) => (map[key] as num?)?.toInt() ?? 0;

    return FleetRenewalPlanning(
      totalPapers: integer(summary, 'total_papers'),
      expiringSoon: integer(summary, 'expiring_soon'),
      expired: integer(summary, 'expired'),
      inProgress: integer(summary, 'renewal_in_progress'),
      due30Days: integer(summary, 'due_30_days'),
      due90Days: integer(summary, 'due_90_days'),
      due30CostNaira: summary['due_30_cost_naira']?.toString() ?? '0.00',
      due90CostNaira: summary['due_90_cost_naira']?.toString() ?? '0.00',
      walletBalanceNaira: funding['wallet_balance_naira']?.toString() ?? '0.00',
      shortfallNaira: funding['shortfall_naira']?.toString() ?? '0.00',
      sufficientBalance: funding['sufficient_balance'] == true,
      otherOwnerDueCount: integer(funding, 'other_owner_due_count'),
      schedule: (json['schedule'] is List ? json['schedule'] as List : const [])
          .whereType<Map>()
          .map(
            (item) => FleetRenewalItem.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

class FleetRenewalItem {
  const FleetRenewalItem({
    required this.documentId,
    required this.documentTypeId,
    required this.documentType,
    required this.orgVehicleId,
    required this.vehicleId,
    required this.plateNumber,
    required this.vehicleLabel,
    required this.documentName,
    required this.region,
    required this.status,
    required this.statusLabel,
    required this.expiryDate,
    required this.daysUntilExpiry,
    required this.ownerIsActor,
    required this.renewalAccess,
    required this.estimatedCostNaira,
  });

  final String documentId;
  final String documentTypeId;
  final String documentType;
  final String orgVehicleId;
  final String vehicleId;
  final String? plateNumber;
  final String vehicleLabel;
  final String documentName;
  final String? region;
  final String status;
  final String statusLabel;
  final String? expiryDate;
  final int? daysUntilExpiry;
  final bool ownerIsActor;
  final String renewalAccess;
  final String estimatedCostNaira;

  bool get canRenewDirectly => renewalAccess == 'DIRECT';
  bool get ownerActionRequired => renewalAccess == 'OWNER_REQUIRED';

  factory FleetRenewalItem.fromJson(Map<String, dynamic> json) {
    return FleetRenewalItem(
      documentId: json['document_id']?.toString() ?? '',
      documentTypeId: json['document_type_id']?.toString() ?? '',
      documentType: json['document_type']?.toString() ?? '',
      orgVehicleId: json['org_vehicle_id']?.toString() ?? '',
      vehicleId: json['vehicle_id']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString(),
      vehicleLabel: json['vehicle_label']?.toString() ?? 'Vehicle',
      documentName: json['document_name']?.toString() ?? 'Vehicle paper',
      region: json['region']?.toString(),
      status: json['status']?.toString() ?? 'UNKNOWN',
      statusLabel: json['status_label']?.toString() ?? 'Unknown',
      expiryDate: json['expiry_date']?.toString(),
      daysUntilExpiry: (json['days_until_expiry'] as num?)?.toInt(),
      ownerIsActor: json['owner_is_actor'] == true,
      renewalAccess: json['renewal_access']?.toString() ?? 'RESTRICTED',
      estimatedCostNaira: json['estimated_cost_naira']?.toString() ?? '0.00',
    );
  }
}

class FleetAlert {
  const FleetAlert({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.description,
    required this.count,
    required this.organisationId,
    required this.actionType,
    required this.actionParameters,
    required this.legacyActionUrl,
  });

  final String id;
  final String kind;
  final String severity;
  final String title;
  final String description;
  final int count;
  final String organisationId;
  final String actionType;
  final Map<String, String> actionParameters;
  final String? legacyActionUrl;

  bool get isCritical => severity == 'CRITICAL';

  factory FleetAlert.fromJson(Map<String, dynamic> json) {
    final action = json['action'];
    final parameters = action is Map ? action['parameters'] : null;
    return FleetAlert(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'UNKNOWN',
      severity: json['severity']?.toString() ?? 'INFO',
      title: json['title']?.toString() ?? 'Fleet action',
      description: json['description']?.toString() ?? '',
      count: json['count'] is num ? (json['count'] as num).toInt() : 0,
      organisationId: json['organisation_id']?.toString() ?? '',
      actionType: action is Map ? action['type']?.toString() ?? '' : '',
      actionParameters: parameters is Map
          ? parameters.map((key, value) => MapEntry('$key', '$value'))
          : const {},
      legacyActionUrl: json['action_url']?.toString(),
    );
  }
}

class OrgMember {
  const OrgMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roleLabel,
    required this.status,
    required this.seesAllRegions,
    required this.regionIds,
  });

  final String id;
  final String? name;
  final String? email;
  final String? role;
  final String? roleLabel;
  final String? status;
  final bool seesAllRegions;
  final List<String> regionIds;

  factory OrgMember.fromJson(Map<String, dynamic> json) {
    return OrgMember(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString(),
      roleLabel: json['role_label']?.toString(),
      status: json['status']?.toString(),
      seesAllRegions: json['sees_all_regions'] == true,
      regionIds:
          (json['region_ids'] is List ? json['region_ids'] as List : const [])
              .map((id) => id.toString())
              .toList(growable: false),
    );
  }
}

class OrgVehicle {
  const OrgVehicle({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.plateNumber,
    required this.year,
    required this.color,
    required this.imageUrl,
    required this.canOpen,
    required this.regionId,
    required this.regionName,
    required this.department,
    required this.driverId,
    required this.driverName,
    required this.complianceStatus,
    required this.complianceLabel,
    required this.missingRequiredDocumentsCount,
    required this.missingRequiredDocuments,
    required this.renewableDocumentsCount,
    required this.expiredDocumentsCount,
    required this.expiringSoonCount,
    required this.nextExpiryDate,
    required this.documentAccess,
    required this.renewalAccess,
    required this.documents,
    required this.hasTracker,
    required this.isLive,
    required this.lastPositionAt,
    required this.cardNumber,
    required this.cardLastFour,
    required this.cardStatus,
    required this.allocationBalanceNaira,
    required this.allocationNaira,
  });

  final String id;
  final String? vehicleId;
  final String name;
  final String? plateNumber;
  final int? year;
  final String? color;
  final String? imageUrl;
  final bool canOpen;
  final String? regionId;
  final String? regionName;
  final String? department;
  final String? driverId;
  final String? driverName;
  final String? complianceStatus;
  final String? complianceLabel;
  final int missingRequiredDocumentsCount;
  final List<String> missingRequiredDocuments;
  final int renewableDocumentsCount;
  final int expiredDocumentsCount;
  final int expiringSoonCount;
  final String? nextExpiryDate;
  final bool documentAccess;
  final bool renewalAccess;
  final List<FleetVehicleDocument> documents;
  final bool hasTracker;
  final bool isLive;
  final String? lastPositionAt;
  final String? cardNumber;
  final String? cardLastFour;
  final String? cardStatus;
  final String? allocationBalanceNaira;
  final String? allocationNaira;

  factory OrgVehicle.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'];
    final v = vehicle is Map ? vehicle : const {};
    final region = json['region'];
    final driver = json['driver'];
    final name = [
      v['make']?.toString() ?? '',
      v['model']?.toString() ?? '',
    ].where((s) => s.isNotEmpty).join(' ');
    return OrgVehicle(
      id: json['id']?.toString() ?? '',
      vehicleId: v['id']?.toString(),
      name: name.isEmpty ? 'Vehicle' : name,
      plateNumber: v['plate_number']?.toString(),
      year: v['year'] is num ? (v['year'] as num).toInt() : null,
      color: v['color']?.toString(),
      imageUrl: v['image_url']?.toString(),
      canOpen: v['can_open'] == true,
      regionId: region is Map ? region['id']?.toString() : null,
      regionName: region is Map ? region['name']?.toString() : null,
      department: json['department']?.toString(),
      driverId: driver is Map ? driver['id']?.toString() : null,
      driverName: driver is Map ? driver['full_name']?.toString() : null,
      complianceStatus: json['compliance_status']?.toString(),
      complianceLabel: json['compliance_label']?.toString(),
      missingRequiredDocumentsCount:
          (json['missing_required_documents_count'] as num?)?.toInt() ?? 0,
      missingRequiredDocuments:
          (json['missing_required_documents'] is List
                  ? json['missing_required_documents'] as List
                  : const [])
              .map((item) => item.toString())
              .toList(growable: false),
      renewableDocumentsCount:
          (json['renewable_documents_count'] as num?)?.toInt() ?? 0,
      expiredDocumentsCount:
          (json['expired_documents_count'] as num?)?.toInt() ?? 0,
      expiringSoonCount: (json['expiring_soon_count'] as num?)?.toInt() ?? 0,
      nextExpiryDate: json['next_expiry_date']?.toString(),
      documentAccess: json['document_access'] != false,
      renewalAccess: json['renewal_access'] != false,
      documents:
          (json['documents'] is List ? json['documents'] as List : const [])
              .whereType<Map>()
              .map(
                (item) =>
                    FleetVehicleDocument.fromJson(item.cast<String, dynamic>()),
              )
              .toList(growable: false),
      hasTracker: json['has_tracker'] == true,
      isLive: json['is_live'] == true,
      lastPositionAt: json['last_position_at']?.toString(),
      cardNumber: json['card_number']?.toString(),
      cardLastFour: json['card_last_four']?.toString(),
      cardStatus: json['card_status']?.toString(),
      allocationBalanceNaira: json['allocation_balance_naira']?.toString(),
      allocationNaira: json['allocation_naira']?.toString(),
    );
  }
}

class FleetVehicleDocument {
  const FleetVehicleDocument({
    required this.id,
    required this.documentTypeId,
    required this.type,
    required this.name,
    required this.status,
    required this.statusLabel,
    required this.expiryDate,
    required this.daysUntilExpiry,
    required this.renewalAction,
  });

  final String id;
  final String documentTypeId;
  final String type;
  final String name;
  final String status;
  final String statusLabel;
  final String? expiryDate;
  final int? daysUntilExpiry;
  final String renewalAction;

  bool get canRenewDirectly => renewalAction == 'DIRECT';
  bool get ownerActionRequired => renewalAction == 'OWNER_REQUIRED';

  factory FleetVehicleDocument.fromJson(Map<String, dynamic> json) {
    return FleetVehicleDocument(
      id: json['id']?.toString() ?? '',
      documentTypeId: json['document_type_id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Vehicle paper',
      status: json['status']?.toString() ?? 'UNKNOWN',
      statusLabel: json['status_label']?.toString() ?? 'Unknown',
      expiryDate: json['expiry_date']?.toString(),
      daysUntilExpiry: (json['days_until_expiry'] as num?)?.toInt(),
      renewalAction: json['renewal_action']?.toString() ?? 'RESTRICTED',
    );
  }
}

class FleetRegionRef {
  const FleetRegionRef({required this.id, required this.name, this.state});

  final String id;
  final String name;
  final String? state;

  factory FleetRegionRef.fromJson(Map<String, dynamic> json) {
    return FleetRegionRef(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Region',
      state: json['state']?.toString(),
    );
  }
}

class FleetDriver {
  const FleetDriver({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.licenseNumber,
    required this.region,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? licenseNumber;
  final FleetRegionRef? region;

  factory FleetDriver.fromJson(Map<String, dynamic> json) {
    final region = json['region'];
    return FleetDriver(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Driver',
      phone: json['phone']?.toString(),
      licenseNumber: json['license_number']?.toString(),
      region: region is Map
          ? FleetRegionRef.fromJson(region.cast<String, dynamic>())
          : null,
    );
  }
}

class FleetDriversPage {
  const FleetDriversPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<FleetDriver> items;
  final int page;
  final int lastPage;
  final int total;
}

class FleetFuelSummary {
  const FleetFuelSummary({
    required this.organisationId,
    required this.organisationName,
    required this.scope,
    required this.fundingModel,
    required this.fundingModelLabel,
    required this.balanceKobo,
    required this.balanceNaira,
    required this.availableKobo,
    required this.availableNaira,
    required this.reservedKobo,
    required this.reservedNaira,
    required this.monthSpendKobo,
    required this.monthSpendNaira,
    required this.visibleVehicleCount,
    required this.activeCardCount,
    required this.activeTransactionCount,
  });

  final String organisationId;
  final String? organisationName;
  final FleetScope scope;
  final String? fundingModel;
  final String? fundingModelLabel;
  final int balanceKobo;
  final String balanceNaira;
  final int availableKobo;
  final String availableNaira;
  final int reservedKobo;
  final String reservedNaira;
  final int monthSpendKobo;
  final String monthSpendNaira;
  final int visibleVehicleCount;
  final int activeCardCount;
  final int activeTransactionCount;

  factory FleetFuelSummary.fromJson(Map<String, dynamic> json) {
    final organisation = json['organisation'];
    final org = organisation is Map ? organisation : const {};
    int integer(String key) => (json[key] as num?)?.toInt() ?? 0;
    return FleetFuelSummary(
      organisationId: org['id']?.toString() ?? '',
      organisationName: org['name']?.toString(),
      scope: FleetScope.fromJson(json['scope']),
      fundingModel: json['funding_model']?.toString(),
      fundingModelLabel: json['funding_model_label']?.toString(),
      balanceKobo: integer('balance_kobo'),
      balanceNaira: json['balance_naira']?.toString() ?? '0.00',
      availableKobo: integer('available_kobo'),
      availableNaira: json['available_naira']?.toString() ?? '0.00',
      reservedKobo: integer('reserved_kobo'),
      reservedNaira: json['reserved_naira']?.toString() ?? '0.00',
      monthSpendKobo: integer('month_spend_kobo'),
      monthSpendNaira: json['month_spend_naira']?.toString() ?? '0.00',
      visibleVehicleCount: integer('visible_vehicle_count'),
      activeCardCount: integer('active_card_count'),
      activeTransactionCount: integer('active_transaction_count'),
    );
  }
}

class FleetFundingStepUp {
  const FleetFundingStepUp({
    required this.token,
    required this.expiresAt,
    required this.expiresInSeconds,
  });

  final String token;
  final DateTime? expiresAt;
  final int expiresInSeconds;

  factory FleetFundingStepUp.fromJson(Map<String, dynamic> json) {
    return FleetFundingStepUp(
      token: json['token']?.toString() ?? '',
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      expiresInSeconds: (json['expires_in_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class FleetFundingReceipt {
  const FleetFundingReceipt({
    required this.requestId,
    required this.walletTransactionId,
    required this.amountKobo,
    required this.amountNaira,
    required this.status,
    required this.completedAt,
    required this.idempotentReplay,
    required this.personalWalletBalanceKobo,
    required this.personalWalletBalanceNaira,
    required this.fleetBalanceKobo,
    required this.fleetBalanceNaira,
  });

  final String requestId;
  final String? walletTransactionId;
  final int amountKobo;
  final String amountNaira;
  final String status;
  final DateTime? completedAt;
  final bool idempotentReplay;
  final int personalWalletBalanceKobo;
  final String personalWalletBalanceNaira;
  final int fleetBalanceKobo;
  final String fleetBalanceNaira;

  factory FleetFundingReceipt.fromJson(Map<String, dynamic> json) {
    int integer(String key) => (json[key] as num?)?.toInt() ?? 0;
    return FleetFundingReceipt(
      requestId: json['request_id']?.toString() ?? '',
      walletTransactionId: json['wallet_transaction_id']?.toString(),
      amountKobo: integer('amount_kobo'),
      amountNaira: json['amount_naira']?.toString() ?? '0.00',
      status: json['status']?.toString() ?? 'UNKNOWN',
      completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
      idempotentReplay: json['idempotent_replay'] == true,
      personalWalletBalanceKobo: integer('personal_wallet_balance_kobo'),
      personalWalletBalanceNaira:
          json['personal_wallet_balance_naira']?.toString() ?? '0.00',
      fleetBalanceKobo: integer('fleet_balance_kobo'),
      fleetBalanceNaira: json['fleet_balance_naira']?.toString() ?? '0.00',
    );
  }
}

class FleetFuelCardReceipt {
  const FleetFuelCardReceipt({
    required this.orgVehicleId,
    required this.cardLastFour,
    required this.status,
    required this.issuedAt,
  });

  final String orgVehicleId;
  final String cardLastFour;
  final String status;
  final DateTime? issuedAt;

  factory FleetFuelCardReceipt.fromJson(Map<String, dynamic> json) {
    return FleetFuelCardReceipt(
      orgVehicleId: json['org_vehicle_id']?.toString() ?? '',
      cardLastFour: json['card_last_four']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      issuedAt: DateTime.tryParse(json['issued_at']?.toString() ?? ''),
    );
  }
}

class FleetAllocationReceipt {
  const FleetAllocationReceipt({
    required this.requestId,
    required this.orgVehicleId,
    required this.requestedKobo,
    required this.grantedKobo,
    required this.grantedNaira,
    required this.idempotentReplay,
    required this.allocationBalanceKobo,
    required this.allocationBalanceNaira,
    required this.fleetAvailableKobo,
    required this.fleetAvailableNaira,
  });

  final String requestId;
  final String orgVehicleId;
  final int requestedKobo;
  final int grantedKobo;
  final String grantedNaira;
  final bool idempotentReplay;
  final int allocationBalanceKobo;
  final String allocationBalanceNaira;
  final int fleetAvailableKobo;
  final String fleetAvailableNaira;

  factory FleetAllocationReceipt.fromJson(Map<String, dynamic> json) {
    int integer(String key) => (json[key] as num?)?.toInt() ?? 0;
    return FleetAllocationReceipt(
      requestId: json['request_id']?.toString() ?? '',
      orgVehicleId: json['org_vehicle_id']?.toString() ?? '',
      requestedKobo: integer('requested_kobo'),
      grantedKobo: integer('granted_kobo'),
      grantedNaira: json['granted_naira']?.toString() ?? '0.00',
      idempotentReplay: json['idempotent_replay'] == true,
      allocationBalanceKobo: integer('allocation_balance_kobo'),
      allocationBalanceNaira:
          json['allocation_balance_naira']?.toString() ?? '0.00',
      fleetAvailableKobo: integer('fleet_available_kobo'),
      fleetAvailableNaira: json['fleet_available_naira']?.toString() ?? '0.00',
    );
  }
}

class FleetFuelTransaction {
  const FleetFuelTransaction({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.orgVehicleId,
    required this.vehicleId,
    required this.plateNumber,
    required this.vehicleLabel,
    required this.regionName,
    required this.stationName,
    required this.stationAddress,
    required this.cardLastFour,
    required this.pricePerLiterKobo,
    required this.pricePerLiterNaira,
    required this.litersDispensed,
    required this.settledAmountKobo,
    required this.reservedAmountKobo,
    required this.displayAmountKobo,
    required this.displayAmountNaira,
    required this.amountState,
    required this.createdAt,
    required this.completedAt,
  });

  final String id;
  final String status;
  final String statusLabel;
  final String? orgVehicleId;
  final String? vehicleId;
  final String? plateNumber;
  final String? vehicleLabel;
  final String? regionName;
  final String? stationName;
  final String? stationAddress;
  final String? cardLastFour;
  final int pricePerLiterKobo;
  final String pricePerLiterNaira;
  final String? litersDispensed;
  final int? settledAmountKobo;
  final int reservedAmountKobo;
  final int? displayAmountKobo;
  final String? displayAmountNaira;
  final String amountState;
  final DateTime? createdAt;
  final DateTime? completedAt;

  bool get isComplete => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';

  factory FleetFuelTransaction.fromJson(Map<String, dynamic> json) {
    final vehicleRaw = json['vehicle'];
    final vehicle = vehicleRaw is Map ? vehicleRaw : const {};
    final stationRaw = json['station'];
    final station = stationRaw is Map ? stationRaw : const {};
    int? optionalInteger(String key) =>
        json[key] is num ? (json[key] as num).toInt() : null;
    return FleetFuelTransaction(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      statusLabel: json['status_label']?.toString() ?? 'Unknown',
      orgVehicleId: vehicle['org_vehicle_id']?.toString(),
      vehicleId: vehicle['vehicle_id']?.toString(),
      plateNumber: vehicle['plate_number']?.toString(),
      vehicleLabel: vehicle['label']?.toString(),
      regionName: vehicle['region']?.toString(),
      stationName: station['name']?.toString(),
      stationAddress: station['address']?.toString(),
      cardLastFour: json['card_last_four']?.toString(),
      pricePerLiterKobo: (json['price_per_liter_kobo'] as num?)?.toInt() ?? 0,
      pricePerLiterNaira: json['price_per_liter_naira']?.toString() ?? '0.00',
      litersDispensed: json['liters_dispensed']?.toString(),
      settledAmountKobo: optionalInteger('settled_amount_kobo'),
      reservedAmountKobo: (json['reserved_amount_kobo'] as num?)?.toInt() ?? 0,
      displayAmountKobo: optionalInteger('display_amount_kobo'),
      displayAmountNaira: json['display_amount_naira']?.toString(),
      amountState: json['amount_state']?.toString() ?? 'UNAVAILABLE',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
    );
  }
}

class FleetFuelTransactionsPage {
  const FleetFuelTransactionsPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<FleetFuelTransaction> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

class FleetVehiclesPage {
  const FleetVehiclesPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<OrgVehicle> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

enum FleetTrackingStatus {
  live,
  stale,
  offline;

  static FleetTrackingStatus fromJson(Object? raw) {
    return switch (raw?.toString().toUpperCase()) {
      'LIVE' => FleetTrackingStatus.live,
      'STALE' => FleetTrackingStatus.stale,
      _ => FleetTrackingStatus.offline,
    };
  }
}

class FleetTrackingPoint {
  const FleetTrackingPoint({
    required this.orgVehicleId,
    required this.vehicleId,
    required this.label,
    required this.region,
    required this.driver,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    required this.lastPositionAt,
    required this.hasTracker,
    required this.hasPosition,
    required this.status,
    required this.statusReason,
    required this.sourceLabel,
  });

  final String orgVehicleId;
  final String? vehicleId;
  final String label;
  final String? region;
  final String? driver;
  final double? latitude;
  final double? longitude;
  final double? speed;
  final double? heading;
  final DateTime? lastPositionAt;
  final bool hasTracker;
  final bool hasPosition;
  final FleetTrackingStatus status;
  final String? statusReason;
  final String? sourceLabel;

  bool get canPlot => hasPosition && latitude != null && longitude != null;

  factory FleetTrackingPoint.fromJson(Map<String, dynamic> json) {
    double? number(String key) => (json[key] as num?)?.toDouble();
    final label = json['label']?.toString().trim();
    return FleetTrackingPoint(
      orgVehicleId: json['org_vehicle_id']?.toString() ?? '',
      vehicleId: json['vehicle_id']?.toString(),
      label: label?.isNotEmpty == true ? label! : 'Fleet vehicle',
      region: json['region']?.toString(),
      driver: json['driver']?.toString(),
      latitude: number('latitude'),
      longitude: number('longitude'),
      speed: number('speed'),
      heading: number('heading'),
      lastPositionAt: DateTime.tryParse(
        json['last_position_at']?.toString() ?? '',
      ),
      hasTracker: json['has_tracker'] == true,
      hasPosition: json['has_position'] == true,
      status: FleetTrackingStatus.fromJson(json['status']),
      statusReason: json['status_reason']?.toString(),
      sourceLabel: json['source_label']?.toString(),
    );
  }
}

class FleetTrackingSnapshot {
  const FleetTrackingSnapshot({
    required this.organisationId,
    required this.organisationName,
    required this.generatedAt,
    required this.freshnessSeconds,
    required this.vehicles,
  });

  final String organisationId;
  final String? organisationName;
  final DateTime? generatedAt;
  final int freshnessSeconds;
  final List<FleetTrackingPoint> vehicles;

  int get liveCount => vehicles
      .where((vehicle) => vehicle.status == FleetTrackingStatus.live)
      .length;
  int get staleCount => vehicles
      .where((vehicle) => vehicle.status == FleetTrackingStatus.stale)
      .length;
  int get offlineCount => vehicles
      .where((vehicle) => vehicle.status == FleetTrackingStatus.offline)
      .length;

  factory FleetTrackingSnapshot.fromJson(Map<String, dynamic> json) {
    final organisation = json['organisation'];
    final organisationMap = organisation is Map ? organisation : const {};
    final rawVehicles = json['vehicles'];
    return FleetTrackingSnapshot(
      organisationId: organisationMap['id']?.toString() ?? '',
      organisationName: organisationMap['name']?.toString(),
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? ''),
      freshnessSeconds: (json['freshness_seconds'] as num?)?.toInt() ?? 600,
      vehicles: (rawVehicles is List ? rawVehicles : const [])
          .whereType<Map>()
          .map(
            (vehicle) =>
                FleetTrackingPoint.fromJson(vehicle.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

class FleetSetupChecklist {
  const FleetSetupChecklist({
    required this.requiredComplete,
    required this.completedCount,
    required this.totalCount,
    required this.items,
    required this.webHandoffs,
  });

  final bool requiredComplete;
  final int completedCount;
  final int totalCount;
  final List<FleetSetupItem> items;
  final List<FleetWebHandoff> webHandoffs;

  factory FleetSetupChecklist.fromJson(Object? raw) {
    final json = raw is Map ? raw : const <String, dynamic>{};
    return FleetSetupChecklist(
      requiredComplete: json['required_complete'] == true,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      items: (json['items'] is List ? json['items'] as List : const [])
          .whereType<Map>()
          .map((item) => FleetSetupItem.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
      webHandoffs:
          (json['web_handoffs'] is List
                  ? json['web_handoffs'] as List
                  : const [])
              .whereType<Map>()
              .map(
                (item) =>
                    FleetWebHandoff.fromJson(item.cast<String, dynamic>()),
              )
              .where((item) => item.path.startsWith('/fleet/'))
              .toList(growable: false),
    );
  }
}

class FleetSetupItem {
  const FleetSetupItem({
    required this.key,
    required this.title,
    required this.description,
    required this.required,
    required this.complete,
    required this.action,
  });

  final String key;
  final String title;
  final String description;
  final bool required;
  final bool complete;
  final String? action;

  factory FleetSetupItem.fromJson(Map<String, dynamic> json) {
    return FleetSetupItem(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Fleet setup',
      description: json['description']?.toString() ?? '',
      required: json['required'] == true,
      complete: json['complete'] == true,
      action: json['action']?.toString(),
    );
  }
}

class FleetWebHandoff {
  const FleetWebHandoff({
    required this.key,
    required this.title,
    required this.description,
    required this.path,
  });

  final String key;
  final String title;
  final String description;
  final String path;

  factory FleetWebHandoff.fromJson(Map<String, dynamic> json) {
    return FleetWebHandoff(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Fleet web administration',
      description: json['description']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
    );
  }
}

class FleetOrgDetail {
  const FleetOrgDetail({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.registrationVerificationStatus,
    required this.myRole,
    required this.myRoleLabel,
    required this.capabilities,
    required this.setup,
    required this.fuelBalanceNaira,
    required this.fuelAvailableNaira,
    required this.fundingModel,
    required this.monthlyAllocationNaira,
    required this.members,
    required this.vehicles,
    required this.regionCount,
  });

  final String id;
  final String? name;
  final String? registrationNumber;
  final String registrationVerificationStatus;
  final String? myRole;
  final String? myRoleLabel;
  final FleetCapabilities capabilities;
  final FleetSetupChecklist setup;
  final String? fuelBalanceNaira;
  final String? fuelAvailableNaira;
  final String? fundingModel;
  final String? monthlyAllocationNaira;
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
      registrationVerificationStatus:
          json['registration_verification_status']?.toString() ??
          'NOT_PROVIDED',
      myRole: json['my_role']?.toString(),
      myRoleLabel: json['my_role_label']?.toString(),
      capabilities: FleetCapabilities.fromJson(json['capabilities']),
      setup: FleetSetupChecklist.fromJson(json['setup']),
      fuelBalanceNaira: fuel is Map ? fuel['balance_naira']?.toString() : null,
      fuelAvailableNaira: fuel is Map
          ? fuel['available_naira']?.toString()
          : null,
      fundingModel: fuel is Map ? fuel['funding_model']?.toString() : null,
      monthlyAllocationNaira: fuel is Map
          ? fuel['monthly_allocation_naira']?.toString()
          : null,
      members: mapList(json['members'], OrgMember.fromJson),
      vehicles: mapList(json['vehicles'], OrgVehicle.fromJson),
      regionCount: regions is List ? regions.length : 0,
    );
  }
}
