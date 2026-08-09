class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.slug,
    required this.title,
    required this.category,
    required this.coverImageUrl,
    required this.excerpt,
    required this.body,
    required this.tags,
    required this.sourceName,
    required this.sourceUrl,
    required this.author,
    required this.featured,
    required this.publishedAt,
    required this.viewCount,
    required this.readingMinutes,
    required this.related,
  });

  final String id;
  final String slug;
  final String title;
  final String? category;
  final String? coverImageUrl;
  final String? excerpt;
  final String? body;
  final List<String> tags;
  final String? sourceName;
  final String? sourceUrl;
  final String? author;
  final bool featured;
  final DateTime? publishedAt;
  final int viewCount;
  final int readingMinutes;
  final List<NewsArticle> related;

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final rawRelated = json['related'];
    return NewsArticle(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled briefing',
      category: json['category']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString(),
      excerpt: json['excerpt']?.toString(),
      body: json['body']?.toString(),
      tags: rawTags is List
          ? rawTags.map((tag) => tag.toString()).toList(growable: false)
          : const [],
      sourceName: json['source_name']?.toString(),
      sourceUrl: json['source_url']?.toString(),
      author: json['author']?.toString(),
      featured: json['is_featured'] == true,
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      readingMinutes: (json['reading_minutes'] as num?)?.toInt() ?? 1,
      related: rawRelated is List
          ? rawRelated
                .whereType<Map<String, dynamic>>()
                .map(NewsArticle.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class NewsCategory {
  const NewsCategory({
    required this.name,
    required this.description,
    required this.count,
  });

  final String name;
  final String description;
  final int count;

  factory NewsCategory.fromJson(Map<String, dynamic> json) {
    return NewsCategory(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class NewsMeta {
  const NewsMeta({required this.categories, required this.featured});

  final List<NewsCategory> categories;
  final NewsArticle? featured;

  factory NewsMeta.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final rawFeatured = json['featured'];
    return NewsMeta(
      categories: rawCategories is List
          ? rawCategories
                .whereType<Map<String, dynamic>>()
                .map(NewsCategory.fromJson)
                .where((category) => category.name.isNotEmpty)
                .toList(growable: false)
          : const [],
      featured: rawFeatured is Map<String, dynamic>
          ? NewsArticle.fromJson(rawFeatured)
          : null,
    );
  }
}

class NewsPage {
  const NewsPage({
    required this.articles,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<NewsArticle> articles;
  final int currentPage;
  final int lastPage;
  final int total;
}

class NewsQuery {
  const NewsQuery({
    this.search = '',
    this.category = '',
    this.sort = 'latest',
    this.page = 1,
  });

  final String search;
  final String category;
  final String sort;
  final int page;

  @override
  bool operator ==(Object other) {
    return other is NewsQuery &&
        other.search == search &&
        other.category == category &&
        other.sort == sort &&
        other.page == page;
  }

  @override
  int get hashCode => Object.hash(search, category, sort, page);
}
