class ForumCategory {
  const ForumCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.color,
    required this.threadCount,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? color;
  final int threadCount;

  factory ForumCategory.fromJson(Map<String, dynamic> json) {
    return ForumCategory(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      color: json['color']?.toString(),
      threadCount: (json['thread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ForumAuthor {
  const ForumAuthor({required this.name, required this.avatarUrl});
  final String name;
  final String? avatarUrl;

  factory ForumAuthor.fromJson(Map<String, dynamic>? json) {
    return ForumAuthor(
      name: json?['name']?.toString() ?? 'Member',
      avatarUrl: json?['avatar_url']?.toString(),
    );
  }
}

class ForumThread {
  const ForumThread({
    required this.id,
    required this.title,
    required this.body,
    required this.categoryName,
    required this.categoryColor,
    required this.author,
    required this.latestReplyAuthor,
    required this.latestReplyAt,
    required this.viewCount,
    required this.replyCount,
    required this.likeCount,
    required this.isPinned,
    required this.isLocked,
    required this.isMine,
    required this.liked,
    required this.lastActivityAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? body;
  final String? categoryName;
  final String? categoryColor;
  final ForumAuthor author;
  final String? latestReplyAuthor;
  final String? latestReplyAt;
  final int viewCount;
  final int replyCount;
  final int likeCount;
  final bool isPinned;
  final bool isLocked;
  final bool isMine;
  final bool liked;
  final String? lastActivityAt;
  final String? createdAt;

  factory ForumThread.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final latest = json['latest_reply'];
    return ForumThread(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString(),
      categoryName: category is Map ? category['name']?.toString() : null,
      categoryColor: category is Map ? category['color']?.toString() : null,
      author: ForumAuthor.fromJson(
        json['author'] is Map
            ? (json['author'] as Map).cast<String, dynamic>()
            : null,
      ),
      latestReplyAuthor: latest is Map
          ? latest['author_name']?.toString()
          : null,
      latestReplyAt: latest is Map ? latest['created_at']?.toString() : null,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      isPinned: json['is_pinned'] == true,
      isLocked: json['is_locked'] == true,
      isMine: json['is_mine'] == true,
      liked: json['liked'] == true,
      lastActivityAt: json['last_activity_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ForumReply {
  const ForumReply({
    required this.id,
    required this.body,
    required this.author,
    required this.likeCount,
    required this.isMine,
    required this.liked,
    required this.createdAt,
  });

  final String id;
  final String body;
  final ForumAuthor author;
  final int likeCount;
  final bool isMine;
  final bool liked;
  final String? createdAt;

  factory ForumReply.fromJson(Map<String, dynamic> json) {
    return ForumReply(
      id: json['id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      author: ForumAuthor.fromJson(
        json['author'] is Map
            ? (json['author'] as Map).cast<String, dynamic>()
            : null,
      ),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      isMine: json['is_mine'] == true,
      liked: json['liked'] == true,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ForumThreadDetail {
  const ForumThreadDetail({required this.thread, required this.replies});
  final ForumThread thread;
  final List<ForumReply> replies;
}

class ForumStats {
  const ForumStats({
    required this.threads,
    required this.replies,
    required this.today,
  });

  final int threads;
  final int replies;
  final int today;

  factory ForumStats.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    return ForumStats(
      threads: asInt(json['threads']),
      replies: asInt(json['replies']),
      today: asInt(json['today']),
    );
  }
}

/// One page of forum threads — mirrors the web's `Paginated<ForumThread>`.
class ForumThreadsPage {
  const ForumThreadsPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<ForumThread> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

const forumSortOptions = <({String value, String label})>[
  (value: 'active', label: 'Active'),
  (value: 'newest', label: 'Newest'),
  (value: 'popular', label: 'Popular'),
  (value: 'unanswered', label: 'Unanswered'),
];
