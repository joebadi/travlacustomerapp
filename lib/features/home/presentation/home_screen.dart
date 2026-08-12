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
import 'package:travla_customer_app/features/insurance/data/insurance_repository.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';
import 'package:travla_customer_app/features/notifications/data/notification_repository.dart';
import 'package:travla_customer_app/features/notifications/domain/app_notification.dart';
import 'package:travla_customer_app/features/renewals/data/renewal_repository.dart';
import 'package:travla_customer_app/features/renewals/domain/renewal_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

/// Home dashboard — mirrors the web dashboard's information architecture:
/// hero + fleet cross-sell, KPI tiles, a readiness donut + at-a-glance bars,
/// "needs attention" and "renewals in progress" panels, and latest updates.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final garage = ref.watch(garageProvider);
    final renewals = ref.watch(renewalOrdersProvider);
    final licenses = ref.watch(driversLicensesProvider);
    final expiringPolicies = ref.watch(expiringPoliciesProvider);
    final notifications = ref.watch(notificationsProvider);

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
          ref.invalidate(notificationsProvider);
          await ref.read(garageProvider.future).catchError((_) {
            throw Exception();
          });
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Hero(firstName: user?.firstName),
            ),
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
                    _HomeTransferAlert(transfer: snapshot.pendingTransfers.first),
                    const SizedBox(height: 16),
                  ],

                  // KPI tiles — mirrors the web's Vehicles / Papers to review /
                  // Active renewals / Driver's licences row.
                  _StatGrid(
                    vehicleCount: snapshot?.vehicles.length ?? 0,
                    papersToReview:
                        (snapshot?.expiringCount ?? 0) +
                        (snapshot?.expiredCount ?? 0),
                    activeRenewals: activeRenewals?.length ?? 0,
                    licenseCount: licenseList?.length ?? 0,
                  ),

                  if (snapshot != null && snapshot.vehicles.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _ReadinessSection(snapshot: snapshot),
                  ],

                  const SizedBox(height: 22),
                  _NeedsAttentionCard(
                    snapshot: snapshot,
                    expiringPolicies: expiringPolicies.asData?.value,
                    licenses: licenseList,
                  ),
                  const SizedBox(height: 14),
                  _RenewalsInProgressCard(renewals: activeRenewals),

                  const SizedBox(height: 22),
                  _LatestUpdatesCard(
                    snapshot: notifications.asData?.value,
                    isLoading: notifications.isLoading,
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
              const TravlaLogo(onDark: true, width: 124),
              const Spacer(),
              const DashboardHeaderActions(),
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
  const _SectionHeaderBar({
    required this.title,
    this.subtitle,
    this.trailing,
  });

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

/* ------------------------------- KPI tiles -------------------------------- */

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.vehicleCount,
    required this.papersToReview,
    required this.activeRenewals,
    required this.licenseCount,
  });

  final int vehicleCount;
  final int papersToReview;
  final int activeRenewals;
  final int licenseCount;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTile(
        icon: Icons.directions_car_filled_outlined,
        iconColor: AppColors.forest700,
        iconBg: AppColors.forest50,
        label: 'Vehicles',
        value: '$vehicleCount',
        caption: 'on your account',
      ),
      _StatTile(
        icon: Icons.description_outlined,
        iconColor: AppColors.forest700,
        iconBg: AppColors.forest50,
        label: 'Papers to review',
        value: '$papersToReview',
        caption: papersToReview == 0 ? 'everything looks current' : 'need attention',
      ),
      _StatTile(
        icon: Icons.autorenew_rounded,
        iconColor: const Color(0xFF2F6FEB),
        iconBg: const Color(0xFFE7EDFB),
        label: 'Active renewals',
        value: '$activeRenewals',
        caption: activeRenewals == 0 ? 'no orders in progress' : 'in progress',
      ),
      _StatTile(
        icon: Icons.badge_outlined,
        iconColor: const Color(0xFF2F6FEB),
        iconBg: const Color(0xFFE7EDFB),
        label: "Driver's licences",
        value: '$licenseCount',
        caption: licenseCount == 0 ? 'none added yet' : 'on record',
      ),
    ];

    // A hand-rolled 2-column grid (IntrinsicHeight rows, no fixed aspect
    // ratio) rather than GridView.count — GridView forces every cell into an
    // exact height derived from childAspectRatio, and that height doesn't
    // grow with the system font-scale setting, so long captions or a larger
    // accessibility text size can overflow it. Letting each tile size to its
    // own content makes that class of overflow impossible.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < tiles.length
                      ? tiles[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
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

    final int valid;
    final int expiring;
    final int expired;
    if (selected != null) {
      expired = selected.expiredDocumentsCount;
      expiring = selected.expiringSoonCount;
      valid = (selected.documentsCount - expired - expiring).clamp(
        0,
        selected.documentsCount,
      );
    } else {
      valid = widget.snapshot.validCount;
      expiring = widget.snapshot.expiringCount;
      expired = widget.snapshot.expiredCount;
    }
    final total = valid + expiring + expired;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _VehicleFilterDropdown(
                          vehicles: vehicles,
                          selectedId: _selectedVehicleId,
                          onSelect: (id) =>
                              setState(() => _selectedVehicleId = id),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => context.go('/vehicles'),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'Manage vehicles →',
                              style: TextStyle(
                                color: AppColors.forest700,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                        width: 108,
                        height: 108,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 34,
                                startDegreeOffset: -90,
                                sections: [
                                  if (valid > 0)
                                    PieChartSectionData(
                                      value: valid.toDouble(),
                                      color: AppColors.forest600,
                                      showTitle: false,
                                      radius: 18,
                                    ),
                                  if (expiring > 0)
                                    PieChartSectionData(
                                      value: expiring.toDouble(),
                                      color: AppColors.orange,
                                      showTitle: false,
                                      radius: 18,
                                    ),
                                  if (expired > 0)
                                    PieChartSectionData(
                                      value: expired.toDouble(),
                                      color: AppColors.danger,
                                      showTitle: false,
                                      radius: 18,
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Text(
                                  'papers',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LegendRow(
                              color: AppColors.forest600,
                              label: 'Up to date',
                              value: valid,
                            ),
                            const SizedBox(height: 9),
                            _LegendRow(
                              color: AppColors.orange,
                              label: 'Expiring',
                              value: expiring,
                            ),
                            const SizedBox(height: 9),
                            _LegendRow(
                              color: AppColors.danger,
                              label: 'Expired',
                              value: expired,
                            ),
                          ],
                        ),
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

/// A compact, right-aligned "All vehicles" + per-vehicle dropdown filter for
/// the readiness donut — replaces the earlier horizontal chip row.
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
          alignment: Alignment.centerRight,
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
                  vehicle.displayName.isEmpty
                      ? (vehicle.plateNumber ?? 'Vehicle')
                      : vehicle.displayName,
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
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
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
                  style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 18),
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
              child: const Icon(Icons.autorenew_rounded, color: AppColors.forest700, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.documentName.isEmpty ? 'Renewal' : record.documentName,
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
                    style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
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

/* ----------------------------- Latest updates ------------------------------ */

class _LatestUpdatesCard extends StatelessWidget {
  const _LatestUpdatesCard({required this.snapshot, required this.isLoading});

  final NotificationSnapshot? snapshot;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final items = snapshot?.items.take(3).toList(growable: false) ?? const [];

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
            title: 'Latest updates',
            subtitle: 'From renewals, documents, and deliveries.',
            trailing: TextButton(
              onPressed: () => context.push('/notifications'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'All updates',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: isLoading && snapshot == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'No updates yet.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const Divider(height: 20),
                        _UpdateRow(notification: items[i]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _UpdateRow extends StatelessWidget {
  const _UpdateRow({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final destination = nativeNotificationPath(notification.actionUrl);

    return InkWell(
      onTap: destination == null ? null : () => context.push(destination),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: notification.isRead ? AppColors.border : AppColors.forest600,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
      children: [
        block(210),
        const SizedBox(height: 12),
        block(140),
      ],
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
              child: Text(message, style: const TextStyle(color: AppColors.muted)),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.orange.withValues(alpha: .4),
                    ),
                  ),
                  child: const Text(
                    'FOR BUSINESSES',
                    style: TextStyle(
                      color: AppColors.orange,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
