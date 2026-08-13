import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/features/more/presentation/app_drawer.dart';
import 'package:travla_customer_app/features/support/presentation/support_floating_widget.dart';
import 'package:travla_customer_app/shared/widgets/profile_avatar.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The single Scaffold that owns the app's navigation drawer — every tab
/// root lives inside [navigationShell] as its body, and each of them opens
/// this SAME drawer via [openAppDrawer] rather than declaring their own
/// (nested Scaffolds don't share a drawer, so a single shared key is what
/// lets a hamburger button on any tab reach it).
final GlobalKey<ScaffoldState> customerShellScaffoldKey =
    GlobalKey<ScaffoldState>();

void openAppDrawer() {
  customerShellScaffoldKey.currentState?.openDrawer();
}

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

    return Scaffold(
      key: customerShellScaffoldKey,
      drawer: const AppDrawer(),
      body: Stack(children: [navigationShell, const SupportFloatingWidget()]),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _selectDestination,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon: Icon(Icons.directions_car_filled_rounded),
              label: 'Vehicles',
            ),
            const NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route_rounded),
              label: 'Journeys',
            ),
            const NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum_rounded),
              label: 'Car Talk',
            ),
            NavigationDestination(
              icon: ProfileAvatar(user: user, radius: 12),
              selectedIcon: ProfileAvatar(user: user, radius: 12),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
