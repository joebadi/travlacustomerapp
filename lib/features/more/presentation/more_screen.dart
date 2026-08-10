import 'package:flutter/material.dart';
import 'package:travla_customer_app/shared/widgets/travla_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    return Scaffold(
      appBar: const TravlaAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.forest100,
                    foregroundColor: AppColors.forest800,
                    child: Text(
                      _initials(user?.fullName),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Travla customer',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (user?.isFinancialIdentityVerified == true)
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.forest600,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _GroupLabel('SERVICES & RECORDS'),
          _MoreTile(
            icon: Icons.storefront_outlined,
            title: 'Marketplace',
            subtitle: 'Buy, sell and manage vehicle offers',
            onTap: () => context.go('/more/marketplace'),
          ),
          _MoreTile(
            icon: Icons.description_outlined,
            title: 'Renewals & registrations',
            subtitle: 'Vehicle papers, registration and driver’s licence',
            onTap: () => context.go('/more/renewals'),
          ),
          _MoreTile(
            icon: Icons.swap_horiz_rounded,
            title: 'Ownership transfers',
            subtitle: 'Sent, received and pending transfers',
            onTap: () => context.go('/more/transfers'),
          ),
          const _MoreTile(
            icon: Icons.shield_outlined,
            title: 'Insurance & claims',
            subtitle: 'Policies, renewals and claim records',
          ),
          const SizedBox(height: 18),
          const _GroupLabel('ACCOUNT'),
          _MoreTile(
            icon: Icons.receipt_long_outlined,
            title: 'Transactions',
            subtitle: 'Wallet funding and service payments',
            onTap: () => context.go('/more/transactions'),
          ),
          const _MoreTile(
            icon: Icons.support_agent_outlined,
            title: 'Support',
            subtitle: 'Get help from Travla',
          ),
          _MoreTile(
            icon: Icons.person_outline_rounded,
            title: 'Profile & security',
            subtitle: 'Identity, bank details and account settings',
            onTap: () => context.go('/more/profile'),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: auth.isSubmitting
                ? null
                : () => ref.read(authControllerProvider.notifier).logout(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: Color(0xFFF0C6C2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              'Sign out',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String? name) {
    final words = (name ?? '').trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return initials.isEmpty ? 'T' : initials;
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
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

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: onTap != null,
        onTap: onTap,
        leading: Icon(icon, color: AppColors.forest700),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
