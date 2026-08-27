import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/drivers_license/data/drivers_license_repository.dart';
import 'package:travla_customer_app/features/drivers_license/domain/drivers_license.dart';
import 'package:travla_customer_app/features/home/presentation/dashboard_header_actions.dart';
import 'package:travla_customer_app/features/home/presentation/dashboard_quick_actions.dart';
import 'package:travla_customer_app/features/insurance/data/insurance_repository.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';
import 'package:travla_customer_app/features/news/data/news_repository.dart';
import 'package:travla_customer_app/features/news/domain/news_models.dart';
import 'package:travla_customer_app/features/renewals/data/renewal_repository.dart';
import 'package:travla_customer_app/features/renewals/domain/renewal_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

/// Home dashboard — mirrors the web dashboard's information architecture:
/// hero + fleet cross-sell, a readiness donut + at-a-glance bars,
/// "needs attention", live renewals, quick actions, and recent road content.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final garage = ref.watch(garageProvider);
    final renewals = ref.watch(renewalOrdersProvider);
    final licenses = ref.watch(driversLicensesProvider);
    final expiringPolicies = ref.watch(expiringPoliciesProvider);
    const dashboardNewsQuery = NewsQuery();
    final recentNews = ref.watch(newsFeedProvider(dashboardNewsQuery));

    final activeRenewals = renewals.asData?.value
        .where((r) => !r.isCompleted && r.status != 'CANCELLED')
        .toList(growable: false);
    final licenseList = licenses.asData?.value;
    final snapshot = garage.asData?.value;

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: () async {
          ref.invalidate(garageProvider);
          ref.invalidate(renewalOrdersProvider);
          ref.invalidate(driversLicensesProvider);
          ref.invalidate(expiringPoliciesProvider);
          ref.invalidate(newsFeedProvider(dashboardNewsQuery));
          await ref.read(garageProvider.future).catchError((_) {
            throw Exception();
          });
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Hero(firstName: user?.firstName)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: SliverList.list(
                children: [
                  if (garage.isLoading && snapshot == null) ...[
                    const _DashboardLoadingSkeleton(),
                    const SizedBox(height: 16),
                  ],
                  if (garage.hasError && snapshot == null) ...[
                    _DashboardLoadError(
                      message: garage.error is ApiFailure
                          ? (garage.error as ApiFailure).message
                          : 'Your dashboard could not be loaded.',
                      onRetry: () => ref.invalidate(garageProvider),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (snapshot != null &&
                      snapshot.pendingTransfers.isNotEmpty) ...[
                    _HomeTransferAlert(
                      transfer: snapshot.pendingTransfers.first,
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (snapshot != null && snapshot.vehicles.isNotEmpty)
                    _ReadinessSection(snapshot: snapshot),

                  if (snapshot != null && snapshot.vehicles.isNotEmpty)
                    const SizedBox(height: 22),
                  DashboardQuickActions(
                    vehicles: snapshot?.vehicles ?? const [],
                  ),

                  const SizedBox(height: 22),
                  _NeedsAttentionCard(
                    snapshot: snapshot,
                    expiringPolicies: expiringPolicies.asData?.value,
                    licenses: licenseList,
                  ),
                  const SizedBox(height: 14),
                  _RenewalsInProgressCard(renewals: activeRenewals),

                  const SizedBox(height: 22),
                  _RecentBlogPostsSlider(
                    feed: recentNews,
                    onRetry: () =>
                        ref.invalidate(newsFeedProvider(dashboardNewsQuery)),
                  ),
                  const SizedBox(height: 22),
                  const _FleetCtaBanner(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* --------------------------------- Hero ---------------------------------- */

class _Hero extends StatelessWidget {
  const _Hero({required this.firstName});

  final String? firstName;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              const TravlaLogo(onDark: true, width: 116),
              const Spacer(),
              const DashboardHeaderActions(showWallet: true),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            'Good day, ${firstName ?? 'there'}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'See what needs attention, renew documents, and follow every order '
            'through to pickup or delivery.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: .68),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared green-gradient title bar for every dashboard section card — flush
/// against the white body below (no gap), so each section reads as header +
/// content the same way the vehicle Documents tab's sections do.
class _SectionHeaderBar extends StatelessWidget {
  const _SectionHeaderBar({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest700, AppColors.forest950],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .72),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/* ---------------------------- Readiness section ---------------------------- */

/// A donut chart of the fleet's document readiness (valid/expiring/expired)
/// alongside a compact bar comparing the four dashboard counts — the
/// "infographic" layer that makes the numbers legible at a glance. A chip
/// filter lets the reader narrow the donut from "all vehicles" down to one.
class _ReadinessSection extends StatefulWidget {
  const _ReadinessSection({required this.snapshot});

  final GarageSnapshot snapshot;

  @override
  State<_ReadinessSection> createState() => _ReadinessSectionState();
}

class _ReadinessSectionState extends State<_ReadinessSection> {
  String? _selectedVehicleId;

  @override
  Widget build(BuildContext context) {
    final vehicles = widget.snapshot.vehicles;
    final selected = _selectedVehicleId == null
        ? null
        : vehicles.where((v) => v.id == _selectedVehicleId).firstOrNull;
    // Reset the filter if the selected vehicle disappeared (e.g. removed).
    if (_selectedVehicleId != null && selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedVehicleId = null);
      });
    }

    final readiness =
        selected?.paperReadiness ?? widget.snapshot.paperReadiness;
    final valid = readiness.upToDate;
    final expiring = readiness.expiring;
    final expired = readiness.expired;
    final missing = readiness.missing;
    final total = readiness.total;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionHeaderBar(
            title: 'Vehicle readiness',
            subtitle: selected != null
                ? selected.displayName.isEmpty
                      ? 'Selected vehicle'
                      : selected.displayName
                : '${vehicles.length} vehicle${vehicles.length == 1 ? '' : 's'} monitored',
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (vehicles.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: _VehicleFilterDropdown(
                      vehicles: vehicles,
                      selectedId: _selectedVehicleId,
                      onSelect: (id) => setState(() => _selectedVehicleId = id),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (total == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Add papers to a vehicle to see its readiness here.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 132,
                        height: 132,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 42,
                                startDegreeOffset: -90,
                                sections: [
                                  if (valid > 0)
                                    PieChartSectionData(
                                      value: valid.toDouble(),
                                      color: AppColors.forest600,
                                      showTitle: false,
                                      radius: 24,
                                    ),
                                  if (expiring > 0)
                                    PieChartSectionData(
                                      value: expiring.toDouble(),
                                      color: AppColors.orange,
                                      showTitle: false,
                                      radius: 24,
                                    ),
                                  if (expired > 0)
                                    PieChartSectionData(
                                      value: expired.toDouble(),
                                      color: AppColors.danger,
                                      showTitle: false,
                                      radius: 24,
                                    ),
                                  if (missing > 0)
                                    PieChartSectionData(
                                      value: missing.toDouble(),
                                      color: const Color(0xFF9A6700),
                                      showTitle: false,
                                      radius: 24,
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$total',
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Text(
                                  'papers',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LegendRow(
                              color: AppColors.forest600,
                              label: 'Up to date',
                              value: valid,
                            ),
                            const SizedBox(height: 11),
                            _LegendRow(
                              color: AppColors.orange,
                              label: 'Expiring',
                              value: expiring,
                            ),
                            const SizedBox(height: 11),
                            _LegendRow(
                              color: AppColors.danger,
                              label: 'Expired',
                              value: expired,
                            ),
                            const SizedBox(height: 11),
                            _LegendRow(
                              color: const Color(0xFF9A6700),
                              label: 'Missing',
                              value: missing,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                // "Manage vehicles" anchored to the bottom-right of the card,
                // beneath the legend — leaving the top clear so the (bigger)
                // donut sits higher and reads as the focal point on the left.
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => context.go('/vehicles'),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                      child: Text(
                        'Manage vehicles →',
                        style: TextStyle(
                          color: AppColors.forest700,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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

/// A compact, right-aligned "All vehicles" + per-vehicle dropdown filter for
/// the readiness donut — replaces the earlier horizontal chip row.

/// "Model · PLATE" so two vehicles of the same model can be told apart at a
/// glance; the plate is dropped only when a vehicle has none on file.
String _vehicleLabel(VehicleSummary vehicle) {
  final name = vehicle.displayName.isEmpty ? 'Vehicle' : vehicle.displayName;
  final plate = vehicle.plateNumber?.trim();
  return (plate != null && plate.isNotEmpty) ? '$name · $plate' : name;
}

class _VehicleFilterDropdown extends StatelessWidget {
  const _VehicleFilterDropdown({
    required this.vehicles,
    required this.selectedId,
    required this.onSelect,
  });

  final List<VehicleSummary> vehicles;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedId,
          isDense: true,
          // Fill the card width so every option — and the plate beside each
          // model — stays fully visible, even in the open menu.
          isExpanded: true,
          alignment: Alignment.centerLeft,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.muted,
          ),
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All vehicles')),
            ...vehicles.map(
              (vehicle) => DropdownMenuItem(
                value: vehicle.id,
                child: Text(
                  _vehicleLabel(vehicle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onSelect,
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.ink, fontSize: 12.5),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/* ---------------------------- Needs attention ---------------------------- */

class _NeedsAttentionCard extends StatelessWidget {
  const _NeedsAttentionCard({
    required this.snapshot,
    required this.expiringPolicies,
    required this.licenses,
  });

  final GarageSnapshot? snapshot;
  final List<InsurancePolicy>? expiringPolicies;
  final List<DriversLicense>? licenses;

  @override
  Widget build(BuildContext context) {
    final items = <_AttentionItem>[];

    for (final vehicle in snapshot?.vehicles ?? const <VehicleSummary>[]) {
      if (vehicle.expiredDocumentsCount > 0) {
        items.add(
          _AttentionItem(
            title: 'Papers expired',
            subtitle:
                '${vehicle.displayName.isEmpty ? 'A vehicle' : vehicle.displayName} · ${vehicle.expiredDocumentsCount} document${vehicle.expiredDocumentsCount == 1 ? '' : 's'}',
            severe: true,
            onTap: () => context.push('/vehicles/${vehicle.id}?tab=documents'),
          ),
        );
      } else if (vehicle.expiringSoonCount > 0) {
        items.add(
          _AttentionItem(
            title: 'Papers expiring soon',
            subtitle:
                '${vehicle.displayName.isEmpty ? 'A vehicle' : vehicle.displayName} · ${vehicle.expiringSoonCount} document${vehicle.expiringSoonCount == 1 ? '' : 's'}',
            severe: false,
            onTap: () => context.push('/vehicles/${vehicle.id}?tab=documents'),
          ),
        );
      }
    }

    for (final policy in expiringPolicies ?? const <InsurancePolicy>[]) {
      final days = policy.daysToExpiry;
      items.add(
        _AttentionItem(
          title: 'Insurance policy expires soon',
          subtitle:
              '${policy.vehicleName ?? policy.provider ?? 'A vehicle'}${days != null ? ' · $days days left' : ''}',
          severe: false,
          onTap: () =>
              context.push('/vehicles/${policy.vehicleId}?tab=insurance'),
        ),
      );
    }

    for (final license in licenses ?? const <DriversLicense>[]) {
      final status = license.status;
      if (status == 'EXPIRED' || status == 'EXPIRING_SOON') {
        items.add(
          _AttentionItem(
            title: status == 'EXPIRED'
                ? "Driver's licence expired"
                : "Driver's licence expiring soon",
            subtitle: license.holderName,
            severe: status == 'EXPIRED',
            onTap: () => context.push('/more/drivers-license'),
          ),
        );
      }
    }

    items.sort((a, b) => (b.severe ? 1 : 0).compareTo(a.severe ? 1 : 0));
    final shown = items.take(4).toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionHeaderBar(
            title: 'Needs your attention',
            subtitle: 'Upcoming expiries and time-sensitive tasks.',
            trailing: shown.isEmpty
                ? null
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: shown.isEmpty
                ? Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.forest50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.forest700,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Nothing needs attention right now.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const Divider(height: 22),
                        _AttentionRow(item: shown[i]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AttentionItem {
  const _AttentionItem({
    required this.title,
    required this.subtitle,
    required this.severe,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool severe;
  final VoidCallback onTap;
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item});

  final _AttentionItem item;

  @override
  Widget build(BuildContext context) {
    final tone = item.severe ? AppColors.danger : AppColors.orangeDark;
    final bg = item.severe ? const Color(0xFFFFE3E1) : AppColors.orangeSoft;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.warning_amber_rounded, color: tone, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
            size: 18,
          ),
        ],
      ),
    );
  }
}

/* ------------------------------ In progress ------------------------------- */

class _RenewalsInProgressCard extends StatelessWidget {
  const _RenewalsInProgressCard({required this.renewals});

  final List<RenewalRecord>? renewals;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionHeaderBar(
            title: 'Renewals in progress',
            subtitle: 'Track your live orders.',
            trailing: TextButton(
              onPressed: () => context.push('/more/renewals'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View all',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: renewals == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : renewals!.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.autorenew_rounded,
                            color: AppColors.muted,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No active renewals',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => context.push('/more/renewals/new'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.forest700,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('Start one →'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final r in renewals!.take(3)) _RenewalRow(record: r),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RenewalRow extends StatelessWidget {
  const _RenewalRow({required this.record});

  final RenewalRecord record;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/more/renewals/orders/${record.orderGroupId}'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.forest50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.autorenew_rounded,
                color: AppColors.forest700,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.documentName.isEmpty
                        ? 'Renewal'
                        : record.documentName,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.vehicle?.displayName ?? 'Vehicle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              record.statusLabel,
              style: const TextStyle(
                color: AppColors.orangeDark,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- Recent blogs ------------------------------- */

class _RecentBlogPostsSlider extends StatefulWidget {
  const _RecentBlogPostsSlider({required this.feed, required this.onRetry});

  final AsyncValue<NewsPage> feed;
  final VoidCallback onRetry;

  @override
  State<_RecentBlogPostsSlider> createState() => _RecentBlogPostsSliderState();
}

class _RecentBlogPostsSliderState extends State<_RecentBlogPostsSlider> {
  late final PageController _controller;
  Timer? _autoPlay;
  int _current = 0;

  List<NewsArticle> get _articles =>
      widget.feed.asData?.value.articles.take(6).toList(growable: false) ??
      const [];

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: .9);
    _autoPlay = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients || _articles.length < 2) return;
      final next = (_current + 1) % _articles.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubicEmphasized,
      );
    });
  }

  @override
  void didUpdateWidget(covariant _RecentBlogPostsSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_articles.isNotEmpty && _current >= _articles.length) {
      _current = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) _controller.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent blog posts',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'News, guides and updates for Nigerian roads.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.go('/news'),
              child: const Text(
                'View all',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        widget.feed.when(
          loading: () => const _BlogSliderSkeleton(),
          error: (_, _) => _BlogSliderError(onRetry: widget.onRetry),
          data: (page) => page.articles.isEmpty
              ? const _EmptyBlogSlider()
              : Column(
                  children: [
                    SizedBox(
                      height: 236,
                      child: PageView.builder(
                        controller: _controller,
                        clipBehavior: Clip.none,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _articles.length,
                        onPageChanged: (index) =>
                            setState(() => _current = index),
                        itemBuilder: (context, index) {
                          return AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              var pageValue = _current.toDouble();
                              if (_controller.hasClients &&
                                  _controller.position.haveDimensions) {
                                pageValue = _controller.page ?? pageValue;
                              }
                              final distance = (pageValue - index).abs().clamp(
                                0.0,
                                1.0,
                              );
                              final scale = 1 - (distance * .045);
                              return Transform.scale(
                                scale: scale,
                                alignment: Alignment.centerLeft,
                                child: Opacity(
                                  opacity: 1 - (distance * .18),
                                  child: child,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _BlogSlide(article: _articles[index]),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_articles.length > 1) ...[
                      const SizedBox(height: 11),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _articles.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            width: index == _current ? 20 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: index == _current
                                  ? AppColors.orange
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _BlogSlide extends StatelessWidget {
  const _BlogSlide({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forest950,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/news/${article.slug}'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (article.coverImageUrl?.isNotEmpty == true)
              Image.network(
                article.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _BlogImageFallback(),
              )
            else
              const _BlogImageFallback(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .38, 1],
                  colors: [
                    Color(0x12000000),
                    Color(0x6B021B13),
                    Color(0xFA021B13),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.category?.isNotEmpty == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        article.category!.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .65,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_formatBlogDate(article.publishedAt)} · ${article.readingMinutes} min read',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .67),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF75DFB8),
                        size: 19,
                      ),
                    ],
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

class _BlogImageFallback extends StatelessWidget {
  const _BlogImageFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest700, AppColors.forest950],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.newspaper_rounded,
          color: Color(0xFF75DFB8),
          size: 42,
        ),
      ),
    );
  }
}

class _BlogSliderSkeleton extends StatelessWidget {
  const _BlogSliderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 236,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _BlogSliderError extends StatelessWidget {
  const _BlogSliderError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.muted),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Recent posts could not be loaded.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyBlogSlider extends StatelessWidget {
  const _EmptyBlogSlider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'New road stories will appear here.',
        style: TextStyle(color: AppColors.muted, fontSize: 12.5),
      ),
    );
  }
}

String _formatBlogDate(DateTime? value) {
  if (value == null) return 'Recently';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

/* ------------------------------- Shared bits -------------------------------- */

/// Skeleton shown while the garage snapshot (the primary dashboard dataset)
/// is loading for the first time.
class _DashboardLoadingSkeleton extends StatelessWidget {
  const _DashboardLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height) => Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(16),
      ),
    );

    return Column(
      children: [block(210), const SizedBox(height: 12), block(140)],
    );
  }
}

class _DashboardLoadError extends StatelessWidget {
  const _DashboardLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
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

/* ----------------------------- Fleet CTA banner ---------------------------- */

/// Closing cross-sell at the very bottom of the dashboard — a dark, premium
/// banner with a large decorative watermark icon, distinct from the white
/// data cards above it so it reads as a deliberate final pitch rather than
/// another section.
class _FleetCtaBanner extends StatelessWidget {
  const _FleetCtaBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Oversized watermark icon bleeding off the corner for visual depth.
          Positioned(
            right: -22,
            top: -22,
            child: Icon(
              Icons.corporate_fare_rounded,
              size: 140,
              color: Colors.white.withValues(alpha: .06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Running more than one vehicle?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bring your fleet onto one dashboard — drivers, fuel, '
                  'regions, live tracking, and team access, all in one place.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/more/fleet'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.forest950,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text(
                      'Explore Fleet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
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
