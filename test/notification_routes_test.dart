import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/notifications/domain/app_notification.dart';

void main() {
  test('fleet invitations open the native Fleet directory', () {
    expect(nativeNotificationPath('/fleet'), '/more/fleet');
    expect(
      notificationRouteFor({
        'notification_id': 'notification-1',
        'action_url': '/fleet',
      }),
      '/more/fleet',
    );
  });

  test('fleet consent notifications open the native owner inbox', () {
    expect(
      nativeNotificationPath('/more/fleet/requests'),
      '/more/fleet/requests',
    );
    expect(
      nativeNotificationPath('/fleet/requests?status=pending'),
      '/more/fleet/requests?status=pending',
    );
  });

  test('known organisation Fleet destinations remain organisation scoped', () {
    expect(
      nativeNotificationPath('/fleet/org-1/tracking'),
      '/more/fleet/org-1/tracking',
    );
    expect(
      nativeNotificationPath('/fleet/org-1/vehicles/org-vehicle-1'),
      '/more/fleet/org-1/vehicles/org-vehicle-1',
    );
    expect(
      nativeNotificationPath('/fleet/org-1/enrolments'),
      '/more/fleet/org-1/enrol',
    );
    expect(
      nativeNotificationPath('/fleet/org-1/fuel'),
      '/more/fleet/org-1/fuel',
    );
    expect(
      nativeNotificationPath('/fleet/org-1/fuel/transactions/fuel-1'),
      '/more/fleet/org-1/fuel/transactions/fuel-1',
    );
  });

  test('unknown actions fall back to the selected notification', () {
    expect(nativeNotificationPath('https://example.test/unsafe'), isNull);
    expect(nativeNotificationPath('https://example.test/fleet'), isNull);
    expect(
      notificationRouteFor({
        'notification_id': 'notification/unsafe value',
        'action_url': 'https://example.test/unsafe',
      }),
      '/notifications?selected=notification%2Funsafe%20value',
    );
  });
}
