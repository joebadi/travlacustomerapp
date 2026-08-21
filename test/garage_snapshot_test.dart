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
        vehicle('5', 'MISSING_DOCUMENTS'),
      ],
      pendingTransfers: const [],
      incomingVehicles: const [],
    );

    expect(snapshot.validCount, 2);
    expect(snapshot.expiringCount, 1);
    expect(snapshot.expiredCount, 1);
    expect(snapshot.missingCount, 1);
  });

  test('vehicle summary reads missing required papers from the API', () {
    final vehicle = VehicleSummary.fromJson({
      'id': 'vehicle-1',
      'make': 'Honda',
      'model': 'CR-V',
      'status': 'MISSING_DOCUMENTS',
      'status_label': '2 required papers missing',
      'documents_complete': false,
      'required_documents_count': 3,
      'missing_required_documents_count': 2,
      'missing_required_documents': [
        {'type': 'ROADWORTHINESS', 'name': 'Roadworthiness Certificate'},
        {'type': 'PROOF_OF_OWNERSHIP', 'name': 'Proof of Ownership'},
      ],
    });

    expect(vehicle.documentsComplete, isFalse);
    expect(vehicle.requiredDocumentsCount, 3);
    expect(vehicle.missingRequiredDocumentsCount, 2);
    expect(vehicle.missingRequiredDocumentNames, [
      'Roadworthiness Certificate',
      'Proof of Ownership',
    ]);
  });
}
