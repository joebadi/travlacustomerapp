import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/fleet/data/fleet_repository.dart';
import 'package:travla_customer_app/features/fleet/domain/fleet_models.dart';
import 'package:travla_customer_app/features/fleet/presentation/fleet_vehicle_screen.dart';

void main() {
  const organisationId = 'org-1';
  const orgVehicleId = 'org-vehicle-1';
  const key = (organisationId: organisationId, orgVehicleId: orgVehicleId);

  testWidgets('manager can open scoped vehicle placement editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fleetVehicleProvider(key).overrideWith((ref) async => _vehicle()),
          fleetOrgProvider(
            organisationId,
          ).overrideWith((ref) async => _organisation(manageVehicles: true)),
          fleetRegionsProvider(organisationId).overrideWith(
            (ref) async => const [
              FleetRegionRef(id: 'region-lagos', name: 'Lagos', state: 'Lagos'),
              FleetRegionRef(id: 'region-abuja', name: 'Abuja', state: 'FCT'),
            ],
          ),
        ],
        child: const MaterialApp(
          home: FleetVehicleScreen(
            organisationId: organisationId,
            orgVehicleId: orgVehicleId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editAction = find.text('Edit region & department');
    await tester.ensureVisible(editAction);
    await tester.tap(editAction);
    await tester.pumpAndSettle();

    expect(find.text('Vehicle placement'), findsOneWidget);
    expect(find.text('OPERATING REGION'), findsOneWidget);
    expect(find.text('No assigned region'), findsNothing);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      'Logistics',
    );

    await tester.tap(find.text('Abuja'));
    await tester.pump();
    expect(find.text('Confirm region move'), findsOneWidget);
  });

  testWidgets('viewer does not receive the vehicle placement action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fleetVehicleProvider(key).overrideWith((ref) async => _vehicle()),
          fleetOrgProvider(
            organisationId,
          ).overrideWith((ref) async => _organisation(manageVehicles: false)),
        ],
        child: const MaterialApp(
          home: FleetVehicleScreen(
            organisationId: organisationId,
            orgVehicleId: orgVehicleId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit region & department'), findsNothing);
  });

  testWidgets('manager receives scoped card and allocation quick actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fleetVehicleProvider(key).overrideWith((ref) async => _vehicle()),
          fleetOrgProvider(organisationId).overrideWith(
            (ref) async => _organisation(
              manageVehicles: true,
              manageFuelCards: true,
              manageAllocations: true,
            ),
          ),
        ],
        child: const MaterialApp(
          home: FleetVehicleScreen(
            organisationId: organisationId,
            orgVehicleId: orgVehicleId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final issueCard = find.text('Issue fuel card');
    await tester.scrollUntilVisible(issueCard, 160);
    expect(issueCard, findsOneWidget);
    expect(find.text('Top up vehicle allocation'), findsOneWidget);
    expect(find.text('Hybrid allocation + pool'), findsOneWidget);
  });

  testWidgets('read-only viewer sees fuel status without mutation actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fleetVehicleProvider(key).overrideWith((ref) async => _vehicle()),
          fleetOrgProvider(
            organisationId,
          ).overrideWith((ref) async => _organisation(manageVehicles: false)),
        ],
        child: const MaterialApp(
          home: FleetVehicleScreen(
            organisationId: organisationId,
            orgVehicleId: orgVehicleId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fuelControls = find.text('Fuel controls');
    await tester.scrollUntilVisible(fuelControls, 160);
    expect(fuelControls, findsOneWidget);
    expect(find.text('Issue fuel card'), findsNothing);
    expect(find.text('Top up vehicle allocation'), findsNothing);
  });

  testWidgets('vehicle owner receives direct paper renewal action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fleetVehicleProvider(
            key,
          ).overrideWith((ref) async => _vehicle(renewalAction: 'DIRECT')),
          fleetOrgProvider(
            organisationId,
          ).overrideWith((ref) async => _organisation(manageVehicles: true)),
        ],
        child: const MaterialApp(
          home: FleetVehicleScreen(
            organisationId: organisationId,
            orgVehicleId: orgVehicleId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.text('Renew now');
    await tester.scrollUntilVisible(action, 160);
    expect(action, findsOneWidget);
    expect(find.text('Vehicle Licence'), findsOneWidget);
  });

  testWidgets('fleet manager sees owner-required renewal state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fleetVehicleProvider(key).overrideWith(
            (ref) async => _vehicle(renewalAction: 'OWNER_REQUIRED'),
          ),
          fleetOrgProvider(
            organisationId,
          ).overrideWith((ref) async => _organisation(manageVehicles: true)),
        ],
        child: const MaterialApp(
          home: FleetVehicleScreen(
            organisationId: organisationId,
            orgVehicleId: orgVehicleId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = find.text('Owner action');
    await tester.scrollUntilVisible(state, 160);
    expect(state, findsOneWidget);
    expect(find.text('Renew now'), findsNothing);
  });
}

FleetOrgDetail _organisation({
  required bool manageVehicles,
  bool manageFuelCards = false,
  bool manageAllocations = false,
}) {
  return FleetOrgDetail.fromJson({
    'id': 'org-1',
    'name': 'Example Fleet',
    'my_role': manageVehicles ? 'MANAGER' : 'VIEWER',
    'capabilities': {
      'manage_vehicles': manageVehicles,
      'view_fuel_financials': true,
      'manage_fuel_cards': manageFuelCards,
      'manage_vehicle_allocations': manageAllocations,
      'sees_all_regions': false,
    },
    'fuel': {
      'funding_model': 'HYBRID',
      'monthly_allocation_naira': '5,000.00',
      'balance_naira': '20,000.00',
      'available_naira': '15,000.00',
    },
    'regions': const [],
    'members': const [],
    'vehicles': const [],
  });
}

OrgVehicle _vehicle({String? renewalAction}) {
  return OrgVehicle.fromJson({
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
    'region': {'id': 'region-lagos', 'name': 'Lagos'},
    'department': 'Logistics',
    'driver': null,
    'compliance_status': 'VALID',
    'compliance_label': 'Ready',
    'missing_required_documents': const [],
    'document_access': true,
    'renewal_access': true,
    'documents': renewalAction == null
        ? const []
        : [
            {
              'id': 'document-1',
              'document_type_id': 'type-1',
              'type': 'VEHICLE_LICENCE',
              'name': 'Vehicle Licence',
              'status': 'EXPIRED',
              'status_label': 'Expired',
              'days_until_expiry': -2,
              'renewal_action': renewalAction,
            },
          ],
    'card_number': null,
    'card_last_four': null,
    'card_status': null,
    'allocation_balance_naira': '1,500.00',
    'allocation_naira': '5,000.00',
  });
}
