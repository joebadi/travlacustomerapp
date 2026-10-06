class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.actionUrl,
  });

  final String id;
  final String type;
  final String typeLabel;
  final String title;
  final String message;
  final String? actionUrl;
  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'SYSTEM',
      typeLabel: json['type_label']?.toString() ?? 'Update',
      title: json['title']?.toString() ?? 'Travla update',
      message: json['message']?.toString() ?? '',
      actionUrl: json['action_url']?.toString(),
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class NotificationSnapshot {
  const NotificationSnapshot({required this.items, required this.unreadCount});

  final List<AppNotification> items;
  final int unreadCount;
}

String? nativeNotificationPath(String? actionUrl) {
  final raw = actionUrl?.trim() ?? '';
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !raw.startsWith('/')) {
    return null;
  }
  final path = uri.path;
  final query = uri.hasQuery ? '?${uri.query}' : '';

  final renewalOrder = RegExp(r'^/renewals/orders/([^/]+)$').firstMatch(path);
  if (renewalOrder != null) {
    return '/more/renewals/orders/${renewalOrder.group(1)}';
  }
  if (path == '/renewals') return '/more/renewals';

  final transfer = RegExp(r'^/transfers/([^/]+)$').firstMatch(path);
  if (transfer != null) return '/more/transfers/${transfer.group(1)}';
  if (path == '/transfers') return '/more/transfers';

  if (path == '/wallet' || path == '/transactions') {
    return '/more/transactions';
  }
  final vehicle = RegExp(r'^/vehicles/([^/]+)$').firstMatch(path);
  if (vehicle != null) return '$path$query';
  if (path == '/vehicles') return '/vehicles';
  if (path == '/marketplace') return '/more/marketplace';

  // Fleet notifications use both the web-style `/fleet` contract and older
  // mobile `/more/fleet` action URLs. Only known paths are admitted here; an
  // arbitrary server URL must never become an in-app navigation instruction.
  if (path == '/fleet' || path == '/more/fleet') {
    return '/more/fleet$query';
  }
  if (path == '/fleet/requests' || path == '/more/fleet/requests') {
    return '/more/fleet/requests$query';
  }
  if (path == '/fleet/map' || path == '/fleet/vehicles') {
    return '/more/fleet';
  }

  final fleetTracking = RegExp(
    r'^/(?:more/)?fleet/([^/]+)/tracking$',
  ).firstMatch(path);
  if (fleetTracking != null) {
    return '/more/fleet/${fleetTracking.group(1)}/tracking$query';
  }
  final fleetFuelTransaction = RegExp(
    r'^/(?:more/)?fleet/([^/]+)/fuel/transactions/([^/]+)$',
  ).firstMatch(path);
  if (fleetFuelTransaction != null) {
    return '/more/fleet/${fleetFuelTransaction.group(1)}/fuel/transactions/${fleetFuelTransaction.group(2)}$query';
  }
  final fleetFuel = RegExp(r'^/(?:more/)?fleet/([^/]+)/fuel$').firstMatch(path);
  if (fleetFuel != null) {
    return '/more/fleet/${fleetFuel.group(1)}/fuel$query';
  }
  final fleetVehicle = RegExp(
    r'^/(?:more/)?fleet/([^/]+)/vehicles/([^/]+)$',
  ).firstMatch(path);
  if (fleetVehicle != null) {
    return '/more/fleet/${fleetVehicle.group(1)}/vehicles/${fleetVehicle.group(2)}$query';
  }
  final fleetEnrolments = RegExp(
    r'^/(?:more/)?fleet/([^/]+)/enrolments$',
  ).firstMatch(path);
  if (fleetEnrolments != null) {
    return '/more/fleet/${fleetEnrolments.group(1)}/enrol$query';
  }
  final fleetOrganisation = RegExp(
    r'^/(?:more/)?fleet/([^/]+)$',
  ).firstMatch(path);
  if (fleetOrganisation != null) {
    return '/more/fleet/${fleetOrganisation.group(1)}$query';
  }

  // Car Talk news articles (the admin's "new article" push).
  final news = RegExp(r'^/news/([^/]+)$').firstMatch(path);
  if (news != null) return '/news/${news.group(1)}';
  if (path == '/news') return '/news';
  return null;
}

/// Resolves push data to one safe native route. Known action URLs open their
/// workflow directly; unknown URLs fall back to the in-app notification copy.
String notificationRouteFor(Map<String, dynamic> data) {
  final target = nativeNotificationPath(data['action_url']?.toString());
  if (target != null) return target;

  final id = data['notification_id']?.toString();
  if (id != null && id.isNotEmpty) {
    return '/notifications?selected=${Uri.encodeComponent(id)}';
  }
  return '/notifications';
}
