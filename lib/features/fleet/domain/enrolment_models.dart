/// A fleet enrolment request — an organisation asking a vehicle owner's consent
/// to add their vehicle to the fleet. Ownership never changes; approval only
/// links the vehicle to the org.
class VehicleEnrolment {
  const VehicleEnrolment({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.isPending,
    required this.organisationId,
    required this.organisationName,
    required this.vehicleId,
    required this.vehicleName,
    required this.vehiclePlate,
    required this.regionName,
    required this.department,
    required this.message,
    required this.requestedByName,
    required this.ownerName,
    required this.scope,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String status; // PENDING/APPROVED/DECLINED/CANCELLED/EXPIRED/REVOKED
  final String statusLabel;
  final bool isPending;
  final String organisationId;
  final String? organisationName;
  final String vehicleId;
  final String? vehicleName;
  final String? vehiclePlate;
  final String? regionName;
  final String? department;
  final String? message;
  final String? requestedByName;
  final String? ownerName;
  final EnrolmentScope scope;
  final String? expiresAt;
  final String? createdAt;

  bool get isApproved => status == 'APPROVED';

  factory VehicleEnrolment.fromJson(Map<String, dynamic> json) {
    final scope = json['scope'];
    return VehicleEnrolment(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      statusLabel: json['status_label']?.toString() ?? 'Pending',
      isPending: json['is_pending'] == true,
      organisationId: json['organisation_id']?.toString() ?? '',
      organisationName: json['organisation_name']?.toString(),
      vehicleId: json['vehicle_id']?.toString() ?? '',
      vehicleName: json['vehicle_name']?.toString(),
      vehiclePlate: json['vehicle_plate']?.toString(),
      regionName: json['region_name']?.toString(),
      department: json['department']?.toString(),
      message: json['message']?.toString(),
      requestedByName: json['requested_by_name']?.toString(),
      ownerName: json['owner_name']?.toString(),
      scope: EnrolmentScope.fromJson(scope is Map ? scope : const {}),
      expiresAt: json['expires_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

/// What the organisation may access on an enrolled vehicle.
class EnrolmentScope {
  const EnrolmentScope({
    required this.tracking,
    required this.documents,
    required this.renewals,
  });

  final bool tracking;
  final bool documents;
  final bool renewals;

  List<String> get labels => [
    if (tracking) 'Tracking',
    if (documents) 'Documents',
    if (renewals) 'Renewals',
  ];

  factory EnrolmentScope.fromJson(Map json) {
    return EnrolmentScope(
      tracking: json['tracking'] != false,
      documents: json['documents'] != false,
      renewals: json['renewals'] != false,
    );
  }
}
