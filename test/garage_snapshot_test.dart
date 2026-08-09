import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';

void main() {
  test('garage readiness totals follow backend vehicle status values', () {
    VehicleSummary vehicle(String id, String status) {
      return VehicleSummary(
        id: id,
        make: 'Honda',
        model: 'Pilot',
        year: 2022,
        color: 'Black',
        plateNumber: 'ABC-123XY',
        status: status,
        statusLabel: status,
        expiredDocumentsCount: 0,
        expiringSoonCount: 0,
        documentsCount: 3,
        images: const [],
      );
    }

    final snapshot = GarageSnapshot(
      vehicles: [
        vehicle('1', 'VALID'),
        vehicle('2', 'VALID'),
        vehicle('3', 'EXPIRING_SOON'),
        vehicle('4', 'EXPIRED'),
      ],
      pendingTransfers: const [],
      incomingVehicles: const [],
    );

    expect(snapshot.validCount, 2);
    expect(snapshot.expiringCount, 1);
    expect(snapshot.expiredCount, 1);
  });
}
