/// Reference data for the claim form (`/claims/meta`).
class ClaimMeta {
  const ClaimMeta({
    required this.types,
    required this.severities,
    required this.policeReportFeeNaira,
  });

  final List<ClaimTypeOption> types;
  final List<String> severities;
  final String policeReportFeeNaira;

  factory ClaimMeta.fromJson(Map<String, dynamic> json) {
    final types = json['types'];
    final severities = json['severities'];
    return ClaimMeta(
      types: (types is List ? types : const [])
          .whereType<Map>()
          .map((e) => ClaimTypeOption.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      severities: (severities is List ? severities : const [])
          .map((e) => e.toString())
          .toList(growable: false),
      policeReportFeeNaira: json['police_report_fee_naira']?.toString() ?? '0.00',
    );
  }
}

class ClaimTypeOption {
  const ClaimTypeOption({
    required this.value,
    required this.label,
    required this.requiredDocuments,
  });

  final String value;
  final String label;
  final List<({String slug, String label})> requiredDocuments;

  factory ClaimTypeOption.fromJson(Map<String, dynamic> json) {
    final docs = json['required_documents'];
    return ClaimTypeOption(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      requiredDocuments: (docs is List ? docs : const [])
          .whereType<Map>()
          .map(
            (e) => (
              slug: e['slug']?.toString() ?? '',
              label: e['label']?.toString() ?? '',
            ),
          )
          .toList(growable: false),
    );
  }
}

class ClaimEvidence {
  const ClaimEvidence({
    required this.id,
    required this.fileType,
    required this.docSlug,
    required this.originalFilename,
    required this.description,
  });

  final String id;
  final String fileType;
  final String? docSlug;
  final String? originalFilename;
  final String? description;

  factory ClaimEvidence.fromJson(Map<String, dynamic> json) {
    return ClaimEvidence(
      id: json['id']?.toString() ?? '',
      fileType: json['file_type']?.toString() ?? 'DOCUMENT',
      docSlug: json['doc_slug']?.toString(),
      originalFilename: json['original_filename']?.toString(),
      description: json['description']?.toString(),
    );
  }
}

class ClaimDispute {
  const ClaimDispute({
    required this.id,
    required this.reason,
    required this.description,
    required this.status,
    required this.response,
    required this.naicomEscalated,
    required this.naicomReference,
  });

  final String id;
  final String? reason;
  final String? description;
  final String? status;
  final String? response;
  final bool naicomEscalated;
  final String? naicomReference;

  factory ClaimDispute.fromJson(Map<String, dynamic> json) {
    return ClaimDispute(
      id: json['id']?.toString() ?? '',
      reason: json['reason']?.toString(),
      description: json['description']?.toString(),
      status: json['status']?.toString(),
      response: json['response']?.toString(),
      naicomEscalated: json['naicom_escalated'] == true,
      naicomReference: json['naicom_reference']?.toString(),
    );
  }
}

class ClaimPolicyRef {
  const ClaimPolicyRef({
    required this.id,
    required this.provider,
    required this.policyNumber,
    required this.coverageLabel,
  });

  final String? id;
  final String? provider;
  final String? policyNumber;
  final String? coverageLabel;

  factory ClaimPolicyRef.fromJson(Map<String, dynamic> json) {
    return ClaimPolicyRef(
      id: json['id']?.toString(),
      provider: json['provider']?.toString(),
      policyNumber: json['policy_number']?.toString(),
      coverageLabel: json['coverage_label']?.toString(),
    );
  }
}

/// A motor-insurance claim. The list view populates a subset (vehicle, status,
/// type, dates); the detail view carries the full record.
class InsuranceClaim {
  const InsuranceClaim({
    required this.id,
    required this.claimNumber,
    required this.claimType,
    required this.claimTypeLabel,
    required this.status,
    required this.statusLabel,
    required this.incidentDate,
    required this.location,
    required this.description,
    required this.damageDescription,
    required this.severity,
    required this.policeReportNumber,
    required this.policeReportFeeNaira,
    required this.policeReportFeePaid,
    required this.lateNotice,
    required this.thirdPartyInvolved,
    required this.fault,
    required this.otherVehiclePlate,
    required this.witnessInfo,
    required this.estimatedCostNaira,
    required this.approvedAmountNaira,
    required this.excessNaira,
    required this.settlementAmountNaira,
    required this.assessorNote,
    required this.decisionNote,
    required this.documentsComplete,
    required this.documentChecklist,
    required this.vehicleName,
    required this.vehiclePlate,
    required this.policies,
    required this.evidence,
    required this.disputes,
  });

  final String id;
  final String? claimNumber;
  final String? claimType;
  final String? claimTypeLabel;
  final String status;
  final String statusLabel;
  final String? incidentDate;
  final String? location;
  final String? description;
  final String? damageDescription;
  final String? severity;
  final String? policeReportNumber;
  final String? policeReportFeeNaira;
  final bool policeReportFeePaid;
  final bool lateNotice;
  final bool? thirdPartyInvolved;
  final String? fault;
  final String? otherVehiclePlate;
  final String? witnessInfo;
  final String? estimatedCostNaira;
  final String? approvedAmountNaira;
  final String? excessNaira;
  final String? settlementAmountNaira;
  final String? assessorNote;
  final String? decisionNote;
  final bool documentsComplete;
  final List<({String slug, String label, bool provided})> documentChecklist;
  final String? vehicleName;
  final String? vehiclePlate;
  final List<ClaimPolicyRef> policies;
  final List<ClaimEvidence> evidence;
  final List<ClaimDispute> disputes;

  bool get isDraft => status == 'DRAFT';
  bool get needsPayment => status == 'PENDING_PAYMENT';
  bool get canEdit => status == 'DRAFT' || status == 'PENDING_PAYMENT';
  bool get isDecided =>
      status == 'APPROVED' || status == 'REJECTED' || status == 'SETTLED';

  factory InsuranceClaim.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'];
    final vehicleJson = vehicle is Map ? vehicle : const {};
    final make = vehicleJson['make']?.toString() ?? '';
    final model = vehicleJson['model']?.toString() ?? '';
    final name = [make, model].where((s) => s.isNotEmpty).join(' ');

    List<T> mapList<T>(Object? raw, T Function(Map<String, dynamic>) fn) {
      return (raw is List ? raw : const [])
          .whereType<Map>()
          .map((e) => fn(e.cast<String, dynamic>()))
          .toList(growable: false);
    }

    final checklist = json['document_checklist'];

    return InsuranceClaim(
      id: json['id']?.toString() ?? '',
      claimNumber: json['claim_number']?.toString(),
      claimType: json['claim_type']?.toString(),
      claimTypeLabel: json['claim_type_label']?.toString(),
      status: json['status']?.toString() ?? 'DRAFT',
      statusLabel: json['status_label']?.toString() ?? 'Draft',
      incidentDate: json['incident_date']?.toString(),
      location: json['location']?.toString(),
      description: json['description']?.toString(),
      damageDescription: json['damage_description']?.toString(),
      severity: json['severity']?.toString(),
      policeReportNumber: json['police_report_number']?.toString(),
      policeReportFeeNaira: json['police_report_fee_naira']?.toString(),
      policeReportFeePaid: json['police_report_fee_paid'] == true,
      lateNotice: json['late_notice'] == true,
      thirdPartyInvolved: json['third_party_involved'] is bool
          ? json['third_party_involved'] as bool
          : null,
      fault: json['fault']?.toString(),
      otherVehiclePlate: json['other_vehicle_plate']?.toString(),
      witnessInfo: json['witness_info']?.toString(),
      estimatedCostNaira: json['estimated_cost_naira']?.toString(),
      approvedAmountNaira: json['approved_amount_naira']?.toString(),
      excessNaira: json['excess_naira']?.toString(),
      settlementAmountNaira: json['settlement_amount_naira']?.toString(),
      assessorNote: json['assessor_note']?.toString(),
      decisionNote: json['decision_note']?.toString(),
      documentsComplete: json['documents_complete'] == true,
      documentChecklist: (checklist is List ? checklist : const [])
          .whereType<Map>()
          .map(
            (e) => (
              slug: e['slug']?.toString() ?? '',
              label: e['label']?.toString() ?? '',
              provided: e['provided'] == true,
            ),
          )
          .toList(growable: false),
      vehicleName: name.isEmpty ? null : name,
      vehiclePlate: vehicleJson['plate_number']?.toString(),
      policies: mapList(json['policies'], ClaimPolicyRef.fromJson),
      evidence: mapList(json['evidence'], ClaimEvidence.fromJson),
      disputes: mapList(json['disputes'], ClaimDispute.fromJson),
    );
  }
}

class ClaimMessage {
  const ClaimMessage({
    required this.id,
    required this.direction,
    required this.author,
    required this.subject,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String direction; // INBOUND | OUTBOUND
  final String? author;
  final String? subject;
  final String? body;
  final String? createdAt;

  bool get fromMotorist => direction == 'OUTBOUND';

  factory ClaimMessage.fromJson(Map<String, dynamic> json) {
    return ClaimMessage(
      id: json['id']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'INBOUND',
      author: json['author']?.toString(),
      subject: json['subject']?.toString(),
      body: json['body']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ClaimThread {
  const ClaimThread({required this.alias, required this.messages});

  final String? alias;
  final List<ClaimMessage> messages;
}

class PlateCheckResult {
  const PlateCheckResult({
    required this.plate,
    required this.outcome,
    required this.found,
    required this.policies,
  });

  final String plate;
  final String outcome; // FOUND | NOT_FOUND | ERROR | CAPTCHA_BLOCKED | PENDING
  final bool found;
  final List<
    ({
      String? coverageType,
      String? coverageLabel,
      String? startDate,
      String? endDate,
    })
  >
  policies;

  /// The check ran but couldn't get a definitive answer (network/anti-bot) —
  /// distinct from a clean "no record", which does mean uninsured.
  bool get inconclusive => outcome == 'ERROR' || outcome == 'CAPTCHA_BLOCKED';

  factory PlateCheckResult.fromJson(Map<String, dynamic> json) {
    final policies = json['policies'];
    return PlateCheckResult(
      plate: json['plate']?.toString() ?? '',
      outcome: json['outcome']?.toString() ?? 'NOT_FOUND',
      found: json['found'] == true,
      policies: (policies is List ? policies : const [])
          .whereType<Map>()
          .map(
            (e) => (
              coverageType: e['coverage_type']?.toString(),
              coverageLabel: e['coverage_label']?.toString(),
              startDate: e['start_date']?.toString(),
              endDate: e['end_date']?.toString(),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// The server's authoritative pre-flight verdict on whether a claim can actually
/// benefit the user (`/vehicles/{id}/claim-eligibility`).
class ClaimEligibility {
  const ClaimEligibility({
    required this.verdict,
    required this.canBenefit,
    required this.requiresLiability,
    required this.title,
    required this.message,
    required this.hasActivePolicy,
    required this.coversOwnDamage,
    required this.coversTheft,
    required this.coverageLabel,
  });

  final String verdict;
  final bool canBenefit;
  final bool requiresLiability;
  final String title;
  final String message;
  final bool hasActivePolicy;
  final bool coversOwnDamage;
  final bool coversTheft;
  final String coverageLabel;

  bool get isDeadEnd => verdict == 'DEAD_END' || verdict == 'NO_COVER';

  factory ClaimEligibility.fromJson(Map<String, dynamic> json) {
    final coverage = json['coverage'];
    final cov = coverage is Map ? coverage : const {};
    return ClaimEligibility(
      verdict: json['verdict']?.toString() ?? 'PROCEED_OWN_DAMAGE',
      canBenefit: json['can_benefit'] == true,
      requiresLiability: json['requires_liability'] == true,
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      hasActivePolicy: cov['has_active_policy'] == true,
      coversOwnDamage: cov['covers_own_damage'] == true,
      coversTheft: cov['covers_theft'] == true,
      coverageLabel: cov['label']?.toString() ?? '',
    );
  }
}
