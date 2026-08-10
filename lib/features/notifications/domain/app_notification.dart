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
  final path = uri?.path ?? raw;
  final query = uri?.hasQuery == true ? '?${uri!.query}' : '';

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
  return null;
}
