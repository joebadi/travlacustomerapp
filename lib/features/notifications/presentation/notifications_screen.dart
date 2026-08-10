import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/home/presentation/dashboard_header_actions.dart';
import 'package:travla_customer_app/features/notifications/data/notification_repository.dart';
import 'package:travla_customer_app/features/notifications/domain/app_notification.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({this.selectedId, super.key});

  final String? selectedId;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _selectedId;
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final snapshot = notifications.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if ((snapshot?.unreadCount ?? 0) > 0)
            TextButton(
              onPressed: _isMarkingAll ? null : _markAllRead,
              child: Text(_isMarkingAll ? 'Updating…' : 'Mark all read'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _NotificationError(
          message: error is ApiFailure
              ? error.message
              : 'Notifications could not be loaded.',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (data) {
          if (data.items.isEmpty) return const _EmptyNotifications();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              await ref.read(notificationsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              itemCount: data.items.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(2, 4, 2, 9),
                    child: Text(
                      'Renewals, transfers, deliveries and account updates.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  );
                }
                final item = data.items[index - 1];
                final destination = nativeNotificationPath(item.actionUrl);
                return _NotificationCard(
                  item: item,
                  isSelected: item.id == _selectedId,
                  onTap: () => _select(item),
                  onAction: destination == null
                      ? null
                      : () => context.push(destination),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _select(AppNotification item) async {
    setState(() {
      _selectedId = _selectedId == item.id ? null : item.id;
    });
    if (item.isRead) return;
    try {
      await ref.read(notificationRepositoryProvider).markRead(item.id);
      ref.invalidate(notificationsProvider);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _isMarkingAll = true);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      ref.invalidate(notificationsProvider);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onAction,
  });

  final AppNotification item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: item.isRead ? AppColors.white : AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.forest600
              : item.isRead
              ? AppColors.border
              : const Color(0xFFFFC6B4),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item.isRead ? AppColors.forest50 : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconFor(item.type),
                    color: item.isRead ? AppColors.forest700 : AppColors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (!item.isRead)
                            const Padding(
                              padding: EdgeInsets.only(left: 8, top: 4),
                              child: CircleAvatar(
                                radius: 4,
                                backgroundColor: AppColors.orange,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: Text(
                          item.message,
                          maxLines: isSelected ? null : 2,
                          overflow: isSelected
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isSelected && onAction != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: onAction,
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            label: const Text('Open update'),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.forest50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.typeLabel,
                              style: const TextStyle(
                                color: AppColors.forest700,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            notificationTimeLabel(item.createdAt),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: isSelected ? .5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppColors.muted,
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
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.forest50,
              child: Icon(
                Icons.notifications_none_rounded,
                color: AppColors.forest700,
                size: 28,
              ),
            ),
            SizedBox(height: 14),
            Text(
              "You're all caught up",
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Important Travla updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.muted,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String type) {
  switch (type.toUpperCase()) {
    case 'WALLET':
      return Icons.account_balance_wallet_outlined;
    case 'DELIVERY_STATUS':
      return Icons.local_shipping_outlined;
    case 'DOCUMENT_EXPIRY':
    case 'RENEWAL_STATUS':
      return Icons.description_outlined;
    case 'TRANSFER_STATUS':
      return Icons.swap_horiz_rounded;
    case 'STOLEN_ALERT':
      return Icons.gpp_maybe_outlined;
    default:
      return Icons.notifications_none_rounded;
  }
}
