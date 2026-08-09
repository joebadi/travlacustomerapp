import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/features/auth/domain/app_user.dart';
import 'package:travla_customer_app/features/notifications/data/notification_repository.dart';
import 'package:travla_customer_app/features/notifications/domain/app_notification.dart';

class DashboardHeaderActions extends ConsumerWidget {
  const DashboardHeaderActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NotificationMenu(ref: ref),
        const SizedBox(width: 9),
        _ProfileMenu(ref: ref, user: user),
      ],
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

    return MenuAnchor(
      alignmentOffset: const Offset(-270, 8),
      style: _menuStyle(width: 318),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent notifications',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (unreadCount > 0)
                Text(
                  '$unreadCount unread',
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        ...notifications.when(
          loading: () => [
            const Padding(
              padding: EdgeInsets.all(24),
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
              return [
                const Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.muted,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "You're all caught up.",
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
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
                    onPressed: () => _openNotification(context, item),
                  ),
                )
                .toList(growable: false);
          },
        ),
        const Divider(height: 1),
        MenuItemButton(
          onPressed: () => context.push('/notifications'),
          child: const SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 5),
              child: Text(
                'View all notifications',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.forest700,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        return _HeaderActionButton(
          tooltip: 'Notifications',
          onTap: controller.isOpen ? controller.close : controller.open,
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
                      border: Border.all(
                        color: AppColors.forest800,
                        width: 1.5,
                      ),
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

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.ref, required this.user});

  final WidgetRef ref;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return MenuAnchor(
      alignmentOffset: const Offset(-235, 8),
      style: _menuStyle(width: 282),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
          child: Row(
            children: [
              _ProfileAvatar(user: user, radius: 23),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Travla customer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 13),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusPill(
                icon: user?.isVerified == true
                    ? Icons.verified_user_outlined
                    : Icons.info_outline_rounded,
                label: user?.isVerified == true
                    ? 'Account verified'
                    : 'Verification pending',
                isPositive: user?.isVerified == true,
              ),
              if ((user?.phone ?? '').isNotEmpty)
                _StatusPill(
                  icon: Icons.phone_outlined,
                  label: user!.phone,
                  isPositive: true,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.manage_accounts_outlined, size: 20),
          onPressed: () => context.go('/more/profile'),
          child: const Text('Account & security'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(
            Icons.logout_rounded,
            size: 20,
            color: AppColors.danger,
          ),
          onPressed: auth.isSubmitting
              ? null
              : () => ref.read(authControllerProvider.notifier).logout(),
          child: Text(
            auth.isSubmitting ? 'Signing out…' : 'Sign out',
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        return _HeaderActionButton(
          tooltip: 'Account menu',
          onTap: controller.isOpen ? controller.close : controller.open,
          child: _ProfileAvatar(user: user, radius: 16),
        );
      },
    );
  }
}

class _RecentNotificationItem extends StatelessWidget {
  const _RecentNotificationItem({required this.item, required this.onPressed});

  final AppNotification item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return AppColors.forest50;
          return item.isRead ? AppColors.white : AppColors.orangeSoft;
        }),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
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
            const SizedBox(width: 10),
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
                            fontSize: 11,
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
                      fontSize: 10,
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user, required this.radius});

  final AppUser? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = user?.profileImageUrl?.trim() ?? '';
    final size = radius * 2;

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.forest100,
        child: imageUrl.isEmpty
            ? _Initials(name: user?.fullName, fontSize: radius * .72)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _Initials(name: user?.fullName, fontSize: radius * .72),
              ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.fontSize});

  final String? name;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final words = (name ?? '').trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return Center(
      child: Text(
        initials.isEmpty ? 'T' : initials,
        style: TextStyle(
          color: AppColors.forest800,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.isPositive,
  });

  final IconData icon;
  final String label;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AppColors.forest700 : AppColors.orangeDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isPositive ? AppColors.forest50 : AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

MenuStyle _menuStyle({required double width}) {
  return MenuStyle(
    minimumSize: WidgetStatePropertyAll(Size(width, 0)),
    maximumSize: WidgetStatePropertyAll(Size(width, 520)),
    backgroundColor: const WidgetStatePropertyAll(AppColors.white),
    elevation: const WidgetStatePropertyAll(12),
    shadowColor: const WidgetStatePropertyAll(Color(0x33021B13)),
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );
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
