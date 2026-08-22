import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/support/data/support_repository.dart';
import 'package:travla_customer_app/features/support/domain/support_models.dart';

enum _SupportView { list, newTicket, thread }

/// The floating "Travla Support" launcher + panel — the mobile counterpart
/// of the web's `SupportWidget` (list of conversations, new-ticket form,
/// live thread). Mounted by [CustomerShell] over customer tabs except the
/// full-screen Travla map, where the map's own controls need the complete
/// canvas. It rests on the bottom-left so it does not collide with the other
/// tabs' primary actions.
class SupportFloatingWidget extends ConsumerStatefulWidget {
  const SupportFloatingWidget({super.key});

  @override
  ConsumerState<SupportFloatingWidget> createState() =>
      _SupportFloatingWidgetState();
}

class _SupportFloatingWidgetState extends ConsumerState<SupportFloatingWidget> {
  static const double _btn = 56;

  bool _open = false;
  _SupportView _view = _SupportView.list;
  String? _threadId;

  // Top-left offset of the launcher button. Null until first laid out, then
  // it defaults to the bottom-left corner. The user can drag it anywhere.
  Offset? _pos;

  Timer? _unreadTimer;
  Timer? _openTimer;
  Timer? _threadTimer;

  @override
  void initState() {
    super.initState();
    // Unread badge stays live even while the panel is closed.
    _unreadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(myTicketsProvider);
    });
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    _openTimer?.cancel();
    _threadTimer?.cancel();
    super.dispose();
  }

  void _toggle() {
    final opening = !_open;
    setState(() => _open = opening);
    if (opening) {
      ref.invalidate(supportAvailabilityProvider);
      ref.invalidate(myTicketsProvider);
      _openTimer?.cancel();
      _openTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        ref.invalidate(supportAvailabilityProvider);
        ref.invalidate(myTicketsProvider);
      });
    } else {
      _openTimer?.cancel();
      _openTimer = null;
      _stopThreadPoll();
      setState(() {
        _view = _SupportView.list;
        _threadId = null;
      });
    }
  }

  void _openThread(String id) {
    setState(() {
      _view = _SupportView.thread;
      _threadId = id;
    });
    ref.read(supportRepositoryProvider).markRead(id).catchError((_) {});
    ref.invalidate(supportTicketProvider(id));
    _threadTimer?.cancel();
    _threadTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      ref.invalidate(supportTicketProvider(id));
    });
  }

  void _stopThreadPoll() {
    _threadTimer?.cancel();
    _threadTimer = null;
  }

  void _backToList() {
    _stopThreadPoll();
    setState(() {
      _view = _SupportView.list;
      _threadId = null;
    });
    ref.invalidate(myTicketsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(myTicketsProvider);
    final unread = tickets.maybeWhen(
      data: (list) => list.where((t) => t.unread).length,
      orElse: () => 0,
    );

    // Fill the shell's Stack so the button's offset maps to the whole screen.
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final safe = MediaQuery.paddingOf(context);
          const margin = 12.0;

          // Default resting spot: bottom-left, above the bottom safe area.
          final pos = _pos ?? Offset(margin, h - _btn - margin - safe.bottom);
          final clamped = Offset(
            pos.dx.clamp(margin, w - _btn - margin),
            pos.dy.clamp(margin + safe.top, h - _btn - margin - safe.bottom),
          );

          final inBottomHalf = clamped.dy > h / 2;
          final onLeft = clamped.dx < w / 2;
          final panelWidth = (w - 2 * margin).clamp(280.0, 360.0);
          final panelLeft = onLeft
              ? clamped.dx
              : (clamped.dx + _btn - panelWidth);
          final spaceAbove = clamped.dy - margin - safe.top;
          final spaceBelow = h - (clamped.dy + _btn) - margin - safe.bottom;

          return Stack(
            children: [
              if (_open)
                Positioned(
                  left: panelLeft.clamp(margin, w - panelWidth - margin),
                  top: inBottomHalf ? null : clamped.dy + _btn + 12,
                  bottom: inBottomHalf ? (h - clamped.dy + 12) : null,
                  width: panelWidth,
                  child: _Panel(
                    maxHeight: (inBottomHalf ? spaceAbove : spaceBelow) - 12,
                    view: _view,
                    threadId: _threadId,
                    onBack: _backToList,
                    onOpenThread: _openThread,
                    onStartNew: () =>
                        setState(() => _view = _SupportView.newTicket),
                    onCreated: _openThread,
                  ),
                ),
              Positioned(
                left: clamped.dx,
                top: clamped.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() => _pos = clamped + details.delta);
                  },
                  child: _LaunchButton(
                    open: _open,
                    unread: unread,
                    onTap: _toggle,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LaunchButton extends StatelessWidget {
  const _LaunchButton({
    required this.open,
    required this.unread,
    required this.onTap,
  });

  final bool open;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.forest700,
          shape: const CircleBorder(),
          elevation: 6,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                open ? Icons.close_rounded : Icons.support_agent_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
        if (!open && unread > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({
    required this.view,
    required this.threadId,
    required this.onBack,
    required this.onOpenThread,
    required this.onStartNew,
    required this.onCreated,
    this.maxHeight = double.infinity,
  });

  final _SupportView view;
  final String? threadId;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenThread;
  final VoidCallback onStartNew;
  final ValueChanged<String> onCreated;
  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(supportAvailabilityProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    // Never taller than the space available beside the (movable) button.
    final height = (screenHeight * .62)
        .clamp(360.0, 520.0)
        .clamp(
          220.0,
          maxHeight.isFinite ? maxHeight.clamp(220.0, double.infinity) : 520.0,
        );

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 10,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: AppColors.forest700,
              child: Row(
                children: [
                  if (view != _SupportView.list)
                    InkWell(
                      onTap: onBack,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Travla Support',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: availability.maybeWhen(
                                  data: (a) => a.online
                                      ? const Color(0xFF7BE0A0)
                                      : Colors.white.withValues(alpha: .35),
                                  orElse: () =>
                                      Colors.white.withValues(alpha: .35),
                                ),
                              ),
                            ),
                            Text(
                              availability.maybeWhen(
                                data: (a) => a.online
                                    ? 'An agent is online'
                                    : 'Offline — leave us a ticket',
                                orElse: () => 'Connecting…',
                              ),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .82),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (view) {
                _SupportView.list => _ListView(
                  onOpen: onOpenThread,
                  onNew: onStartNew,
                ),
                _SupportView.newTicket => _NewTicketView(
                  online: availability.value?.online ?? false,
                  onCreated: onCreated,
                ),
                _SupportView.thread =>
                  threadId == null
                      ? const SizedBox.shrink()
                      : _ThreadView(ticketId: threadId!),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ListView extends ConsumerWidget {
  const _ListView({required this.onOpen, required this.onNew});

  final ValueChanged<String> onOpen;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(myTicketsProvider);

    return Column(
      children: [
        Expanded(
          child: tickets.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error is ApiFailure
                      ? error.message
                      : 'Support could not be loaded.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
            data: (list) => list.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No conversations yet. Start one below — we\'re here to help.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _TicketRow(
                      ticket: list[i],
                      onTap: () => onOpen(list[i].id),
                    ),
                  ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNew,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest700,
              ),
              child: const Text('New conversation'),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = switch (ticket.status) {
      'OPEN' => AppColors.forest700,
      'RESOLVED' || 'CLOSED' => AppColors.forest700,
      _ => AppColors.orangeDark,
    };
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  if (ticket.unread)
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ticket.statusLabel,
                      style: TextStyle(
                        color: tone,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ticket.reference,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewTicketView extends ConsumerStatefulWidget {
  const _NewTicketView({required this.online, required this.onCreated});

  final bool online;
  final ValueChanged<String> onCreated;

  @override
  ConsumerState<_NewTicketView> createState() => _NewTicketViewState();
}

class _NewTicketViewState extends ConsumerState<_NewTicketView> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _category = '';
  String? _orderKey;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_subjectCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Add a subject and a message.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final orders = ref.read(supportOrderOptionsProvider).value ?? const [];
      final matches = orders.where((o) => o.key == _orderKey);
      final related = matches.isEmpty ? null : matches.first;
      final ticket = await ref
          .read(supportRepositoryProvider)
          .createTicket(
            subject: _subjectCtrl.text,
            message: _messageCtrl.text,
            category: _category.isEmpty ? null : _category,
            channel: widget.online ? 'CHAT' : 'TICKET',
            related: related,
          );
      ref.invalidate(myTicketsProvider);
      if (mounted) widget.onCreated(ticket.id);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(supportOrderOptionsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.online
                ? 'An agent is online and will reply live.'
                : "We're offline right now — leave a ticket and we'll get back to you.",
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE3E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 11.5),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
              labelText: 'Subject',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Category',
              isDense: true,
            ),
            items: supportCategoryOptions
                .map(
                  (o) => DropdownMenuItem(value: o.value, child: Text(o.label)),
                )
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? ''),
          ),
          orders.maybeWhen(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: DropdownButtonFormField<String?>(
                      initialValue: _orderKey,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Related order (optional)',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None'),
                        ),
                        ...list.map(
                          (o) => DropdownMenuItem(
                            value: o.key,
                            child: Text(
                              o.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _orderKey = v),
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _messageCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest700,
              ),
              child: Text(
                _submitting
                    ? 'Sending…'
                    : (widget.online ? 'Start chat' : 'Submit ticket'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadView extends ConsumerStatefulWidget {
  const _ThreadView({required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<_ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends ConsumerState<_ThreadView> {
  final _bodyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(supportRepositoryProvider)
          .postMessage(widget.ticketId, body);
      _bodyCtrl.clear();
      ref.invalidate(supportTicketProvider(widget.ticketId));
      ref.invalidate(myTicketsProvider);
      _scrollToEnd();
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(supportTicketProvider(widget.ticketId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            error is ApiFailure
                ? error.message
                : 'This conversation could not be loaded.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ),
      ),
      data: (ticket) {
        final closed = ticket.isClosed;
        return Column(
          children: [
            if (ticket.related != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: AppColors.canvas,
                child: Text(
                  ticket.related!.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ),
            Expanded(
              child: ticket.messages.isEmpty
                  ? const Center(
                      child: Text(
                        'Say hello to get started.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(10),
                      itemCount: ticket.messages.length,
                      itemBuilder: (_, i) =>
                          _MessageBubble(message: ticket.messages[i]),
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 11),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: closed
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'This conversation is closed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _bodyCtrl,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Type a message…',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 40,
                          width: 40,
                          child: FilledButton(
                            onPressed: _sending ? null : _send,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: AppColors.forest700,
                              shape: const CircleBorder(),
                            ),
                            child: _sending
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 16),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            message.body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
        ),
      );
    }
    final mine = message.author?.isStaff != true;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .6,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? AppColors.forest700 : AppColors.canvas,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.author?.name ?? 'Support',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                color: mine ? Colors.white : AppColors.ink,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
