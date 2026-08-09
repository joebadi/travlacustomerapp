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
}
