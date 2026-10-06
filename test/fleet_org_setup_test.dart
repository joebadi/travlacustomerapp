import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/fleet/data/fleet_repository.dart';
import 'package:travla_customer_app/features/fleet/domain/fleet_models.dart';
import 'package:travla_customer_app/features/fleet/presentation/fleet_org_screen.dart';

void main() {
  testWidgets('Fleet overview shows setup progress and explicit web handoffs', (
    tester,
  ) async {
    const organisationId = 'org-1';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fleetOrgProvider(
            organisationId,
          ).overrideWith((ref) async => _organisation()),
          fleetDashboardProvider(
            organisationId,
          ).overrideWith((ref) async => _dashboard()),
        ],
        child: const MaterialApp(
          home: FleetOrgScreen(organisationId: organisationId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Company setup'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('First Fleet vehicle'), findsOneWidget);
    expect(find.text('Start'), findsWidgets);

    final administration = find.text('Advanced administration on web');
    expect(administration, findsWidgets);
    expect(find.text('Roles & regional access'), findsOneWidget);
  });
}

FleetOrgDetail _organisation() {
  return FleetOrgDetail.fromJson({
    'id': 'org-1',
    'name': 'Example Fleet',
    'my_role': 'OWNER',
    'my_role_label': 'Owner',
    'capabilities': {
      'manage_org': true,
      'manage_members': true,
      'manage_regions': true,
      'manage_vehicles': true,
      'sees_all_regions': true,
    },
    'setup': {
      'required_complete': false,
      'completed_count': 1,
      'total_count': 4,
      'items': [
        {
          'key': 'COMPANY_CREATED',
          'title': 'Company workspace',
          'description': 'The company is active.',
          'required': true,
          'complete': true,
          'action': null,
        },
        {
          'key': 'FIRST_REGION',
          'title': 'First operating region',
          'description': 'Create an operating boundary.',
          'required': true,
          'complete': false,
          'action': 'OPEN_WEB_FLEET_REGIONS',
        },
        {
          'key': 'FIRST_VEHICLE',
          'title': 'First Fleet vehicle',
          'description': 'Add an owned vehicle.',
          'required': true,
          'complete': false,
          'action': 'OPEN_FLEET_ENROLMENT',
        },
        {
          'key': 'TEAM',
          'title': 'Operations team',
          'description': 'Invite a teammate.',
          'required': false,
          'complete': false,
          'action': 'OPEN_FLEET_TEAM',
        },
      ],
      'web_handoffs': [
        {
          'key': 'ACCESS_GOVERNANCE',
          'title': 'Roles & regional access',
          'description': 'Configure granular access on web.',
          'path': '/fleet/members?org=org-1',
        },
      ],
    },
    'regions': const [],
    'members': const [],
    'vehicles': const [],
  });
}

FleetKpis _dashboard() {
  return FleetKpis.fromJson({
    'organisation': {'id': 'org-1'},
    'capabilities': {'sees_all_regions': true},
    'scope': {
      'label': 'All regions',
      'sees_all_regions': true,
      'region_ids': const [],
    },
    'health': {'score': 0, 'label': 'Set up your fleet'},
    'kpis': const <String, Object>{},
    'alerts': const <Object>[],
    'renewal_planning': const <String, Object>{},
  });
}
