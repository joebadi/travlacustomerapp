import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_detail.dart';

void main() {
  group('vehicle document dates', () {
    test('expiry stays in February after leap day', () {
      final expiry = oneYearAfterNoOverflow(DateTime(2024, 2, 29));

      expect(apiDate(expiry), '2025-02-28');
    });

    test('normal issue date advances exactly one calendar year', () {
      final expiry = oneYearAfterNoOverflow(DateTime(2026, 7, 30));

      expect(apiDate(expiry), '2027-07-30');
    });
  });

  test('vehicle detail separates renewable and other documents', () {
    final vehicle = VehicleDetail.fromJson({
      'id': 'vehicle-1',
      'make': 'Honda',
      'model': 'Pilot',
      'year': 2024,
      'color': 'Black',
      'plate_number': 'ABC-123-XY',
      'chassis_number': 'CHASSIS-1',
      'engine_number': 'ENGINE-1',
      'has_valid_plate_number': true,
      'is_tinted': false,
      'category': {'value': 'suv', 'label': 'SUV'},
      'documents': [
        {
          'id': 'document-1',
          'document_type': {
            'type': 'VEHICLE_LICENCE',
            'name': 'Vehicle Licence',
            'document_category': 'RENEWABLE',
          },
          'status': 'VALID',
          'status_label': 'Valid',
          'days_until_expiry': 200,
          'auto_renew': true,
        },
        {
          'id': 'document-2',
          'document_type': {
            'type': 'PROOF_OF_OWNERSHIP',
            'name': 'Proof of Ownership',
            'document_category': 'OTHER',
          },
          'status': 'VALID',
          'status_label': 'On file',
        },
      ],
    });

    expect(vehicle.displayName, 'Honda Pilot');
    expect(vehicle.categoryLabel, 'SUV');
    expect(vehicle.renewableDocuments.single.name, 'Vehicle Licence');
    expect(vehicle.renewableDocuments.single.autoRenew, isTrue);
    expect(vehicle.otherDocuments.single.name, 'Proof of Ownership');
  });

  test('current file becomes a display version when history is absent', () {
    final document = VehicleDocument.fromJson({
      'id': 'document-1',
      'document_type': {
        'type': 'VEHICLE_LICENCE',
        'name': 'Vehicle Licence',
        'document_category': 'RENEWABLE',
      },
      'document_url': 'https://travla.com.ng/signed/document',
      'original_filename': 'licence.pdf',
      'mime_type': 'application/pdf',
      'status': 'VALID',
      'status_label': 'Valid',
    });

    expect(document.displayVersions, hasLength(1));
    expect(document.displayVersions.single.isCurrent, isTrue);
    expect(document.displayVersions.single.isOriginal, isTrue);
  });
}
