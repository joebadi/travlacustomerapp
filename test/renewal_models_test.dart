import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/notifications/domain/app_notification.dart';
import 'package:travla_customer_app/features/renewals/domain/renewal_models.dart';

void main() {
  test('renewal quote keeps server-owned document and delivery breakdown', () {
    final quote = RenewalQuote.fromJson({
      'items': [
        {
          'document_type_id': 'licence',
          'type': 'VEHICLE_LICENCE',
          'name': 'Vehicle Licence',
          'eligible': true,
          'price_kobo': 2500000,
          'price_naira': '25000.00',
        },
      ],
      'documents_kobo': 2500000,
      'documents_naira': '25000.00',
      'delivery_fee_kobo': 250000,
      'delivery_fee_naira': '2500.00',
      'total_kobo': 2750000,
      'total_naira': '27500.00',
      'wallet_balance_kobo': 50000,
      'wallet_balance_naira': '500.00',
      'sufficient_balance': false,
      'shortfall_kobo': 2700000,
      'shortfall_naira': '27000.00',
    });

    expect(quote.allEligible, isTrue);
    expect(quote.documentsKobo, 2500000);
    expect(quote.deliveryFeeKobo, 250000);
    expect(quote.totalKobo, 2750000);
    expect(quote.shortfallKobo, 2700000);
  });

  test('flat renewal records group into one order and count delivery once', () {
    final records = [
      _record(
        id: 'one',
        documentName: 'Vehicle Licence',
        amountKobo: 1000000,
        deliveryFeeKobo: 250000,
      ),
      _record(
        id: 'two',
        documentName: 'Roadworthiness',
        amountKobo: 800000,
        deliveryFeeKobo: 0,
      ),
    ];

    final order = RenewalOrderSummary.group(records).single;
    expect(order.items, hasLength(2));
    expect(order.totalKobo, 2050000);
    expect(order.documentNames, 'Vehicle Licence, Roadworthiness');
    expect(order.canCancel, isTrue);
  });

  test('delivery progress does not mark in transit at rider collection', () {
    final collected = RenewalDelivery.fromJson({
      'status': 'PICKED_UP',
      'status_label': 'Rider collected',
    });
    final started = RenewalDelivery.fromJson({
      'status': 'IN_TRANSIT',
      'status_label': 'Out for delivery',
    });

    expect(collected.stage, 2);
    expect(started.stage, 3);
  });

  test('renewal notification opens the native order route', () {
    expect(
      nativeNotificationPath('/renewals/orders/group-123'),
      '/more/renewals/orders/group-123',
    );
  });
}

RenewalRecord _record({
  required String id,
  required String documentName,
  required int amountKobo,
  required int deliveryFeeKobo,
}) {
  return RenewalRecord.fromJson({
    'id': id,
    'order_group_id': 'group-1',
    'order_reference': 'ORD-TEST',
    'tracking_number': 'TRV-$id',
    'status': 'PENDING',
    'status_label': 'Pending',
    'payment_status': 'PAID',
    'amount_kobo': amountKobo,
    'amount_naira': (amountKobo / 100).toStringAsFixed(2),
    'delivery_fee_kobo': deliveryFeeKobo,
    'delivery_fee_naira': (deliveryFeeKobo / 100).toStringAsFixed(2),
    'delivery_method': 'DELIVERY',
    'delivery_method_label': 'Door-to-door delivery',
    'city': 'Lagos',
    'state': 'Lagos',
    'request_date': '2026-08-10T10:00:00Z',
    'subject_type': 'VEHICLE',
    'document_type': {'type': id, 'name': documentName},
    'vehicle': {
      'id': 'vehicle-1',
      'make': 'Honda',
      'model': 'Pilot',
      'plate_number': 'ABC123XY',
    },
  });
}
