import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/features/support/presentation/support_floating_widget.dart';
import 'package:travla_customer_app/shared/widgets/profile_avatar.dart';

class CustomerShell extends ConsumerWidget {
  const CustomerShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _selectDestination(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final isTravlaMap = navigationShell.currentIndex == 2;

    return Scaffold(
      body: Stack(
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(navigationShell.currentIndex),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            child: navigationShell,
            builder: (context, value, child) {
              return Opacity(
                opacity: .72 + (.28 * value),
                child: Transform.translate(
                  offset: Offset(0, 7 * (1 - value)),
                  child: child,
                ),
              );
            },
          ),
          if (!isTravlaMap) const SupportFloatingWidget(),
        ],
      ),
      bottomNavigationBar: CustomerBottomBar(
        selectedIndex: navigationShell.currentIndex,
        onSelected: _selectDestination,
        profile: ProfileAvatar(user: user, radius: 12),
      ),
    );
  }
}

/// Gives authenticated pages that sit outside the indexed tab stacks the same
/// persistent customer chrome. This is useful for global destinations such as
/// Notifications: they should not lose the main navigation just because they
/// are not one of the five primary tabs.
class CustomerStandaloneShell extends ConsumerWidget {
  const CustomerStandaloneShell({required this.child, super.key});

  final Widget child;

  static const _destinations = <String>[
    '/home',
    '/vehicles',
    '/journeys',
    '/news',
    '/more',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      body: Stack(children: [child, const SupportFloatingWidget()]),
      bottomNavigationBar: CustomerBottomBar(
        selectedIndex: null,
        onSelected: (index) => context.go(_destinations[index]),
        profile: ProfileAvatar(user: user, radius: 12),
      ),
    );
  }
}

class CustomerBottomBar extends StatelessWidget {
  const CustomerBottomBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.profile,
    super.key,
  });

  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget profile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14021B13),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BottomDestination(
                label: 'Home',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
              _BottomDestination(
                label: 'Vehicles',
                icon: Icons.directions_car_outlined,
                selectedIcon: Icons.directions_car_filled_rounded,
                selected: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
              _JourneyDestination(
                selected: selectedIndex == 2,
                onTap: () => onSelected(2),
              ),
              _BottomDestination(
                label: 'Car Talk',
                icon: Icons.forum_outlined,
                selectedIcon: Icons.forum_rounded,
                selected: selectedIndex == 3,
                onTap: () => onSelected(3),
              ),
              _BottomDestination(
                label: 'Profile',
                iconWidget: profile,
                selected: selectedIndex == 4,
                onTap: () => onSelected(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomDestination extends StatelessWidget {
  const _BottomDestination({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.selectedIcon,
    this.iconWidget,
  });

  final String label;
  final IconData? icon;
  final IconData? selectedIcon;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange : AppColors.muted;
    final displayedIcon =
        iconWidget ??
        Icon(selected ? selectedIcon ?? icon : icon, size: 21, color: color);

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(3, 8, 3, 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 38,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.orangeSoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      border: iconWidget != null && selected
                          ? Border.all(color: AppColors.orange, width: 1.5)
                          : null,
                    ),
                    child: displayedIcon,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.forest900 : AppColors.muted,
                      fontSize: 9,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyDestination extends StatelessWidget {
  const _JourneyDestination({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Travla',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: -15,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    width: selected ? 58 : 54,
                    height: selected ? 58 : 54,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.forest600, AppColors.forest950],
                      ),
                      border: Border.all(
                        color: selected ? AppColors.orange : AppColors.white,
                        width: selected ? 2.5 : 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x38021B13),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/brand/travla-mark-white.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      semanticLabel: 'Travla map',
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  child: Text(
                    'Travla',
                    style: TextStyle(
                      color: selected ? AppColors.orange : AppColors.forest900,
                      fontSize: 9,
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
