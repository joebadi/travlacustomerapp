import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/data/fleet_repository.dart';
import 'package:travla_customer_app/features/fleet/domain/fleet_models.dart';

class FleetVehicleScreen extends ConsumerWidget {
  const FleetVehicleScreen({
    super.key,
    required this.organisationId,
    required this.orgVehicleId,
  });

  final String organisationId;
  final String orgVehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (organisationId: organisationId, orgVehicleId: orgVehicleId);
    final vehicle = ref.watch(fleetVehicleProvider(key));
    final capabilities = ref
        .watch(fleetOrgProvider(organisationId))
        .value
        ?.capabilities;
    final organisation = ref.watch(fleetOrgProvider(organisationId)).value;
    final canManageDrivers = capabilities?.manageDrivers ?? false;
    final canManageVehicles = capabilities?.manageVehicles ?? false;
    final canLeaveRegionUnassigned = capabilities?.seesAllRegions ?? false;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Fleet vehicle')),
      body: vehicle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiFailure
              ? error.message
              : 'This Fleet vehicle could not be loaded.',
          onRetry: () => ref.invalidate(fleetVehicleProvider(key)),
        ),
        data: (item) => RefreshIndicator(
          color: AppColors.forest700,
          onRefresh: () async {
            ref.invalidate(fleetVehicleProvider(key));
            await ref.read(fleetVehicleProvider(key).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _VehicleHero(vehicle: item),
              const SizedBox(height: 14),
              _ReadinessCard(vehicle: item),
              if (!item.documentAccess || item.documents.isNotEmpty) ...[
                const SizedBox(height: 14),
                _DocumentsCard(
                  vehicle: item,
                  onRenew: (document) => _openRenewal(context, item, document),
                ),
              ],
              const SizedBox(height: 14),
              _OperationsCard(
                vehicle: item,
                onEditPlacement: canManageVehicles
                    ? () => _editPlacement(
                        context,
                        ref,
                        item,
                        canLeaveRegionUnassigned: canLeaveRegionUnassigned,
                      )
                    : null,
                onAssignDriver: canManageDrivers
                    ? () => _assignDriver(context, ref, item)
                    : null,
              ),
              if (item.allocationBalanceNaira != null ||
                  item.cardNumber != null ||
                  item.cardLastFour != null) ...[
                const SizedBox(height: 14),
                _FuelCard(
                  vehicle: item,
                  fundingModel: organisation?.fundingModel,
                  monthlyAllocationNaira: organisation?.monthlyAllocationNaira,
                  onIssueCard:
                      (capabilities?.manageFuelCards ?? false) &&
                          item.cardNumber == null &&
                          item.cardLastFour == null
                      ? () => _issueFuelCard(context, ref, item)
                      : null,
                  onTopUpAllocation:
                      (capabilities?.manageVehicleAllocations ?? false) &&
                          organisation?.fundingModel != 'SHARED'
                      ? () => _topUpAllocation(
                          context,
                          ref,
                          item,
                          organisation?.fuelAvailableNaira ?? '0.00',
                        )
                      : null,
                ),
              ],
              if (item.canOpen && item.vehicleId != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => context.push('/vehicles/${item.vehicleId}'),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open personal vehicle workspace'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openRenewal(
    BuildContext context,
    OrgVehicle vehicle,
    FleetVehicleDocument document,
  ) {
    final vehicleId = vehicle.vehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;
    context.push(
      Uri(
        path: '/more/renewals/new',
        queryParameters: {
          'vehicle': vehicleId,
          'type': document.type,
          'fleet_org': organisationId,
        },
      ).toString(),
    );
  }

  Future<void> _issueFuelCard(
    BuildContext context,
    WidgetRef ref,
    OrgVehicle vehicle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Issue fuel card?'),
        content: Text(
          'Create an active Fleet fuel card for ${vehicle.plateNumber ?? vehicle.name}. The card will be tied to this vehicle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Issue card'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final receipt = await ref
          .read(fleetRepositoryProvider)
          .issueFuelCard(organisationId, orgVehicleId);
      _refreshVehicleFuel(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Fuel card •••• ${receipt.cardLastFour} is now active.',
            ),
          ),
        );
    } on ApiFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _topUpAllocation(
    BuildContext context,
    WidgetRef ref,
    OrgVehicle vehicle,
    String fleetAvailableNaira,
  ) async {
    final receipt = await showModalBottomSheet<FleetAllocationReceipt>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      builder: (_) => _TopUpAllocationSheet(
        organisationId: organisationId,
        orgVehicleId: orgVehicleId,
        vehicleLabel: vehicle.plateNumber ?? vehicle.name,
        currentAllocationNaira: vehicle.allocationBalanceNaira ?? '0.00',
        fleetAvailableNaira: fleetAvailableNaira,
      ),
    );
    if (receipt == null || !context.mounted) return;
    _refreshVehicleFuel(ref);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '₦${receipt.grantedNaira} allocated. Vehicle balance: ₦${receipt.allocationBalanceNaira}.',
          ),
        ),
      );
  }

  void _refreshVehicleFuel(WidgetRef ref) {
    ref.invalidate(
      fleetVehicleProvider((
        organisationId: organisationId,
        orgVehicleId: orgVehicleId,
      )),
    );
    ref.invalidate(fleetOrgProvider(organisationId));
    ref.invalidate(fleetDashboardProvider(organisationId));
    ref.invalidate(fleetFuelSummaryProvider(organisationId));
  }

  Future<void> _assignDriver(
    BuildContext context,
    WidgetRef ref,
    OrgVehicle vehicle,
  ) async {
    final choice = await showModalBottomSheet<_DriverChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AssignDriverSheet(
        organisationId: organisationId,
        currentDriverId: vehicle.driverId,
      ),
    );
    if (choice == null || !context.mounted) return;

    try {
      await ref
          .read(fleetRepositoryProvider)
          .assignDriver(organisationId, orgVehicleId, choice.driverId);
      ref.invalidate(
        fleetVehicleProvider((
          organisationId: organisationId,
          orgVehicleId: orgVehicleId,
        )),
      );
      ref.invalidate(fleetDashboardProvider(organisationId));
      ref.invalidate(fleetOrgProvider(organisationId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              choice.driverId == null
                  ? 'Driver removed from this vehicle.'
                  : '${choice.driverName} is now assigned to this vehicle.',
            ),
          ),
        );
    } on ApiFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _editPlacement(
    BuildContext context,
    WidgetRef ref,
    OrgVehicle vehicle, {
    required bool canLeaveRegionUnassigned,
  }) async {
    final choice = await showModalBottomSheet<_PlacementChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditPlacementSheet(
        organisationId: organisationId,
        currentRegionId: vehicle.regionId,
        currentDepartment: vehicle.department,
        canLeaveRegionUnassigned: canLeaveRegionUnassigned,
      ),
    );
    if (choice == null || !context.mounted) return;

    try {
      await ref
          .read(fleetRepositoryProvider)
          .updateVehiclePlacement(
            organisationId,
            orgVehicleId,
            regionId: choice.regionId,
            department: choice.department,
          );
      ref.invalidate(
        fleetVehicleProvider((
          organisationId: organisationId,
          orgVehicleId: orgVehicleId,
        )),
      );
      ref.invalidate(fleetDashboardProvider(organisationId));
      ref.invalidate(fleetOrgProvider(organisationId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Vehicle placement updated.')),
        );
    } on ApiFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _PlacementChoice {
  const _PlacementChoice({required this.regionId, required this.department});

  final String? regionId;
  final String? department;
}

class _EditPlacementSheet extends ConsumerStatefulWidget {
  const _EditPlacementSheet({
    required this.organisationId,
    required this.currentRegionId,
    required this.currentDepartment,
    required this.canLeaveRegionUnassigned,
  });

  final String organisationId;
  final String? currentRegionId;
  final String? currentDepartment;
  final bool canLeaveRegionUnassigned;

  @override
  ConsumerState<_EditPlacementSheet> createState() =>
      _EditPlacementSheetState();
}

class _EditPlacementSheetState extends ConsumerState<_EditPlacementSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _department;
  String? _regionId;

  @override
  void initState() {
    super.initState();
    _regionId = widget.currentRegionId;
    _department = TextEditingController(text: widget.currentDepartment);
  }

  @override
  void dispose() {
    _department.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _PlacementChoice(
        regionId: _regionId,
        department: _department.text.trim().isEmpty
            ? null
            : _department.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regions = ref.watch(fleetRegionsProvider(widget.organisationId));
    final visibleRegions = regions.value;
    final regionChanged = _regionId != widget.currentRegionId;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehicle placement',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose where this vehicle operates. Region changes also affect which Fleet members can see it.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'OPERATING REGION',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: regions.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _SheetMessage(
                      message: error is ApiFailure
                          ? error.message
                          : 'Fleet regions could not be loaded.',
                      onRetry: () => ref.invalidate(
                        fleetRegionsProvider(widget.organisationId),
                      ),
                    ),
                    data: (items) => ListView(
                      children: [
                        if (widget.canLeaveRegionUnassigned)
                          _RegionChoiceTile(
                            title: 'No assigned region',
                            subtitle: 'Visible only to all-region roles',
                            selected: _regionId == null,
                            icon: Icons.location_off_outlined,
                            onTap: () => setState(() => _regionId = null),
                          ),
                        ...items.map(
                          (region) => _RegionChoiceTile(
                            title: region.name,
                            subtitle: region.state?.isNotEmpty == true
                                ? region.state!
                                : 'Operating region',
                            selected: _regionId == region.id,
                            icon: Icons.location_on_outlined,
                            onTap: () => setState(() => _regionId = region.id),
                          ),
                        ),
                        if (items.isEmpty && !widget.canLeaveRegionUnassigned)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No region is available in your access scope. Ask the Fleet owner to configure your region access.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _department,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Department (optional)',
                    hintText: 'e.g. Logistics',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                    counterText: '',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) > 80
                      ? 'Use 80 characters or fewer.'
                      : null,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        visibleRegions != null &&
                            (widget.canLeaveRegionUnassigned ||
                                _regionId != null)
                        ? _save
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.forest700,
                    ),
                    icon: Icon(
                      regionChanged
                          ? Icons.swap_horiz_rounded
                          : Icons.check_rounded,
                    ),
                    label: Text(
                      regionChanged ? 'Confirm region move' : 'Save placement',
                      style: const TextStyle(fontWeight: FontWeight.w900),
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

class _RegionChoiceTile extends StatelessWidget {
  const _RegionChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.forest700.withValues(alpha: .08)
            : AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? AppColors.forest700
                    : AppColors.ink.withValues(alpha: .1),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? AppColors.forest700 : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? AppColors.forest700 : AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverChoice {
  const _DriverChoice(this.driverId, this.driverName);

  final String? driverId;
  final String driverName;
}

class _AssignDriverSheet extends ConsumerStatefulWidget {
  const _AssignDriverSheet({
    required this.organisationId,
    required this.currentDriverId,
  });

  final String organisationId;
  final String? currentDriverId;

  @override
  ConsumerState<_AssignDriverSheet> createState() => _AssignDriverSheetState();
}

class _AssignDriverSheetState extends ConsumerState<_AssignDriverSheet> {
  final _search = TextEditingController();
  late Future<FleetDriversPage> _drivers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    _drivers = ref
        .read(fleetRepositoryProvider)
        .drivers(widget.organisationId, query: _search.text);
  }

  void _searchDrivers() {
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .66,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign driver',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Only drivers inside your permitted Fleet regions are shown.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchDrivers(),
                decoration: InputDecoration(
                  hintText: 'Search driver, phone or licence',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: _searchDrivers,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<FleetDriversPage>(
                  future: _drivers,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      return _SheetMessage(
                        message: error is ApiFailure
                            ? error.message
                            : 'Drivers could not be loaded.',
                        onRetry: _searchDrivers,
                      );
                    }
                    final drivers =
                        snapshot.data?.items ?? const <FleetDriver>[];
                    return ListView(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: const _DriverAvatar(
                            icon: Icons.person_off_outlined,
                            color: AppColors.muted,
                          ),
                          title: const Text(
                            'No assigned driver',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text('Leave this vehicle unassigned'),
                          trailing: widget.currentDriverId == null
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.forest700,
                                )
                              : null,
                          onTap: () => Navigator.of(
                            context,
                          ).pop(const _DriverChoice(null, 'No driver')),
                        ),
                        const Divider(),
                        if (drivers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: Text(
                              'No drivers match this search. Driver records are created from the web control plane.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          )
                        else
                          ...drivers.map(
                            (driver) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              leading: const _DriverAvatar(
                                icon: Icons.person_outline_rounded,
                                color: AppColors.forest700,
                              ),
                              title: Text(
                                driver.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                [
                                      if (driver.region != null)
                                        driver.region!.name,
                                      if (driver.licenseNumber?.isNotEmpty ==
                                          true)
                                        driver.licenseNumber!,
                                    ].join(' · ').isEmpty
                                    ? 'Region not assigned'
                                    : [
                                        if (driver.region != null)
                                          driver.region!.name,
                                        if (driver.licenseNumber?.isNotEmpty ==
                                            true)
                                          driver.licenseNumber!,
                                      ].join(' · '),
                              ),
                              trailing: driver.id == widget.currentDriverId
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.forest700,
                                    )
                                  : const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.of(
                                context,
                              ).pop(_DriverChoice(driver.id, driver.fullName)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _VehicleHero extends StatelessWidget {
  const _VehicleHero({required this.vehicle});

  final OrgVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: vehicle.imageUrl == null
                ? const Icon(
                    Icons.directions_car_filled_outlined,
                    color: Colors.white,
                  )
                : Image.network(vehicle.imageUrl!, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.plateNumber ?? 'Plate unavailable',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [vehicle.name, vehicle.year, vehicle.color]
                      .where((value) => value != null && '$value'.isNotEmpty)
                      .join(' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          _LiveBadge(vehicle: vehicle),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.vehicle});

  final OrgVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final label = vehicle.isLive
        ? 'Live'
        : vehicle.hasTracker
        ? 'Offline'
        : 'No tracker';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.vehicle});

  final OrgVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Document readiness',
      icon: Icons.fact_check_outlined,
      children: [
        _Line('Status', vehicle.complianceLabel ?? 'Not available'),
        _Line('Renewable papers', '${vehicle.renewableDocumentsCount}'),
        _Line('Expired', '${vehicle.expiredDocumentsCount}'),
        _Line('Expiring soon', '${vehicle.expiringSoonCount}'),
        _Line('Next expiry', vehicle.nextExpiryDate ?? 'Not recorded'),
        if (vehicle.missingRequiredDocuments.isNotEmpty) ...[
          const Divider(height: 24),
          const Text(
            'Missing required papers',
            style: TextStyle(
              color: AppColors.orangeDark,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          ...vehicle.missingRequiredDocuments.map(
            (paper) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $paper',
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({required this.vehicle, required this.onRenew});

  final OrgVehicle vehicle;
  final ValueChanged<FleetVehicleDocument> onRenew;

  @override
  Widget build(BuildContext context) {
    if (!vehicle.documentAccess) {
      return const _Panel(
        title: 'Renewable papers',
        icon: Icons.description_outlined,
        children: [
          Text(
            'The vehicle owner has not granted this Fleet access to document details or renewal planning.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
          ),
        ],
      );
    }

    return _Panel(
      title: 'Renewable papers',
      icon: Icons.description_outlined,
      children: [
        ...vehicle.documents.indexed.map((entry) {
          final index = entry.$1;
          final document = entry.$2;
          return Column(
            children: [
              if (index > 0) const Divider(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.name,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _documentTiming(document),
                          style: TextStyle(
                            color: document.status == 'EXPIRED'
                                ? AppColors.orangeDark
                                : AppColors.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (document.canRenewDirectly)
                    TextButton(
                      onPressed: () => onRenew(document),
                      child: const Text('Renew now'),
                    )
                  else
                    _RenewalState(action: document.renewalAction),
                ],
              ),
            ],
          );
        }),
        if (!vehicle.renewalAccess) ...[
          const SizedBox(height: 10),
          const Text(
            'Renewal permission was not included in the owner’s Fleet consent.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ],
    );
  }

  static String _documentTiming(FleetVehicleDocument document) {
    final days = document.daysUntilExpiry;
    if (document.status == 'PENDING_RENEWAL') return 'Renewal in progress';
    if (days == null) return document.statusLabel;
    if (days < 0) return '${document.statusLabel} · ${days.abs()} days ago';
    if (days == 0) return '${document.statusLabel} · expires today';
    return '${document.statusLabel} · $days days remaining';
  }
}

class _RenewalState extends StatelessWidget {
  const _RenewalState({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    final label = switch (action) {
      'OWNER_REQUIRED' => 'Owner action',
      'IN_PROGRESS' => 'In progress',
      'RESTRICTED' => 'Restricted',
      _ => 'Not due',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OperationsCard extends StatelessWidget {
  const _OperationsCard({
    required this.vehicle,
    this.onEditPlacement,
    this.onAssignDriver,
  });

  final OrgVehicle vehicle;
  final VoidCallback? onEditPlacement;
  final VoidCallback? onAssignDriver;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Operations',
      icon: Icons.route_outlined,
      children: [
        _Line('Region', vehicle.regionName ?? 'Unassigned'),
        _Line('Department', vehicle.department ?? 'Unassigned'),
        _Line('Driver', vehicle.driverName ?? 'Unassigned'),
        _Line(
          'Tracking',
          vehicle.isLive
              ? 'Reporting live'
              : vehicle.hasTracker
              ? 'Tracker offline'
              : 'Not configured',
        ),
        if (vehicle.lastPositionAt != null)
          _Line('Last position', vehicle.lastPositionAt!),
        if (onEditPlacement != null) ...[
          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEditPlacement,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: const Text('Edit region & department'),
            ),
          ),
        ],
        if (onAssignDriver != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAssignDriver,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(
                vehicle.driverId == null ? 'Assign driver' : 'Change driver',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FuelCard extends StatelessWidget {
  const _FuelCard({
    required this.vehicle,
    required this.fundingModel,
    required this.monthlyAllocationNaira,
    this.onIssueCard,
    this.onTopUpAllocation,
  });

  final OrgVehicle vehicle;
  final String? fundingModel;
  final String? monthlyAllocationNaira;
  final VoidCallback? onIssueCard;
  final VoidCallback? onTopUpAllocation;

  @override
  Widget build(BuildContext context) {
    final cardLastFour = vehicle.cardLastFour ?? _lastFour(vehicle.cardNumber);
    return _Panel(
      title: 'Fuel controls',
      icon: Icons.local_gas_station_outlined,
      children: [
        _Line(
          'Fuel card',
          cardLastFour == null ? 'Not issued' : '•••• $cardLastFour',
        ),
        _Line('Card status', vehicle.cardStatus ?? 'Not active'),
        _Line('Funding model', _fundingModelLabel(fundingModel)),
        _Line(
          'Available allocation',
          vehicle.allocationBalanceNaira == null
              ? 'Not available'
              : '₦${vehicle.allocationBalanceNaira}',
        ),
        _Line(
          'Vehicle monthly limit',
          monthlyAllocationNaira == null
              ? 'Not available'
              : '₦$monthlyAllocationNaira',
        ),
        if (onIssueCard != null) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onIssueCard,
              icon: const Icon(Icons.add_card_rounded, size: 18),
              label: const Text('Issue fuel card'),
            ),
          ),
        ],
        if (onTopUpAllocation != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTopUpAllocation,
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
              label: const Text('Top up vehicle allocation'),
            ),
          ),
        ],
      ],
    );
  }
}

class _TopUpAllocationSheet extends ConsumerStatefulWidget {
  const _TopUpAllocationSheet({
    required this.organisationId,
    required this.orgVehicleId,
    required this.vehicleLabel,
    required this.currentAllocationNaira,
    required this.fleetAvailableNaira,
  });

  final String organisationId;
  final String orgVehicleId;
  final String vehicleLabel;
  final String currentAllocationNaira;
  final String fleetAvailableNaira;

  @override
  ConsumerState<_TopUpAllocationSheet> createState() =>
      _TopUpAllocationSheetState();
}

class _TopUpAllocationSheetState extends ConsumerState<_TopUpAllocationSheet> {
  final _amount = TextEditingController();
  bool _submitting = false;
  String? _error;
  int? _keyAmount;
  String? _idempotencyKey;

  int? get _amountNaira => int.tryParse(_amount.text.trim());
  int get _fleetAvailableKobo =>
      ((double.tryParse(widget.fleetAvailableNaira.replaceAll(',', '')) ?? 0) *
              100)
          .round();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _amountChanged(String _) {
    if (_keyAmount != _amountNaira) {
      _keyAmount = null;
      _idempotencyKey = null;
    }
    setState(() => _error = null);
  }

  Future<void> _submit() async {
    final amount = _amountNaira;
    if (amount == null || amount < 1) {
      setState(() => _error = 'Enter at least ₦1.');
      return;
    }
    if (amount * 100 > _fleetAvailableKobo) {
      setState(
        () => _error =
            'The Fleet fuel pool does not have enough available money.',
      );
      return;
    }
    _keyAmount ??= amount;
    _idempotencyKey ??= _newAllocationIdempotencyKey();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final receipt = await ref
          .read(fleetRepositoryProvider)
          .topUpVehicleAllocation(
            widget.organisationId,
            widget.orgVehicleId,
            amountNaira: amount,
            idempotencyKey: _idempotencyKey!,
          );
      if (mounted) Navigator.of(context).pop(receipt);
    } on ApiFailure catch (failure) {
      if (failure.details['code'] == 'FLEET_IDEMPOTENCY_CONFLICT') {
        _keyAmount = null;
        _idempotencyKey = null;
      }
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = _amountNaira;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final exceedsAvailable =
        amount != null && amount * 100 > _fleetAvailableKobo;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Top up vehicle allocation',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Move available company fuel money into ${widget.vehicleLabel}. Reserved transaction funds cannot be moved.',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.forest700.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.forest700.withValues(alpha: .12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _AllocationBalance(
                    label: 'Fleet available',
                    value: '₦${widget.fleetAvailableNaira}',
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.orange,
                ),
                Expanded(
                  child: _AllocationBalance(
                    label: 'Vehicle allocation',
                    value: '₦${widget.currentAllocationNaira}',
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onChanged: _amountChanged,
            onSubmitted: (_) => _submitting ? null : _submit(),
            decoration: const InputDecoration(
              labelText: 'Amount to allocate',
              prefixText: '₦ ',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _submitting ||
                      amount == null ||
                      amount < 1 ||
                      exceedsAvailable
                  ? null
                  : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _submitting
                    ? 'Allocating securely…'
                    : amount == null
                    ? 'Confirm allocation'
                    : 'Allocate ₦$amount',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationBalance extends StatelessWidget {
  const _AllocationBalance({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 9.5),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

String? _lastFour(String? value) {
  if (value == null || value.isEmpty) return null;
  return value.substring(value.length > 4 ? value.length - 4 : 0);
}

String _fundingModelLabel(String? model) => switch (model) {
  'SHARED' => 'Shared pool',
  'INDIVIDUAL' => 'Individual allocation',
  'HYBRID' => 'Hybrid allocation + pool',
  _ => 'Not configured',
};

String _newAllocationIdempotencyKey() {
  final random = Random.secure();
  return List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.forest700, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
