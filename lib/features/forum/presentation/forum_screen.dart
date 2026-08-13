import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/forum/data/forum_repository.dart';
import 'package:travla_customer_app/features/forum/domain/forum_models.dart';

/// The "Forum" tab inside Car Talk. Headless (no Scaffold/AppBar/FAB of its
/// own) so it can live inside CarTalkScreen's TabBarView — the sort control
/// moved inline into the category row. "New thread" is CarTalkScreen's FAB,
/// which just pushes '/more/forum/new' directly — no state here to reach.
class ForumFeedTab extends ConsumerStatefulWidget {
  const ForumFeedTab({super.key});

  @override
  ConsumerState<ForumFeedTab> createState() => _ForumFeedTabState();
}

class _ForumFeedTabState extends ConsumerState<ForumFeedTab> {
  final _queryCtrl = TextEditingController();
  String? _category; // slug
  String _sort = 'active';
  String? _query;

  List<ForumThread> _items = const [];
  int _page = 1;
  int _lastPage = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool loadMore = false}) async {
    setState(() {
      if (loadMore) {
        _loadingMore = true;
      } else {
        _loading = true;
      }
      _error = null;
    });
    try {
      final nextPage = loadMore ? _page + 1 : 1;
      final result = await ref
          .read(forumRepositoryProvider)
          .threads(
            category: _category,
            query: _query,
            sort: _sort,
            page: nextPage,
          );
      if (!mounted) return;
      setState(() {
        _items = loadMore ? [..._items, ...result.items] : result.items;
        _page = result.page;
        _lastPage = result.lastPage;
      });
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _setCategory(String? slug) {
    setState(() => _category = slug);
    _load();
  }

  void _setSort(String sort) {
    setState(() => _sort = sort);
    _load();
  }

  void _search(String value) {
    setState(() => _query = value.trim().isEmpty ? null : value.trim());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(forumCategoriesProvider);
    final stats = ref.watch(forumStatsProvider);

    return RefreshIndicator(
      color: AppColors.forest700,
      onRefresh: () async {
        ref.invalidate(forumCategoriesProvider);
        ref.invalidate(forumStatsProvider);
        await _load();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  stats.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (value) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ForumStatsRow(stats: value),
                    ),
                  ),
                  TextField(
                    controller: _queryCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search the archives',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: categories.maybeWhen(
                      data: (cats) => ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                        children: [
                          _CategoryChip(
                            label: 'All',
                            selected: _category == null,
                            onTap: () => _setCategory(null),
                          ),
                          ...cats.map(
                            (c) => _CategoryChip(
                              label: '${c.name} · ${c.threadCount}',
                              selected: _category == c.slug,
                              onTap: () => _setCategory(c.slug),
                            ),
                          ),
                        ],
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Sort threads',
                    icon: const Icon(
                      Icons.sort_rounded,
                      color: AppColors.muted,
                    ),
                    onSelected: _setSort,
                    itemBuilder: (_) => forumSortOptions
                        .map(
                          (o) => PopupMenuItem(
                            value: o.value,
                            child: Text(o.label),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ),
            )
          else if (_items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'No threads here yet. Start the conversation!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              sliver: SliverList.list(
                children: _items.map((t) => _ThreadRow(thread: t)).toList(),
              ),
            ),
          if (!_loading && _error == null && _page < _lastPage)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 96),
                child: Center(
                  child: TextButton(
                    onPressed: _loadingMore
                        ? null
                        : () => _load(loadMore: true),
                    child: _loadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Load more'),
                  ),
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}

/// Compact registry of forum-wide counters — mirrors the web forum's
/// 3-stat header (topics filed / replies posted / active today).
class _ForumStatsRow extends StatelessWidget {
  const _ForumStatsRow({required this.stats});

  final ForumStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ForumStat(label: 'Topics', value: stats.threads),
        ),
        Container(width: 1, height: 30, color: AppColors.border),
        Expanded(
          child: _ForumStat(label: 'Replies', value: stats.replies),
        ),
        Container(width: 1, height: 30, color: AppColors.border),
        Expanded(
          child: _ForumStat(label: 'Active today', value: stats.today),
        ),
      ],
    );
  }
}

class _ForumStat extends StatelessWidget {
  const _ForumStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.forest700 : AppColors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected ? AppColors.forest700 : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread});

  final ForumThread thread;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/more/forum/${thread.id}'),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (thread.isPinned) ...[
                    const Icon(
                      Icons.push_pin_rounded,
                      size: 14,
                      color: AppColors.orange,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (thread.categoryName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _color(
                          thread.categoryColor,
                        ).withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        thread.categoryName!,
                        style: TextStyle(
                          color: _color(thread.categoryColor),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    _ago(thread.lastActivityAt ?? thread.createdAt),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                thread.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'by ${thread.author.name}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                  const Spacer(),
                  _stat(Icons.mode_comment_outlined, thread.replyCount),
                  const SizedBox(width: 12),
                  _stat(Icons.favorite_border_rounded, thread.likeCount),
                  const SizedBox(width: 12),
                  _stat(Icons.visibility_outlined, thread.viewCount),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, int count) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.muted),
      const SizedBox(width: 3),
      Text(
        '$count',
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Color _color(String? hex) {
    if (hex == null) return AppColors.forest700;
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    return value == null ? AppColors.forest700 : Color(value);
  }
}

String _ago(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${diff.inDays ~/ 7}w';
}
