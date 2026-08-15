import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/checkpoint/domain/checkpoint_models.dart';
import 'package:travla_customer_app/features/checkpoint/presentation/vehicle_checkpoint_tab.dart';

void main() {
  const payload = <String, dynamic>{
    'eligible': true,
    'active': true,
    'disclaimer': 'Optional aid',
    'credential': {
      'id': 'credential-1',
      'version': 2,
      'display_code': 'ABCD-EFGH-IJKL',
      'public_url': 'https://travla.com.ng/checkpoint/token',
      'enabled_at': '2026-08-15T12:00:00Z',
      'snapshot_updated_at': '2026-08-15T12:01:00Z',
      'print_urls': {'a4': '/a4', 'compact': '/compact'},
    },
    'snapshot': {
      'vehicle': {
        'plate_number': 'SMK664DE',
        'make': 'Honda',
        'model': 'CR-V',
        'year': 2026,
        'colour': 'Silver',
        'category': 'SUV',
        // Unknown sensitive backend fields are deliberately ignored.
        'engine_number': 'MUST-NOT-BECOME-A-MODEL-FIELD',
        'owner_name': 'MUST-NOT-BECOME-A-MODEL-FIELD',
      },
      'documents': [
        {
          'document_type': 'Vehicle Licence',
          'validity': {
            'status': 'VALID',
            'status_label': 'Valid',
            'expiry_date': '2027-03-23',
          },
          'authenticity': {
            'status': 'VERIFIED',
            'status_label': 'Authority source checked',
            'evidence_level_label': 'Authority source',
          },
        },
      ],
      'security': {
        'travla_stolen_status': 'NO_ACTIVE_TRAVLA_REPORT',
        'label': 'No active report on Travla.',
        'source': 'Travla registry',
      },
      'generated_at': '2026-08-15T12:01:00Z',
    },
  };

  test('parses only the typed privacy-filtered Checkpoint contract', () {
    final state = CheckpointState.fromJson(payload);

    expect(state.active, isTrue);
    expect(state.credential?.version, 2);
    expect(state.snapshot?.vehicle.plateNumber, 'SMK664DE');
    expect(state.snapshot?.documents.single.validity.status, 'VALID');
    expect(
      state.snapshot?.documents.single.authenticity.evidenceLabel,
      'Authority source',
    );
  });

  testWidgets('snapshot remains usable in a narrow portrait viewport', (
    tester,
  ) async {
    final state = CheckpointState.fromJson(payload);
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CheckpointSnapshotView(snapshot: state.snapshot!),
            ),
          ),
        ),
      ),
    );

    expect(find.text('SMK664DE'), findsOneWidget);
    expect(find.text('Vehicle Licence'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
