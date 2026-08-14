import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/features/notifications/data/notification_repository.dart';
import 'package:travla_customer_app/features/notifications/domain/app_notification.dart';
import 'package:travla_customer_app/features/wallet/data/wallet_repository.dart';
import 'package:travla_customer_app/shared/widgets/anchored_menu.dart';

/// Compact top-right actions shared by the dashboard-style headers.
class DashboardHeaderActions extends ConsumerWidget {
  const DashboardHeaderActions({super.key, this.showWallet = false});

  final bool showWallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showWallet) ...[
          const _WalletBalanceAction(),
          const SizedBox(width: 7),
        ],
        _NotificationMenu(ref: ref),
      ],
    );
  }
}

class _WalletBalanceAction extends ConsumerWidget {
  const _WalletBalanceAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletWorkspaceProvider);
    final balance = wallet.asData?.value.wallet.balanceNaira;
    final label = balance == null ? '₦—' : '₦${_compactMoney(balance)}';

    return Tooltip(
      message: 'Open Transactions',
      child: Material(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/more/transactions'),
          child: Container(
            constraints: const BoxConstraints(minWidth: 82, maxWidth: 112),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.orange,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
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

class _NotificationMenu extends StatelessWidget {
  const _NotificationMenu({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = notifications.value?.unreadCount ?? 0;

    return AnchoredMenu(
      width: 288,
      triggerBuilder: (context, isOpen, toggle) => _HeaderActionButton(
        tooltip: 'Notifications',
        onTap: toggle,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.white,
              size: 22,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -7,
                top: -7,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 17),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.forest800, width: 1.5),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 8,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      menuBuilder: (context, close) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 11),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orangeSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$unreadCount new',
                        style: const TextStyle(
                          color: AppColors.orangeDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const MenuDivider(),
            ...notifications.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(26),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ],
              error: (error, stackTrace) => [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Text(
                        'Notifications could not be loaded.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => ref.invalidate(notificationsProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ],
              data: (snapshot) {
                if (snapshot.items.isEmpty) {
                  return const [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 26,
                        horizontal: 18,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.muted,
                          ),
                          SizedBox(height: 8),
                          Text(
                            "You're all caught up.",
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                }
                return snapshot.items
                    .take(4)
                    .map(
                      (item) => _RecentNotificationItem(
                        item: item,
                        onPressed: () {
                          close();
                          _openNotification(context, item);
                        },
                      ),
                    )
                    .toList(growable: false);
              },
            ),
            const MenuDivider(),
            InkWell(
              onTap: () {
                close();
                context.push('/notifications');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Center(
                  child: Text(
                    'View all notifications',
                    style: TextStyle(
                      color: AppColors.forest700,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    AppNotification item,
  ) async {
    if (!item.isRead) {
      try {
        await ref.read(notificationRepositoryProvider).markRead(item.id);
        ref.invalidate(notificationsProvider);
      } catch (_) {
        // The full page can retry; navigation should not be blocked.
      }
    }
    if (context.mounted) {
      context.push('/notifications?selected=${Uri.encodeComponent(item.id)}');
    }
  }
}

class _RecentNotificationItem extends StatelessWidget {
  const _RecentNotificationItem({required this.item, required this.onPressed});

  final AppNotification item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        color: item.isRead ? AppColors.white : AppColors.orangeSoft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: item.isRead ? AppColors.forest50 : AppColors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _notificationIcon(item.type),
                size: 17,
                color: item.isRead ? AppColors.forest700 : AppColors.orange,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: CircleAvatar(
                            radius: 3,
                            backgroundColor: AppColors.orange,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notificationTimeLabel(item.createdAt),
                    style: const TextStyle(
                      color: AppColors.forest600,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: .1),
        shape: const CircleBorder(side: BorderSide(color: Color(0x26FFFFFF))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: 40, child: Center(child: child)),
        ),
      ),
    );
  }
}

IconData _notificationIcon(String type) {
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

String notificationTimeLabel(DateTime? value) {
  if (value == null) return 'Recently';
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

String _compactMoney(String value) {
  final amount = double.tryParse(value.replaceAll(',', ''));
  if (amount == null) return value;
  if (amount >= 1000000) {
    final millions = amount / 1000000;
    return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)}m';
  }
  if (amount >= 100000) return '${(amount / 1000).toStringAsFixed(0)}k';
  final whole = amount == amount.roundToDouble();
  return amount.toStringAsFixed(whole ? 0 : 2);
}
