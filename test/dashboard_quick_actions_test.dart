import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/features/home/presentation/dashboard_quick_actions.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';

void main() {
  testWidgets('dashboard exposes exactly six primary quick actions', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: DashboardQuickActions(vehicles: []),
            ),
          ),
        ),
        GoRoute(
          path: '/more/drivers-license',
          builder: (context, state) =>
              const Scaffold(body: Text('Driver licence destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Renew papers'), findsOneWidget);
    expect(find.text('Report accident'), findsOneWidget);
    expect(find.text('Change ownership'), findsOneWidget);
    expect(find.text('Report stolen'), findsOneWidget);
    expect(find.text("Driver's licence"), findsOneWidget);
    expect(find.text('Fleet'), findsOneWidget);

    await tester.tap(find.text("Driver's licence"));
    await tester.pumpAndSettle();
    expect(find.text('Driver licence destination'), findsOneWidget);
  });

  testWidgets('vehicle-bound action asks which vehicle when garage has many', (
    tester,
  ) async {
    final vehicles = [
      _vehicle(id: 'one', make: 'Honda', model: 'Pilot', plate: 'LAG-1'),
      _vehicle(id: 'two', make: 'Toyota', model: 'Camry', plate: 'ABJ-2'),
    ];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DashboardQuickActions(vehicles: vehicles),
            ),
          ),
        ),
        GoRoute(
          path: '/more/renewals/new',
          builder: (context, state) => Scaffold(
            body: Text('Selected ${state.uri.queryParameters['vehicle']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renew papers'));
    await tester.pumpAndSettle();

    expect(find.text('Renew papers for'), findsOneWidget);
    expect(find.text('Honda Pilot'), findsOneWidget);
    expect(find.text('Toyota Camry'), findsOneWidget);

    await tester.tap(find.text('Honda Pilot'));
    await tester.pumpAndSettle();
    expect(find.text('Selected one'), findsOneWidget);
  });
}

VehicleSummary _vehicle({
  required String id,
  required String make,
  required String model,
  required String plate,
}) => VehicleSummary(
  id: id,
  make: make,
  model: model,
  year: 2024,
  color: 'Black',
  plateNumber: plate,
  status: 'VALID',
  statusLabel: 'Up to date',
  expiredDocumentsCount: 0,
  expiringSoonCount: 0,
  documentsCount: 4,
  images: const [],
);
