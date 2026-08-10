import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/forum/data/forum_repository.dart';
import 'package:travla_customer_app/features/forum/domain/forum_models.dart';

class ForumScreen extends ConsumerStatefulWidget {
  const ForumScreen({super.key});

  @override
  ConsumerState<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends ConsumerState<ForumScreen> {
  String? _category; // slug
  String _sort = 'active';

  ForumQuery get _query => (category: _category, query: null, sort: _sort);

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(forumCategoriesProvider);
    final threads = ref.watch(forumThreadsProvider(_query));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Car Talk'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => forumSortOptions
                .map((o) => PopupMenuItem(value: o.value, child: Text(o.label)))
                .toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        onPressed: () => context.push('/more/forum/new'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('New thread'),
      ),
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: () async {
          ref.invalidate(forumCategoriesProvider);
          ref.invalidate(forumThreadsProvider(_query));
          await ref.read(forumThreadsProvider(_query).future).catchError((_) => <ForumThread>[]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: categories.maybeWhen(
                  data: (cats) => ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    children: [
                      _CategoryChip(
                        label: 'All',
                        selected: _category == null,
                        onTap: () => setState(() => _category = null),
                      ),
                      ...cats.map((c) => _CategoryChip(
                            label: '${c.name} · ${c.threadCount}',
                            selected: _category == c.slug,
                            onTap: () => setState(() => _category = c.slug),
                          )),
                    ],
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
            ),
            threads.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      error is ApiFailure ? error.message : 'The forum could not be loaded.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              data: (list) => list.isEmpty
                  ? const SliverFillRemaining(
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
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      sliver: SliverList.list(
                        children: list.map((t) => _ThreadRow(thread: t)).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

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
            border: Border.all(color: selected ? AppColors.forest700 : AppColors.border),
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
                    const Icon(Icons.push_pin_rounded, size: 14, color: AppColors.orange),
                    const SizedBox(width: 4),
                  ],
                  if (thread.categoryName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _color(thread.categoryColor).withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        thread.categoryName!,
                        style: TextStyle(color: _color(thread.categoryColor), fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  const Spacer(),
                  Text(_ago(thread.lastActivityAt ?? thread.createdAt),
                      style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                thread.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900, fontSize: 15, height: 1.3),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('by ${thread.author.name}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
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
          Text('$count', style: const TextStyle(color: AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      );

  Color _color(String? hex) {
    if (hex == null) return AppColors.forest700;
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
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
