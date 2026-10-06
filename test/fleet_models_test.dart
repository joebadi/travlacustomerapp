import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/fleet/domain/fleet_models.dart';

void main() {
  test('fleet capabilities default missing server flags to false', () {
    final capabilities = FleetCapabilities.fromJson({
      'manage_vehicles': true,
      'view_tracking': true,
    });

    expect(capabilities.manageVehicles, isTrue);
    expect(capabilities.viewTracking, isTrue);
    expect(capabilities.fundFleet, isFalse);
    expect(capabilities.viewFuelFinancials, isFalse);
    expect(capabilities.seesAllRegions, isFalse);
  });

  test('fleet detail preserves role, verification and financial redaction', () {
    final detail = FleetOrgDetail.fromJson({
      'id': 'org-1',
      'name': 'Scoped Fleet',
      'registration_number': 'RC-100',
      'registration_verification_status': 'UNVERIFIED',
      'my_role': 'VIEWER',
      'my_role_label': 'Viewer',
      'capabilities': {'view_tracking': true, 'view_fuel_financials': false},
      'fuel': null,
      'regions': <Object>[],
      'members': <Object>[],
      'vehicles': <Object>[],
    });

    expect(detail.myRole, 'VIEWER');
    expect(detail.registrationVerificationStatus, 'UNVERIFIED');
    expect(detail.capabilities.viewTracking, isTrue);
    expect(detail.capabilities.viewFuelFinancials, isFalse);
    expect(detail.fuelBalanceNaira, isNull);
    expect(detail.fuelAvailableNaira, isNull);
    expect(detail.fundingModel, isNull);
  });

  test('fleet setup keeps typed actions and allowlisted web handoffs', () {
    final detail = FleetOrgDetail.fromJson({
      'id': 'org-1',
      'name': 'Example Fleet',
      'capabilities': const <String, Object>{},
      'setup': {
        'required_complete': false,
        'completed_count': 1,
        'total_count': 3,
        'items': [
          {
            'key': 'FIRST_VEHICLE',
            'title': 'First Fleet vehicle',
            'description': 'Add a vehicle.',
            'required': true,
            'complete': false,
            'action': 'OPEN_FLEET_ENROLMENT',
          },
        ],
        'web_handoffs': [
          {
            'key': 'REGIONS',
            'title': 'Operating regions',
            'description': 'Manage regions.',
            'path': '/fleet/regions?org=org-1',
          },
          {
            'key': 'UNSAFE',
            'title': 'Unsafe destination',
            'description': 'Must not survive parsing.',
            'path': 'https://example.test/steal',
          },
        ],
      },
      'regions': const <Object>[],
      'members': const <Object>[],
      'vehicles': const <Object>[],
    });

    expect(detail.setup.requiredComplete, isFalse);
    expect(detail.setup.items.single.action, 'OPEN_FLEET_ENROLMENT');
    expect(detail.setup.webHandoffs.single.key, 'REGIONS');
    expect(detail.setup.webHandoffs.single.path, startsWith('/fleet/'));
  });

  test('fleet dashboard parses the selected organisation and region scope', () {
    final dashboard = FleetKpis.fromJson({
      'organisation': {'id': 'org-2', 'name': 'Delta Fleet'},
      'capabilities': {'manage_drivers': true, 'sees_all_regions': false},
      'scope': {
        'label': 'Assigned regions',
        'sees_all_regions': false,
        'region_ids': ['region-delta'],
      },
      'health': {'score': 75, 'label': 'Mostly ready'},
      'kpis': {
        'total_vehicles': 4,
        'compliant_vehicles': 3,
        'attention_vehicles': 1,
        'tracked_vehicles': 4,
        'live_vehicles': 2,
        'active_members': 3,
        'pending_invites': 0,
        'fuel_balance_naira': null,
        'available_fuel_naira': null,
      },
      'alerts': [
        {
          'id': 'documents',
          'kind': 'DOCUMENTS_MISSING',
          'severity': 'WARNING',
          'title': 'Compliance records incomplete',
          'description': 'One vehicle has no renewable papers recorded.',
          'count': 1,
          'organisation_id': 'org-2',
          'action_url': '/fleet/vehicles',
          'action': {
            'type': 'OPEN_FLEET_VEHICLES',
            'parameters': {'compliance': 'NO_DOCUMENTS'},
          },
        },
        {
          'id': 'wrong-workspace',
          'kind': 'FUEL_BALANCE_LOW',
          'severity': 'CRITICAL',
          'title': 'Wrong company alert',
          'description': 'Must not cross the selected workspace boundary.',
          'count': 1,
          'organisation_id': 'org-other',
          'action': {
            'type': 'OPEN_FLEET_FUEL',
            'parameters': <String, String>{},
          },
        },
      ],
    });

    expect(dashboard.organisationId, 'org-2');
    expect(dashboard.capabilities.manageDrivers, isTrue);
    expect(dashboard.scope.seesAllRegions, isFalse);
    expect(dashboard.scope.regionIds, ['region-delta']);
    expect(dashboard.fuelBalanceNaira, isNull);
    expect(dashboard.alerts.single.kind, 'DOCUMENTS_MISSING');
    expect(dashboard.alerts.single.actionType, 'OPEN_FLEET_VEHICLES');
    expect(
      dashboard.alerts.single.actionParameters['compliance'],
      'NO_DOCUMENTS',
    );
    expect(dashboard.alerts.single.organisationId, dashboard.organisationId);
  });

  test(
    'fleet dashboard parses scoped renewal planning and direct authority',
    () {
      final dashboard = FleetKpis.fromJson({
        'organisation': {'id': 'org-2'},
        'capabilities': const <String, Object>{},
        'scope': const <String, Object>{},
        'health': const <String, Object>{},
        'kpis': const <String, Object>{},
        'alerts': const <Object>[],
        'renewal_planning': {
          'summary': {
            'total_papers': 2,
            'due_30_days': 1,
            'due_90_days': 2,
            'due_30_cost_naira': '10,000.00',
            'due_90_cost_naira': '17,500.00',
          },
          'funding': {
            'wallet_balance_naira': '8,000.00',
            'shortfall_naira': '2,000.00',
            'sufficient_balance': false,
            'other_owner_due_count': 1,
          },
          'schedule': [
            {
              'document_id': 'doc-1',
              'document_type_id': 'type-1',
              'document_type': 'VEHICLE_LICENCE',
              'org_vehicle_id': 'ov-1',
              'vehicle_id': 'vehicle-1',
              'plate_number': 'LAG200AA',
              'vehicle_label': 'Toyota Hiace',
              'document_name': 'Vehicle Licence',
              'status': 'EXPIRED',
              'status_label': 'Expired',
              'days_until_expiry': -2,
              'owner_is_actor': true,
              'renewal_access': 'DIRECT',
              'estimated_cost_naira': '10,000.00',
            },
          ],
        },
      });

      expect(dashboard.renewalPlanning.due30Days, 1);
      expect(dashboard.renewalPlanning.otherOwnerDueCount, 1);
      expect(dashboard.renewalPlanning.sufficientBalance, isFalse);
      expect(dashboard.renewalPlanning.schedule.single.orgVehicleId, 'ov-1');
      expect(
        dashboard.renewalPlanning.schedule.single.canRenewDirectly,
        isTrue,
      );
    },
  );

  test('fleet vehicle keeps readiness, tracking and redacted fuel fields', () {
    final vehicle = OrgVehicle.fromJson({
      'id': 'org-vehicle-1',
      'vehicle': {
        'id': 'vehicle-1',
        'plate_number': 'LAG200AA',
        'make': 'Toyota',
        'model': 'Hiace',
        'year': 2021,
        'color': 'White',
        'can_open': false,
      },
      'region': {'id': 'region-1', 'name': 'Lagos'},
      'department': 'Operations',
      'driver': {'id': 'driver-1', 'full_name': 'Amina Yusuf'},
      'compliance_status': 'MISSING_DOCUMENTS',
      'compliance_label': 'Required papers missing',
      'missing_required_documents_count': 2,
      'missing_required_documents': ['Vehicle Licence', 'Roadworthiness'],
      'renewable_documents_count': 1,
      'expired_documents_count': 0,
      'expiring_soon_count': 1,
      'next_expiry_date': '2026-10-20',
      'has_tracker': true,
      'is_live': false,
      'last_position_at': '2026-10-05T12:00:00Z',
      'card_number': null,
      'allocation_balance_naira': null,
      'allocation_naira': null,
    });

    expect(vehicle.vehicleId, 'vehicle-1');
    expect(vehicle.name, 'Toyota Hiace');
    expect(vehicle.regionId, 'region-1');
    expect(vehicle.driverId, 'driver-1');
    expect(vehicle.missingRequiredDocumentsCount, 2);
    expect(vehicle.missingRequiredDocuments, contains('Roadworthiness'));
    expect(vehicle.hasTracker, isTrue);
    expect(vehicle.isLive, isFalse);
    expect(vehicle.cardNumber, isNull);
  });

  test('fleet vehicle parses paper-level renewal coordination states', () {
    final vehicle = OrgVehicle.fromJson({
      'id': 'org-vehicle-1',
      'vehicle': {'id': 'vehicle-1', 'can_open': false},
      'document_access': true,
      'renewal_access': true,
      'documents': [
        {
          'id': 'document-1',
          'document_type_id': 'type-1',
          'type': 'ROADWORTHINESS',
          'name': 'Roadworthiness Certificate',
          'status': 'EXPIRING_SOON',
          'status_label': 'Expiring soon',
          'expiry_date': '2026-10-20',
          'days_until_expiry': 14,
          'renewal_action': 'OWNER_REQUIRED',
        },
      ],
    });

    expect(vehicle.documentAccess, isTrue);
    expect(vehicle.documents.single.ownerActionRequired, isTrue);
    expect(vehicle.documents.single.canRenewDirectly, isFalse);
  });

  test('fleet driver preserves its scoped region and licence details', () {
    final driver = FleetDriver.fromJson({
      'id': 'driver-1',
      'full_name': 'Amina Yusuf',
      'phone': '08010000001',
      'license_number': 'LAG-DRIVER-1',
      'region': {'id': 'region-1', 'name': 'Lagos', 'state': 'Lagos'},
    });

    expect(driver.id, 'driver-1');
    expect(driver.fullName, 'Amina Yusuf');
    expect(driver.licenseNumber, 'LAG-DRIVER-1');
    expect(driver.region?.id, 'region-1');
    expect(driver.region?.name, 'Lagos');
  });

  test('fleet tracking snapshot preserves freshness and offline reasons', () {
    final snapshot = FleetTrackingSnapshot.fromJson({
      'generated_at': '2026-10-05T12:00:00+01:00',
      'freshness_seconds': 600,
      'organisation': {'id': 'org-1', 'name': 'Example Fleet'},
      'scope': {
        'label': 'Assigned regions',
        'sees_all_regions': false,
        'region_ids': ['region-1'],
      },
      'vehicles': [
        {
          'org_vehicle_id': 'ov-live',
          'vehicle_id': 'v-live',
          'label': 'Toyota Hiace · LAG200AA',
          'latitude': 6.5244,
          'longitude': 3.3792,
          'has_tracker': true,
          'has_position': true,
          'status': 'LIVE',
          'last_position_at': '2026-10-05T11:58:00+01:00',
        },
        {
          'org_vehicle_id': 'ov-offline',
          'vehicle_id': 'v-offline',
          'label': 'Ford Transit · ABJ300BB',
          'has_tracker': true,
          'has_position': false,
          'status': 'OFFLINE',
          'status_reason': 'NO_FIX',
        },
      ],
    });

    expect(snapshot.organisationId, 'org-1');
    expect(snapshot.freshnessSeconds, 600);
    expect(snapshot.liveCount, 1);
    expect(snapshot.staleCount, 0);
    expect(snapshot.offlineCount, 1);
    expect(snapshot.vehicles.first.canPlot, isTrue);
    expect(snapshot.vehicles.last.canPlot, isFalse);
    expect(snapshot.vehicles.last.statusReason, 'NO_FIX');
  });

  test('fleet fuel summary keeps integer money and workspace identity', () {
    final summary = FleetFuelSummary.fromJson({
      'organisation': {'id': 'org-1', 'name': 'Example Fleet'},
      'scope': {
        'label': 'Assigned regions',
        'sees_all_regions': false,
        'region_ids': ['region-1'],
      },
      'funding_model': 'SHARED',
      'funding_model_label': 'Shared balance',
      'balance_kobo': 1000000,
      'balance_naira': '10,000.00',
      'available_kobo': 750000,
      'available_naira': '7,500.00',
      'reserved_kobo': 250000,
      'reserved_naira': '2,500.00',
      'month_spend_kobo': 325000,
      'month_spend_naira': '3,250.00',
      'visible_vehicle_count': 4,
      'active_card_count': 3,
      'active_transaction_count': 1,
    });

    expect(summary.organisationId, 'org-1');
    expect(summary.scope.regionIds, ['region-1']);
    expect(summary.availableKobo, 750000);
    expect(summary.reservedKobo, 250000);
    expect(summary.monthSpendKobo, 325000);
    expect(summary.activeCardCount, 3);
  });

  test('fleet funding step-up preserves its opaque token and expiry', () {
    final challenge = FleetFundingStepUp.fromJson({
      'token': 'challenge-id.one-use-secret',
      'expires_at': '2026-10-06T09:05:00+01:00',
      'expires_in_seconds': 300,
    });

    expect(challenge.token, 'challenge-id.one-use-secret');
    expect(challenge.expiresAt?.toUtc(), DateTime.utc(2026, 10, 6, 8, 5));
    expect(challenge.expiresInSeconds, 300);
  });

  test('fleet funding receipt preserves post-transfer balances and replay', () {
    final receipt = FleetFundingReceipt.fromJson({
      'request_id': 'request-1',
      'wallet_transaction_id': 'wallet-transaction-1',
      'amount_kobo': 100000,
      'amount_naira': '1,000.00',
      'status': 'COMPLETED',
      'completed_at': '2026-10-06T09:05:01+01:00',
      'idempotent_replay': true,
      'personal_wallet_balance_kobo': 400000,
      'personal_wallet_balance_naira': '4,000.00',
      'fleet_balance_kobo': 100000,
      'fleet_balance_naira': '1,000.00',
    });

    expect(receipt.requestId, 'request-1');
    expect(receipt.amountKobo, 100000);
    expect(receipt.idempotentReplay, isTrue);
    expect(receipt.personalWalletBalanceKobo, 400000);
    expect(receipt.fleetBalanceKobo, 100000);
  });

  test('fleet card and allocation receipts preserve safe display fields', () {
    final card = FleetFuelCardReceipt.fromJson({
      'org_vehicle_id': 'org-vehicle-1',
      'card_last_four': '4821',
      'status': 'ACTIVE',
      'issued_at': '2026-10-06T10:00:00+01:00',
    });
    final allocation = FleetAllocationReceipt.fromJson({
      'request_id': 'request-1',
      'org_vehicle_id': 'org-vehicle-1',
      'requested_kobo': 100000,
      'granted_kobo': 100000,
      'granted_naira': '1,000.00',
      'idempotent_replay': false,
      'allocation_balance_kobo': 150000,
      'allocation_balance_naira': '1,500.00',
      'fleet_available_kobo': 400000,
      'fleet_available_naira': '4,000.00',
    });

    expect(card.cardLastFour, '4821');
    expect(card.status, 'ACTIVE');
    expect(allocation.requestId, 'request-1');
    expect(allocation.grantedKobo, 100000);
    expect(allocation.allocationBalanceKobo, 150000);
    expect(allocation.fleetAvailableKobo, 400000);
  });

  test('fleet fuel transaction distinguishes reserved and settled amounts', () {
    final transaction = FleetFuelTransaction.fromJson({
      'id': 'fuel-1',
      'status': 'BLOCKED',
      'status_label': 'Funds reserved',
      'vehicle': {
        'org_vehicle_id': 'org-vehicle-1',
        'vehicle_id': 'vehicle-1',
        'plate_number': 'LAG200AA',
        'label': 'Toyota Hiace',
        'region': 'Lagos',
      },
      'station': {
        'id': 'station-1',
        'name': 'Travla Station',
        'address': 'Lagos',
      },
      'card_last_four': '1234',
      'price_per_liter_kobo': 10000,
      'price_per_liter_naira': '100.00',
      'liters_dispensed': null,
      'settled_amount_kobo': null,
      'reserved_amount_kobo': 250000,
      'display_amount_kobo': 250000,
      'display_amount_naira': '2,500.00',
      'amount_state': 'RESERVED',
      'created_at': '2026-10-06T12:00:00+01:00',
      'completed_at': null,
    });

    expect(transaction.plateNumber, 'LAG200AA');
    expect(transaction.amountState, 'RESERVED');
    expect(transaction.settledAmountKobo, isNull);
    expect(transaction.displayAmountKobo, 250000);
    expect(transaction.isComplete, isFalse);
  });
}
