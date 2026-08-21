import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_detail_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_detail.dart';
import 'package:travla_customer_app/features/vehicles/presentation/add_vehicle_document_sheet.dart';
import 'package:travla_customer_app/features/vehicles/presentation/vehicle_detail_screen.dart';

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

  group('document verification offline snapshots', () {
    test('a recently cached snapshot is not marked stale', () {
      final workspace = DocumentVerificationWorkspace.fromJson(
        const <String, dynamic>{'current': null, 'history': <dynamic>[]},
        isFromCache: true,
        cachedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      expect(workspace.isFromCache, isTrue);
      expect(workspace.isStale, isFalse);
    });

    test('an older cached snapshot is explicitly marked stale', () {
      final workspace = DocumentVerificationWorkspace.fromJson(
        const <String, dynamic>{'current': null, 'history': <dynamic>[]},
        isFromCache: true,
        cachedAt: DateTime.now().subtract(const Duration(minutes: 16)),
      );

      expect(workspace.isFromCache, isTrue);
      expect(workspace.isStale, isTrue);
    });

    test('live verification data is never marked stale', () {
      final workspace = DocumentVerificationWorkspace.fromJson(
        const <String, dynamic>{'current': null, 'history': <dynamic>[]},
        cachedAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(workspace.isFromCache, isFalse);
      expect(workspace.isStale, isFalse);
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
      'description': 'Primary family vehicle',
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
    expect(vehicle.categoryValue, 'suv');
    expect(vehicle.categoryLabel, 'SUV');
    expect(vehicle.description, 'Primary family vehicle');
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

  testWidgets(
    'customer verification details are safe, collapsed by default and expandable',
    (tester) async {
      final vehicle = VehicleDetail.fromJson({
        'id': 'verified-vehicle',
        'make': 'Honda',
        'model': 'CR-V',
        'year': 2012,
        'color': 'Silver',
        'plate_number': 'SMK664DE',
        'chassis_number': 'JHLRD78464C029487',
        'engine_number': 'K24A13048250',
        'has_valid_plate_number': true,
        'is_tinted': false,
        'category': {'value': 'suv', 'label': 'SUV'},
        'documents': [
          {
            'id': 'verified-document',
            'document_type': {
              'type': 'VEHICLE_LICENCE',
              'name': 'Vehicle Licence',
              'document_category': 'RENEWABLE',
            },
            'issued_date': '2026-03-23',
            'expiry_date': '2027-03-23',
            'status': 'VALID',
            'status_label': 'Valid',
            'verification': {
              'attempt_id': 'attempt-1',
              'status': 'VERIFIED',
              'status_label': 'Authority source checked',
              'checked_at': '2026-08-21T20:15:00Z',
              'manual_verification': {
                'url': 'https://verify.evis.com.ng/',
                'instructions':
                    'Enter the plate number and compare the result.',
              },
              'disclaimer':
                  'Travla verification is an additional check and does not replace official records.',
            },
          },
        ],
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehicleDetailProvider(
              'verified-vehicle',
            ).overrideWith((ref) async => vehicle),
          ],
          child: const MaterialApp(
            home: VehicleDetailScreen(vehicleId: 'verified-vehicle'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      expect(find.text('Document Verified'), findsOneWidget);
      await tester.tap(find.text('See verification result →'));
      await tester.pumpAndSettle();

      expect(find.text('Document Verified'), findsWidgets);
      expect(find.text('VERIFIED ISSUE DATE'), findsNothing);
      expect(find.text('Open official verification page'), findsNothing);

      await tester.tap(find.text('Document Verified').last);
      await tester.pumpAndSettle();

      expect(find.text('VERIFIED ISSUE DATE'), findsOneWidget);
      expect(find.text('VERIFIED EXPIRY DATE'), findsOneWidget);
      expect(find.text('Open official verification page'), findsOneWidget);
      expect(find.text('Check again'), findsNothing);
      expect(find.textContaining('Authority record'), findsNothing);
      expect(find.textContaining('Official host'), findsNothing);
    },
  );

  testWidgets('vehicle documents tab renders both document sections', (
    tester,
  ) async {
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
          'document_number': 'VL-123',
          'expiry_date': '2027-08-09',
          'status': 'VALID',
          'status_label': 'Valid',
          'days_until_expiry': 365,
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vehicleDetailProvider(
            'vehicle-1',
          ).overrideWith((ref) async => vehicle),
        ],
        child: const MaterialApp(
          home: VehicleDetailScreen(vehicleId: 'vehicle-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Renewable papers'), findsOneWidget);
    expect(find.text('Other documents'), findsOneWidget);
    expect(find.text('Vehicle Licence'), findsOneWidget);
    expect(find.text('Proof of Ownership'), findsOneWidget);
  });

  testWidgets('add document sheet reveals guided details and upload stages', (
    tester,
  ) async {
    final types = [
      const AvailableDocumentType(
        type: 'VEHICLE_LICENCE',
        name: 'Vehicle Licence',
        description: 'Annual vehicle licence issued for this vehicle.',
        category: 'RENEWABLE',
        requiresUpload: true,
        alreadyAdded: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          availableDocumentTypesProvider(
            'vehicle-1',
          ).overrideWith((ref) async => types),
          vehicleDocumentStatesProvider.overrideWith(
            (ref) async => const ['Delta'],
          ),
          issuingAuthoritiesProvider((
            documentType: 'VEHICLE_LICENCE',
            state: 'Delta',
          )).overrideWith(
            (ref) async => const [
              IssuingAuthorityOption(
                id: 'authority-asaba',
                code: 'ASABA_OFFICE',
                name: 'Asaba Office',
                shortName: null,
                jurisdiction: 'STATE',
                state: 'Delta',
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AddVehicleDocumentSheet(
              vehicleId: 'vehicle-1',
              filter: DocumentTypeFilter.renewable,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Add renewable paper'), findsOneWidget);
    expect(
      find.text('Stored privately in this vehicle’s document vault.'),
      findsOneWidget,
    );
    expect(find.text('Choose the paper'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vehicle Licence').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Record the details'), findsOneWidget);
    expect(find.text('Document number · optional'), findsOneWidget);

    final stateDropdown = find.byType(DropdownButtonFormField<String>).last;
    await tester.ensureVisible(stateDropdown);
    await tester.pumpAndSettle();
    await tester.tap(stateDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delta').last);
    await tester.pumpAndSettle();

    final authorityDropdown = find.byKey(
      const ValueKey('issuing-authority-dropdown'),
    );
    await tester.ensureVisible(authorityDropdown);
    await tester.drag(find.byType(ListView).last, const Offset(0, 150));
    await tester.pumpAndSettle();
    await tester.tap(authorityDropdown);
    await tester.pumpAndSettle();

    expect(find.text('Asaba Office'), findsOneWidget);
    await tester.tap(find.text('Asaba Office'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The authority catalogue is not configured for this paper yet.',
      ),
      findsNothing,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('Attach the secure copy'), findsOneWidget);
    expect(
      find.text('Always exactly one calendar year after issue.'),
      findsOneWidget,
    );
    expect(find.text('Save to document vault'), findsOneWidget);
  });
}
