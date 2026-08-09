import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/home/presentation/dashboard_header_actions.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';
import 'package:travla_customer_app/shared/widgets/section_heading.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final wallet = user?.wallet;
    final garage = ref.watch(garageProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 18,
                20,
                28,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.forest950, AppColors.forest700],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const TravlaLogo(onDark: true, width: 124),
                      const Spacer(),
                      const DashboardHeaderActions(),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Good day, ${user?.firstName ?? 'there'}',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: AppColors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Everything about your vehicles, in one account.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .68),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .13),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wallet balance',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .65),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${wallet?.currency ?? 'NGN'} ${wallet?.balanceNaira ?? '0.00'}',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(color: AppColors.white),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
            sliver: SliverList.list(
              children: [
                _GarageOverview(
                  garage: garage,
                  onRetry: () => ref.invalidate(garageProvider),
                ),
                const SizedBox(height: 26),
                const SectionHeading(title: 'Quick access'),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.65,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _QuickAccess(
                      icon: Icons.description_outlined,
                      label: 'Renew papers',
                      onTap: () => context.go('/vehicles'),
                    ),
                    _QuickAccess(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Transfer vehicle',
                      onTap: () => context.go('/vehicles'),
                    ),
                    _QuickAccess(
                      icon: Icons.route_outlined,
                      label: 'Journeys',
                      onTap: () => context.go('/journeys'),
                    ),
                    _QuickAccess(
                      icon: Icons.assignment_add,
                      label: 'Register vehicle',
                      onTap: () => context.go('/vehicles/register-new'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GarageOverview extends StatelessWidget {
  const _GarageOverview({required this.garage, required this.onRetry});

  final AsyncValue<GarageSnapshot> garage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return garage.when(
      loading: () => const _HomeGarageLoading(),
      error: (error, stackTrace) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error is ApiFailure
                      ? error.message
                      : 'Vehicle readiness could not be loaded.',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              IconButton(
                tooltip: 'Try again',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
      ),
      data: (snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snapshot.pendingTransfers.isNotEmpty) ...[
            _HomeTransferAlert(transfer: snapshot.pendingTransfers.first),
            const SizedBox(height: 14),
          ],
          if (snapshot.vehicles.isEmpty) ...[
            Card(
              color: AppColors.orangeSoft,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.rocket_launch_outlined,
                      color: AppColors.orange,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start with your first vehicle',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Add a vehicle you already own or begin a new vehicle registration.',
                            style: TextStyle(
                              color: AppColors.muted,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () =>
                                context.go('/vehicles/add-existing'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.orangeDark,
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text('Add existing vehicle'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
          ],
          SectionHeading(
            title: 'Vehicle readiness',
            description: snapshot.vehicles.isEmpty
                ? 'Add a vehicle to begin tracking renewable papers.'
                : '${snapshot.vehicles.length} vehicle${snapshot.vehicles.length == 1 ? '' : 's'} monitored',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ReadinessMetric(
                  label: 'Up to date',
                  value: snapshot.validCount.toString(),
                  color: AppColors.forest600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReadinessMetric(
                  label: 'Expiring',
                  value: snapshot.expiringCount.toString(),
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReadinessMetric(
                  label: 'Expired',
                  value: snapshot.expiredCount.toString(),
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeTransferAlert extends StatelessWidget {
  const _HomeTransferAlert({required this.transfer});

  final IncomingTransferSummary transfer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC9B7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mark_email_unread_outlined, color: AppColors.orange),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incoming ownership transfer',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  '${transfer.currentOwnerName} has sent ${transfer.vehicleName.isEmpty ? 'a vehicle' : transfer.vehicleName} to you.',
                  style: const TextStyle(color: AppColors.muted, height: 1.45),
                ),
                const SizedBox(height: 9),
                TextButton(
                  onPressed: () => context.go('/vehicles'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.orangeDark,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'View incoming vehicle',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeGarageLoading extends StatelessWidget {
  const _HomeGarageLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 106,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 92,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ],
    );
  }
}

class _ReadinessMetric extends StatelessWidget {
  const _ReadinessMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 14),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.forest700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
