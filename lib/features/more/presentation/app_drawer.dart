import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/features/fleet/data/fleet_mode.dart';
import 'package:travla_customer_app/shared/widgets/profile_avatar.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

/// The app's global navigation flyout — every section that isn't already a
/// bottom-nav tab (Home, Vehicles, Journeys, Car Talk, Profile). Opened from
/// the hamburger button that precedes the Travla wordmark on every tab root.
/// Menu items mirror the web's user sidebar (roleNav.ts), minus the entries
/// that already have a dedicated tab here (Profile, Car Talk/Forum/Stolen).
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final fleetMode = ref.watch(fleetModeProvider);

    void go(String path) {
      Navigator.of(context).pop();
      context.go(path);
    }

    return Drawer(
      backgroundColor: AppColors.canvas,
      width: MediaQuery.sizeOf(context).width * .84,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.forest950, AppColors.forest700],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TravlaLogo(onDark: true, width: 108),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      ProfileAvatar(user: user, radius: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user?.fullName ?? 'Travla customer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .68),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (user?.isVerified == true)
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF75DFB8),
                          size: 20,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile(
                      value: fleetMode,
                      activeThumbColor: AppColors.forest700,
                      onChanged: (v) =>
                          ref.read(fleetModeProvider.notifier).set(v),
                      secondary: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: fleetMode
                              ? AppColors.forest700
                              : AppColors.forest50,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.corporate_fare_rounded,
                          color: fleetMode ? Colors.white : AppColors.forest700,
                          size: 19,
                        ),
                      ),
                      title: Text(
                        fleetMode ? 'Fleet mode' : 'Individual mode',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        fleetMode
                            ? 'Managing a fleet company'
                            : 'Switch on to manage a fleet',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  if (fleetMode) ...[
                    const SizedBox(height: 8),
                    _DrawerTile(
                      icon: Icons.groups_2_outlined,
                      label: 'Fleet organisations',
                      onTap: () => go('/more/fleet'),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const _GroupLabel('VEHICLES & PAPERS'),
                  _DrawerTile(
                    icon: Icons.description_outlined,
                    label: 'Renewals & registrations',
                    onTap: () => go('/more/renewals'),
                  ),
                  _DrawerTile(
                    icon: Icons.assignment_add,
                    label: 'Register a new vehicle',
                    onTap: () => go('/vehicles/register-new'),
                  ),
                  _DrawerTile(
                    icon: Icons.badge_outlined,
                    label: "Driver's licence",
                    onTap: () => go('/more/drivers-license'),
                  ),
                  _DrawerTile(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Ownership transfers',
                    onTap: () => go('/more/transfers'),
                  ),
                  _DrawerTile(
                    icon: Icons.shield_outlined,
                    label: 'Insurance',
                    onTap: () => go('/more/insurance'),
                  ),
                  _DrawerTile(
                    icon: Icons.report_gmailerrorred_outlined,
                    label: 'Claims',
                    onTap: () => go('/more/claims'),
                  ),
                  _DrawerTile(
                    icon: Icons.location_on_outlined,
                    label: 'Vehicle tracking',
                    onTap: () => go('/more/tracking'),
                  ),
                  const SizedBox(height: 18),
                  const _GroupLabel('OTHER SERVICES'),
                  _DrawerTile(
                    icon: Icons.storefront_outlined,
                    label: 'Marketplace',
                    onTap: () => go('/more/marketplace'),
                  ),
                  const SizedBox(height: 18),
                  const _GroupLabel('ACCOUNT'),
                  _DrawerTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Transactions',
                    onTap: () => go('/more/transactions'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _DrawerTile(
                icon: Icons.logout_rounded,
                label: auth.isSubmitting ? 'Signing out…' : 'Sign out',
                danger: true,
                onTap: auth.isSubmitting
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        ref.read(authControllerProvider.notifier).logout();
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .9,
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.forest700;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: danger ? AppColors.danger : AppColors.ink,
          ),
        ),
        dense: true,
      ),
    );
  }
}
