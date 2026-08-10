import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/forum/data/forum_repository.dart';
import 'package:travla_customer_app/features/forum/domain/forum_models.dart';

class ForumThreadScreen extends ConsumerStatefulWidget {
  const ForumThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ForumThreadScreen> createState() => _ForumThreadScreenState();
}

class _ForumThreadScreenState extends ConsumerState<ForumThreadScreen> {
  final _replyCtrl = TextEditingController();
  bool _sending = false;
  bool _busy = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(forumThreadProvider(widget.threadId));
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _sendReply() async {
    final body = _replyCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(forumRepositoryProvider).reply(widget.threadId, body);
      _replyCtrl.clear();
      if (mounted) FocusScope.of(context).unfocus();
      _refresh();
    } on ApiFailure catch (f) {
      _snack(f.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _likeThread() async {
    try {
      await ref.read(forumRepositoryProvider).likeThread(widget.threadId);
      _refresh();
    } on ApiFailure catch (f) {
      _snack(f.message);
    }
  }

  Future<void> _likeReply(String id) async {
    try {
      await ref.read(forumRepositoryProvider).likeReply(id);
      _refresh();
    } on ApiFailure catch (f) {
      _snack(f.message);
    }
  }

  Future<void> _deleteThread() async {
    final ok = await _confirm('Delete this thread?');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(forumRepositoryProvider).deleteThread(widget.threadId);
      if (mounted) context.pop();
    } on ApiFailure catch (f) {
      _snack(f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteReply(String id) async {
    final ok = await _confirm('Delete this reply?');
    if (!ok) return;
    try {
      await ref.read(forumRepositoryProvider).deleteReply(id);
      _refresh();
    } on ApiFailure catch (f) {
      _snack(f.message);
    }
  }

  Future<bool> _confirm(String title) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(forumThreadProvider(widget.threadId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Thread'),
        actions: [
          async.maybeWhen(
            data: (d) => d.thread.isMine
                ? IconButton(
                    onPressed: _busy ? null : _deleteThread,
                    icon: const Icon(Icons.delete_outline_rounded),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error is ApiFailure ? error.message : 'This thread could not be loaded.',
                textAlign: TextAlign.center),
          ),
        ),
        data: (detail) {
          final thread = detail.thread;
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.forest700,
                  onRefresh: () async {
                    _refresh();
                    await ref.read(forumThreadProvider(widget.threadId).future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _ThreadHead(thread: thread, onLike: _likeThread),
                      const SizedBox(height: 16),
                      _Label('${detail.replies.length} repl${detail.replies.length == 1 ? 'y' : 'ies'}'),
                      if (detail.replies.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Text('Be the first to reply.', style: TextStyle(color: AppColors.muted)),
                        )
                      else
                        ...detail.replies.map((r) => _ReplyCard(
                              reply: r,
                              onLike: () => _likeReply(r.id),
                              onDelete: r.isMine ? () => _deleteReply(r.id) : null,
                            )),
                    ],
                  ),
                ),
              ),
              if (!thread.isLocked)
                _Composer(controller: _replyCtrl, sending: _sending, onSend: _sendReply)
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  color: AppColors.white,
                  child: const Text('This thread is locked.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ThreadHead extends StatelessWidget {
  const _ThreadHead({required this.thread, required this.onLike});

  final ForumThread thread;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(thread.title,
              style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900, fontSize: 19, height: 1.3)),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.forest100,
                foregroundColor: AppColors.forest800,
                backgroundImage: thread.author.avatarUrl != null ? NetworkImage(thread.author.avatarUrl!) : null,
                child: thread.author.avatarUrl == null
                    ? Text(thread.author.name.isNotEmpty ? thread.author.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))
                    : null,
              ),
              const SizedBox(width: 8),
              Text(thread.author.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 12),
          if (thread.body != null)
            Text(thread.body!, style: const TextStyle(color: AppColors.ink, height: 1.55, fontSize: 14)),
          const Divider(height: 24),
          Row(
            children: [
              _LikeButton(liked: thread.liked, count: thread.likeCount, onTap: onLike),
              const Spacer(),
              Icon(Icons.visibility_outlined, size: 15, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('${thread.viewCount}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply, required this.onLike, this.onDelete});

  final ForumReply reply;
  final VoidCallback onLike;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: AppColors.forest100,
                foregroundColor: AppColors.forest800,
                backgroundImage: reply.author.avatarUrl != null ? NetworkImage(reply.author.avatarUrl!) : null,
                child: reply.author.avatarUrl == null
                    ? Text(reply.author.name.isNotEmpty ? reply.author.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))
                    : null,
              ),
              const SizedBox(width: 8),
              Text(reply.author.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              const Spacer(),
              if (onDelete != null)
                InkWell(
                  onTap: onDelete,
                  child: const Icon(Icons.close_rounded, size: 16, color: AppColors.muted),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(reply.body, style: const TextStyle(color: AppColors.ink, height: 1.5, fontSize: 13.5)),
          const SizedBox(height: 8),
          _LikeButton(liked: reply.liked, count: reply.likeCount, onTap: onLike, small: true),
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.liked, required this.count, required this.onTap, this.small = false});

  final bool liked;
  final int count;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: small ? 15 : 18, color: liked ? AppColors.orange : AppColors.muted),
            const SizedBox(width: 5),
            Text('$count',
                style: TextStyle(
                    color: liked ? AppColors.orange : AppColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: small ? 12 : 13)),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Write a reply…'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              width: 48,
              child: FilledButton(
                onPressed: sending ? null : onSend,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: AppColors.orange,
                  shape: const CircleBorder(),
                ),
                child: sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
      );
}
