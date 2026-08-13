class SupportAuthor {
  const SupportAuthor({
    required this.id,
    required this.name,
    required this.isStaff,
  });

  final String id;
  final String name;
  final bool isStaff;

  factory SupportAuthor.fromJson(Map<String, dynamic> json) {
    return SupportAuthor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Member',
      isStaff: json['is_staff'] == true,
    );
  }
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.body,
    required this.isSystem,
    required this.author,
    required this.createdAt,
  });

  final String id;
  final String body;
  final bool isSystem;
  final SupportAuthor? author;
  final String? createdAt;

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    return SupportMessage(
      id: json['id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      isSystem: json['is_system'] == true,
      author: author is Map
          ? SupportAuthor.fromJson(author.cast<String, dynamic>())
          : null,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class SupportRelated {
  const SupportRelated({
    required this.type,
    required this.id,
    required this.label,
  });

  final String type;
  final String id;
  final String label;

  factory SupportRelated.fromJson(Map<String, dynamic> json) {
    return SupportRelated(
      type: json['type']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.reference,
    required this.subject,
    required this.category,
    required this.status,
    required this.statusLabel,
    required this.channel,
    required this.related,
    required this.assigneeName,
    required this.lastMessageAt,
    required this.createdAt,
    required this.unread,
    required this.messages,
  });

  final String id;
  final String reference;
  final String subject;
  final String? category;
  final String status;
  final String statusLabel;
  final String channel;
  final SupportRelated? related;
  final String? assigneeName;
  final String? lastMessageAt;
  final String? createdAt;
  final bool unread;
  final List<SupportMessage> messages;

  bool get isClosed => status == 'CLOSED';

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final related = json['related'];
    final assignee = json['assignee'];
    final messages = json['messages'];
    return SupportTicket(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      category: json['category']?.toString(),
      status: json['status']?.toString() ?? 'OPEN',
      statusLabel: json['status_label']?.toString() ?? 'Open',
      channel: json['channel']?.toString() ?? 'TICKET',
      related: related is Map
          ? SupportRelated.fromJson(related.cast<String, dynamic>())
          : null,
      assigneeName: assignee is Map ? assignee['name']?.toString() : null,
      lastMessageAt: json['last_message_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      unread: json['unread'] == true,
      messages: messages is List
          ? messages
                .whereType<Map>()
                .map((e) => SupportMessage.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
    );
  }
}

class SupportOrderOption {
  const SupportOrderOption({
    required this.type,
    required this.id,
    required this.label,
  });

  final String type;
  final String id;
  final String label;

  String get key => '$type:$id';

  factory SupportOrderOption.fromJson(Map<String, dynamic> json) {
    return SupportOrderOption(
      type: json['type']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class SupportAvailability {
  const SupportAvailability({required this.online, required this.agentsOnline});

  final bool online;
  final int agentsOnline;

  factory SupportAvailability.fromJson(Map<String, dynamic> json) {
    return SupportAvailability(
      online: json['online'] == true,
      agentsOnline: (json['agents_online'] as num?)?.toInt() ?? 0,
    );
  }
}

const supportCategoryOptions = <({String value, String label})>[
  (value: '', label: 'General'),
  (value: 'PAYMENT', label: 'Payment'),
  (value: 'RENEWAL', label: 'Renewal'),
  (value: 'INSURANCE', label: 'Insurance'),
  (value: 'TRANSFER', label: 'Transfer'),
  (value: 'ACCOUNT', label: 'Account'),
];
