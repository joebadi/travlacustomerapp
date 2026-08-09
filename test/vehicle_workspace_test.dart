import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/marketplace/domain/marketplace_models.dart';
import 'package:travla_customer_app/features/transfers/domain/transfer_models.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_service.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_tracking.dart';

void main() {
  test('quoted vehicle service becomes payable only after quote', () {
    final awaitingQuote = VehicleServiceOrder.fromJson({
      'id': 'order-1',
      'service_type': 'RESPRAY',
      'service_label': 'Vehicle respray',
      'is_fixed_price': false,
      'status': 'PENDING',
      'is_paid': false,
      'amount_due_naira': '0.00',
    });
    final quoted = VehicleServiceOrder.fromJson({
      'id': 'order-1',
      'service_type': 'RESPRAY',
      'service_label': 'Vehicle respray',
      'is_fixed_price': false,
      'status': 'PENDING',
      'is_paid': false,
      'quoted_price_naira': '250000.00',
      'amount_due_naira': '250000.00',
    });

    expect(awaitingQuote.canPay, isFalse);
    expect(quoted.canPay, isTrue);
    expect(quoted.canCancel, isTrue);
  });

  test('tracking workspace identifies active source and latest position', () {
    final workspace = VehicleTrackingWorkspace.fromJson({
      'sources': [
        {
          'id': 'tracker-1',
          'type': 'TRACCAR',
          'type_label': 'Traccar device',
          'is_active': true,
          'is_push': false,
          'unique_id': '123456789',
        },
      ],
      'latest': {
        'id': 'tracker-1',
        'type': 'TRACCAR',
        'type_label': 'Traccar device',
        'is_active': true,
        'is_push': false,
        'last_latitude': 6.5244,
        'last_longitude': 3.3792,
      },
      'trail': [
        {'latitude': 6.5244, 'longitude': 3.3792, 'speed': 31.5},
      ],
    });

    expect(workspace.hasActiveSource, isTrue);
    expect(workspace.latest?.hasPosition, isTrue);
    expect(workspace.trail.single.speed, 31.5);
  });

  test('marketplace eligibility explains missing files and expired papers', () {
    final eligibility = MarketplaceEligibility.fromJson({
      'is_ready': false,
      'documents_exempt': false,
      'missing_documents': [
        {'name': 'Vehicle licence', 'reason': 'file_missing'},
      ],
      'expired_documents': [
        {'name': 'Roadworthiness'},
      ],
      'blockers': ['A renewal is in progress for this vehicle.'],
    });

    expect(eligibility.isReady, isFalse);
    expect(eligibility.expiredDocuments.single, 'Roadworthiness');
    expect(
      eligibility.problems,
      contains('Vehicle licence needs its document file'),
    );
  });

  test(
    'transfer readiness keeps fee lines and expired papers non-blocking',
    () {
      final readiness = TransferReadiness.fromJson({
        'is_ready': true,
        'fee_naira': '27500.00',
        'delivery_fee_naira': '3500.00',
        'total_fee_naira': '31000.00',
        'total_fee_kobo': 3100000,
        'vehicle_category_label': 'SUV',
        'missing_documents': [],
        'blockers': [],
        'expired_documents': [
          {'name': 'Vehicle licence', 'expiry_date': '2026-01-01'},
        ],
      });

      expect(readiness.isReady, isTrue);
      expect(readiness.totalFeeKobo, 3100000);
      expect(readiness.expiredDocuments.single.name, 'Vehicle licence');
      expect(readiness.problems, isEmpty);
    },
  );

  test('transfer evidence enforces renewable metadata', () {
    const field = TransferDocumentField(
      key: 'vehicle_licence',
      label: 'Vehicle licence',
      category: 'RENEWABLE',
      required: true,
      requiresMetadata: true,
      conditionalNote: null,
    );
    const incomplete = TransferEvidenceUpload(
      key: 'vehicle_licence',
      path: '/tmp/licence.pdf',
      name: 'licence.pdf',
      documentNumber: '',
      issuer: '',
      issueDate: null,
    );
    final complete = TransferEvidenceUpload(
      key: 'vehicle_licence',
      path: '/tmp/licence.pdf',
      name: 'licence.pdf',
      documentNumber: 'VL-12345',
      issuer: 'Lagos State',
      issueDate: DateTime(2026, 8, 9),
    );

    expect(incomplete.completeFor(field), isFalse);
    expect(complete.completeFor(field), isTrue);
  });

  test('tinted vehicles require their permit evidence', () {
    const permit = TransferDocumentField(
      key: 'tinted_permit',
      label: 'Tinted permit',
      category: 'OTHER',
      required: false,
      requiresMetadata: false,
      conditionalNote: 'Required when applicable.',
    );
    const setup = TransferSetup(
      cities: [],
      fieldsByBasis: {
        'SALE': [permit],
      },
    );

    expect(setup.fieldsFor('SALE').single.required, isFalse);
    expect(setup.fieldsFor('SALE', tinted: true).single.required, isTrue);
  });

  test('received approved transfer requires recipient consent', () {
    final transfer = TransferRecord.fromJson({
      'id': 'transfer-1',
      'tracking_number': 'TVL-2026-001',
      'status': 'PENDING',
      'status_label': 'Pending',
      'transfer_mode': 'MANAGED',
      'transfer_mode_label': 'Travla managed',
      'transfer_basis': 'GIFT',
      'transfer_basis_label': 'Gift',
      'review_status': 'AWAITING_RECIPIENT',
      'review_status_label': 'Awaiting recipient',
      'consent_verified': false,
      'am_i_sender': false,
      'am_i_recipient': true,
      'recipient': {
        'first_name': 'Ada',
        'last_name': 'Okafor',
        'name': 'Ada Okafor',
        'email': 'ada@example.com',
      },
      'vehicle': {
        'id': 'vehicle-1',
        'make': 'Honda',
        'model': 'Pilot',
        'plate_number': 'ABC-123-XY',
      },
    });

    expect(transfer.awaitsMyConsent, isTrue);
    expect(transfer.directionLabel, 'Received');
    expect(transfer.vehicle?.displayName, 'Honda Pilot');
    expect(transfer.recipient.name, 'Ada Okafor');
  });

  test('finished transfer never requests consent again', () {
    final transfer = TransferRecord.fromJson({
      'id': 'transfer-2',
      'status': 'COMPLETED',
      'review_status': 'AWAITING_RECIPIENT',
      'consent_verified': false,
      'am_i_recipient': true,
      'recipient': {'name': 'Recipient'},
    });

    expect(transfer.isFinished, isTrue);
    expect(transfer.awaitsMyConsent, isFalse);
  });
}
