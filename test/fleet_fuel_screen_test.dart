import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/fleet/data/fleet_repository.dart';
import 'package:travla_customer_app/features/fleet/domain/fleet_models.dart';
import 'package:travla_customer_app/features/fleet/presentation/fleet_fuel_screen.dart';

void main() {
  testWidgets(
    'fuel transaction detail labels reserved company funds honestly',
    (tester) async {
      const key = (organisationId: 'org-1', transactionId: 'fuel-1');
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
          'name': 'Travla Test Station',
          'address': 'Lagos',
        },
        'card_last_four': '1234',
        'price_per_liter_kobo': 10000,
        'price_per_liter_naira': '100.00',
        'reserved_amount_kobo': 250000,
        'display_amount_kobo': 250000,
        'display_amount_naira': '2,500.00',
        'amount_state': 'RESERVED',
        'created_at': '2026-10-06T12:00:00+01:00',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fleetFuelTransactionProvider(
              key,
            ).overrideWith((ref) async => transaction),
          ],
          child: const MaterialApp(
            home: FleetFuelTransactionScreen(
              organisationId: 'org-1',
              transactionId: 'fuel-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₦2,500.00'), findsOneWidget);
      expect(find.text('Funds reserved'), findsOneWidget);
      expect(
        find.text('Reserved funds are not a final settled charge.'),
        findsOneWidget,
      );
      expect(find.text('LAG200AA'), findsOneWidget);
      expect(find.text('Travla Test Station'), findsOneWidget);
      final boundaryNotice = find.textContaining(
        'separate from your personal Travla wallet',
      );
      await tester.scrollUntilVisible(boundaryNotice, 180);
      expect(boundaryNotice, findsOneWidget);
    },
  );
}
