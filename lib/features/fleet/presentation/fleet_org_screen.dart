import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/config/app_config.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/data/fleet_repository.dart';
import 'package:travla_customer_app/features/fleet/domain/fleet_models.dart';
import 'package:url_launcher/url_launcher.dart';

enum _FleetSection { overview, vehicles, team }

class FleetOrgScreen extends ConsumerStatefulWidget {
  const FleetOrgScreen({super.key, required this.organisationId});

  final String organisationId;

  @override
  ConsumerState<FleetOrgScreen> createState() => _FleetOrgScreenState();
}

class _FleetOrgScreenState extends ConsumerState<FleetOrgScreen> {
  _FleetSection _section = _FleetSection.overview;

  @override
  Widget build(BuildContext context) {
    final organisationId = widget.organisationId;
    final org = ref.watch(fleetOrgProvider(organisationId));
    final dashboard = ref.watch(fleetDashboardProvider(organisationId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(org.value?.name ?? 'Company')),
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: () async {
          ref.invalidate(fleetOrgProvider(organisationId));
          ref.invalidate(fleetDashboardProvider(organisationId));
          await ref
              .read(fleetOrgProvider(organisationId).future)
              .catchError((_) => throw Exception());
        },
        child: org.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            children: [
              Center(
                child: Text(
                  error is ApiFailure
                      ? error.message
                      : 'This company could not be loaded.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          data: (detail) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _RoleBanner(detail: detail),
              const SizedBox(height: 12),
              _SectionPicker(
                selected: _section,
                onSelected: (section) => setState(() => _section = section),
              ),
              const SizedBox(height: 16),
              if (_section == _FleetSection.overview)
                dashboard.when(
                  loading: () => const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => _DashboardError(
                    message: error is ApiFailure
                        ? error.message
                        : 'The fleet overview could not be loaded.',
                    onRetry: () =>
                        ref.invalidate(fleetDashboardProvider(organisationId)),
                  ),
                  data: (summary) => _OverviewSection(
                    detail: detail,
                    summary: summary,
                    onAction: _openAction,
                    onSetupAction: (item) => _openSetupAction(detail, item),
                    onWebHandoff: _openWebHandoff,
                    onOpenTracking: () =>
                        context.push('/more/fleet/$organisationId/tracking'),
                    onOpenFuel: () =>
                        context.push('/more/fleet/$organisationId/fuel'),
                  ),
                )
              else if (_section == _FleetSection.vehicles)
                _VehiclesSection(detail: detail, organisationId: organisationId)
              else
                _TeamSection(detail: detail),
            ],
          ),
        ),
      ),
    );
  }

  void _openAction(FleetAlert alert) {
    switch (alert.actionType) {
      case 'OPEN_FLEET_VEHICLES':
        setState(() => _section = _FleetSection.vehicles);
      case 'OPEN_FLEET_DRIVERS':
      case 'OPEN_FLEET_TEAM':
        setState(() => _section = _FleetSection.team);
      case 'OPEN_FLEET_TRACKING':
        context.push('/more/fleet/${widget.organisationId}/tracking');
      case 'OPEN_FLEET_FUEL':
        context.push('/more/fleet/${widget.organisationId}/fuel');
      default:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'This Fleet action is currently available on the web control plane.',
              ),
            ),
          );
    }
  }

  void _openSetupAction(FleetOrgDetail detail, FleetSetupItem item) {
    switch (item.action) {
      case 'OPEN_FLEET_ENROLMENT':
        context.push('/more/fleet/${widget.organisationId}/enrol');
      case 'OPEN_FLEET_TEAM':
        setState(() => _section = _FleetSection.team);
      case 'OPEN_WEB_FLEET_REGIONS':
        final handoff = detail.setup.webHandoffs
            .where((item) => item.key == 'REGIONS')
            .firstOrNull;
        if (handoff != null) _openWebHandoff(handoff);
    }
  }

  Future<void> _openWebHandoff(FleetWebHandoff handoff) async {
    if (!handoff.path.startsWith('/fleet/')) return;
    final base = Uri.tryParse(AppConfig.webBaseUrl);
    if (base == null || !base.hasScheme || base.host.isEmpty) return;
    final opened = await launchUrl(
      base.resolve(handoff.path),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Travla web administration could not be opened.'),
          ),
        );
    }
  }
}

class _SectionPicker extends StatelessWidget {
  const _SectionPicker({required this.selected, required this.onSelected});

  final _FleetSection selected;
  final ValueChanged<_FleetSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _item(_FleetSection.overview, 'Overview', Icons.dashboard_outlined),
          _item(
            _FleetSection.vehicles,
            'Vehicles',
            Icons.directions_car_outlined,
          ),
          _item(_FleetSection.team, 'Team', Icons.groups_outlined),
        ],
      ),
    );
  }

  Widget _item(_FleetSection section, String label, IconData icon) {
    final active = selected == section;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onSelected(section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.forest700 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : AppColors.muted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.detail,
    required this.summary,
    required this.onAction,
    required this.onSetupAction,
    required this.onWebHandoff,
    required this.onOpenTracking,
    required this.onOpenFuel,
  });

  final FleetOrgDetail detail;
  final FleetKpis summary;
  final ValueChanged<FleetAlert> onAction;
  final ValueChanged<FleetSetupItem> onSetupAction;
  final ValueChanged<FleetWebHandoff> onWebHandoff;
  final VoidCallback onOpenTracking;
  final VoidCallback onOpenFuel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScopeStrip(scope: summary.scope),
        const SizedBox(height: 12),
        _KpiGrid(kpis: summary, fuelBalance: detail.fuelBalanceNaira),
        if (detail.setup.totalCount > 0) ...[
          const SizedBox(height: 14),
          _SetupChecklistCard(
            checklist: detail.setup,
            onAction: onSetupAction,
            onWebHandoff: onWebHandoff,
          ),
        ],
        if (summary.capabilities.viewTracking) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenTracking,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest700,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: const Icon(Icons.map_outlined),
              label: Text(
                'Open live map · ${summary.liveVehicles} reporting now',
              ),
            ),
          ),
        ],
        if (summary.capabilities.viewFuelFinancials) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenFuel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest700,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: const Icon(Icons.local_gas_station_outlined),
              label: const Text('Open Fleet fuel activity'),
            ),
          ),
        ],
        if (summary.renewalPlanning.totalPapers > 0) ...[
          const SizedBox(height: 16),
          _RenewalPlanningCard(
            planning: summary.renewalPlanning,
            onOpenVehicle: (item) => context.push(
              '/more/fleet/${summary.organisationId}/vehicles/${item.orgVehicleId}',
            ),
            onRenew: (item) => context.push(
              Uri(
                path: '/more/renewals/new',
                queryParameters: {
                  'vehicle': item.vehicleId,
                  'type': item.documentType,
                  'fleet_org': summary.organisationId,
                },
              ).toString(),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _Label('Action desk (${summary.alerts.length})'),
        if (summary.alerts.isEmpty)
          const _Empty('Nothing urgent in your permitted Fleet scope.')
        else
          ...summary.alerts.map(
            (alert) => _AlertCard(alert: alert, onTap: () => onAction(alert)),
          ),
      ],
    );
  }
}

class _SetupChecklistCard extends StatelessWidget {
  const _SetupChecklistCard({
    required this.checklist,
    required this.onAction,
    required this.onWebHandoff,
  });

  final FleetSetupChecklist checklist;
  final ValueChanged<FleetSetupItem> onAction;
  final ValueChanged<FleetWebHandoff> onWebHandoff;

  @override
  Widget build(BuildContext context) {
    final progress = checklist.totalCount == 0
        ? 0.0
        : checklist.completedCount / checklist.totalCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                checklist.requiredComplete
                    ? Icons.verified_outlined
                    : Icons.checklist_rounded,
                color: AppColors.forest700,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Company setup',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${checklist.completedCount}/${checklist.totalCount}',
                style: const TextStyle(
                  color: AppColors.forest700,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.forest50,
              color: AppColors.forest700,
            ),
          ),
          const SizedBox(height: 13),
          ...checklist.items.indexed.map((entry) {
            final index = entry.$1;
            final item = entry.$2;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == checklist.items.length - 1 ? 0 : 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.complete
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 19,
                    color: item.complete
                        ? AppColors.forest700
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.required
                              ? item.title
                              : '${item.title} · optional',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!item.complete && item.action != null)
                    TextButton(
                      onPressed: () => onAction(item),
                      child: Text(
                        item.action!.startsWith('OPEN_WEB_') ? 'Web' : 'Start',
                      ),
                    ),
                ],
              ),
            );
          }),
          if (checklist.webHandoffs.isNotEmpty) ...[
            const Divider(height: 28),
            const Text(
              'Advanced administration on web',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Complex company governance stays on Travla web and opens in your browser.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 9),
            ...checklist.webHandoffs.map(
              (handoff) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  handoff.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  handoff.description,
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => onWebHandoff(handoff),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RenewalPlanningCard extends StatelessWidget {
  const _RenewalPlanningCard({
    required this.planning,
    required this.onOpenVehicle,
    required this.onRenew,
  });

  final FleetRenewalPlanning planning;
  final ValueChanged<FleetRenewalItem> onOpenVehicle;
  final ValueChanged<FleetRenewalItem> onRenew;

  @override
  Widget build(BuildContext context) {
    final upcoming = planning.schedule
        .where((item) => (item.daysUntilExpiry ?? 9999) <= 90)
        .take(4)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_repeat_outlined, color: AppColors.forest700),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Renewal plan',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RenewalMetric(
                  value: '${planning.due30Days}',
                  label: 'Due in 30 days',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RenewalMetric(
                  value: '₦${planning.due30CostNaira}',
                  label: 'Estimated cost',
                ),
              ),
            ],
          ),
          if (!planning.sufficientBalance && planning.shortfallNaira != '0.00')
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                'Your personal wallet is short by ₦${planning.shortfallNaira} for your enabled auto-renewals.',
                style: const TextStyle(
                  color: AppColors.orangeDark,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          if (planning.otherOwnerDueCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${planning.otherOwnerDueCount} due paper(s) require action and payment by their vehicle owners.',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          if (upcoming.isNotEmpty) ...[
            const Divider(height: 26),
            ...upcoming.indexed.map((entry) {
              final index = entry.$1;
              final item = entry.$2;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == upcoming.length - 1 ? 0 : 12,
                ),
                child: InkWell(
                  onTap: () => onOpenVehicle(item),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.documentName} · ${item.plateNumber ?? item.vehicleLabel}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _timing(item),
                                style: TextStyle(
                                  color: item.status == 'EXPIRED'
                                      ? AppColors.orangeDark
                                      : AppColors.muted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (item.canRenewDirectly)
                          TextButton(
                            onPressed: () => onRenew(item),
                            child: const Text('Renew'),
                          )
                        else
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  static String _timing(FleetRenewalItem item) {
    final days = item.daysUntilExpiry;
    if (item.renewalAccess == 'IN_PROGRESS') return 'Renewal in progress';
    if (days == null) return item.statusLabel;
    if (days < 0) {
      return '${days.abs()} days overdue · ₦${item.estimatedCostNaira}';
    }
    if (days == 0) return 'Expires today · ₦${item.estimatedCostNaira}';
    return '$days days remaining · ₦${item.estimatedCostNaira}';
  }
}

class _RenewalMetric extends StatelessWidget {
  const _RenewalMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.forest700,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _VehiclesSection extends ConsumerStatefulWidget {
  const _VehiclesSection({required this.detail, required this.organisationId});

  final FleetOrgDetail detail;
  final String organisationId;

  @override
  ConsumerState<_VehiclesSection> createState() => _VehiclesSectionState();
}

class _VehiclesSectionState extends ConsumerState<_VehiclesSection> {
  final _search = TextEditingController();
  List<OrgVehicle> _items = const [];
  int _page = 0;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = false;
  String? _error;
  String? _driverStatus;
  String? _tracking;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _load(reset: true));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(fleetRepositoryProvider)
          .vehicles(
            widget.organisationId,
            page: reset ? 1 : _page + 1,
            query: _search.text,
            driverStatus: _driverStatus,
            tracking: _tracking,
          );
      if (!mounted) return;
      setState(() {
        _items = reset ? result.items : [..._items, ...result.items];
        _page = result.page;
        _lastPage = result.lastPage;
        _total = result.total;
      });
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _Label('Vehicles ($_total)')),
            if (widget.detail.capabilities.manageVehicles)
              TextButton.icon(
                onPressed: () =>
                    context.push('/more/fleet/${widget.organisationId}/enrol'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.forest700,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Enrol'),
              ),
          ],
        ),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(reset: true),
          decoration: InputDecoration(
            hintText: 'Search plate, make or model',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Search',
              onPressed: () => _load(reset: true),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            FilterChip(
              label: const Text('Driver missing'),
              selected: _driverStatus == 'UNASSIGNED',
              onSelected: _loading
                  ? null
                  : (selected) {
                      setState(
                        () => _driverStatus = selected ? 'UNASSIGNED' : null,
                      );
                      _load(reset: true);
                    },
            ),
            FilterChip(
              label: const Text('Tracker missing'),
              selected: _tracking == 'MISSING',
              onSelected: _loading
                  ? null
                  : (selected) {
                      setState(() => _tracking = selected ? 'MISSING' : null);
                      _load(reset: true);
                    },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null)
          _DashboardError(message: _error!, onRetry: () => _load(reset: true))
        else if (_loading && _items.isEmpty)
          const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_items.isEmpty)
          const _Empty('No vehicles match this Fleet view.')
        else
          ..._items.map(
            (vehicle) => _VehicleRow(
              vehicle: vehicle,
              onTap: () => context.push(
                '/more/fleet/${widget.organisationId}/vehicles/${vehicle.id}',
              ),
            ),
          ),
        if (_items.isNotEmpty && _page < _lastPage)
          Center(
            child: TextButton.icon(
              onPressed: _loading ? null : () => _load(reset: false),
              icon: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text('Load more (${_items.length} of $_total)'),
            ),
          ),
      ],
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.detail});

  final FleetOrgDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Members (${detail.members.length})'),
        if (detail.members.isEmpty)
          const _Empty('No active members are visible in this company.')
        else
          ...detail.members.map((member) => _MemberRow(member: member)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_tree_outlined,
                color: AppColors.forest700,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${detail.regionCount} operating region${detail.regionCount == 1 ? '' : 's'} configured',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScopeStrip extends StatelessWidget {
  const _ScopeStrip({required this.scope});

  final FleetScope scope;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.visibility_outlined, size: 16, color: AppColors.muted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            scope.seesAllRegions
                ? 'Showing all company regions'
                : 'Showing ${scope.regionIds.length} assigned region${scope.regionIds.length == 1 ? '' : 's'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onTap});

  final FleetAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (alert.severity) {
      'CRITICAL' => AppColors.danger,
      'WARNING' => AppColors.orangeDark,
      _ => AppColors.forest700,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.priority_high_rounded,
                  color: color,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      alert.description,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _RoleBanner extends StatelessWidget {
  const _RoleBanner({required this.detail});

  final FleetOrgDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.name ?? 'Company',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                if (detail.myRoleLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'You are ${detail.myRoleLabel}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (detail.capabilities.viewFuelFinancials &&
              detail.fuelAvailableNaira != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Fuel available',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                Text(
                  '₦${detail.fuelAvailableNaira}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis, required this.fuelBalance});

  final FleetKpis kpis;
  final String? fuelBalance;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _tile(
        'Vehicles',
        '${kpis.totalVehicles}',
        Icons.directions_car_filled_outlined,
      ),
      _tile(
        'Compliant',
        '${kpis.compliantVehicles}',
        Icons.verified_outlined,
        tone: AppColors.forest700,
      ),
      _tile(
        'Need attention',
        '${kpis.attentionVehicles}',
        Icons.warning_amber_rounded,
        tone: AppColors.orangeDark,
      ),
      _tile(
        'Live now',
        '${kpis.liveVehicles}/${kpis.trackedVehicles}',
        Icons.sensors_rounded,
      ),
      _tile('Members', '${kpis.activeMembers}', Icons.groups_outlined),
      if (fuelBalance != null)
        _tile(
          'Fuel balance',
          '₦$fuelBalance',
          Icons.local_gas_station_outlined,
        ),
    ];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: AppColors.forest700,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fleet health: ${kpis.healthLabel ?? '—'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${kpis.healthScore}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.forest700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: tiles,
        ),
      ],
    );
  }

  Widget _tile(
    String label,
    String value,
    IconData icon, {
    Color tone = AppColors.ink,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: tone,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final OrgMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.forest100,
            foregroundColor: AppColors.forest800,
            child: Text(
              (member.name ?? '?').isNotEmpty
                  ? member.name![0].toUpperCase()
                  : '?',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name ?? 'Member',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  [
                    member.roleLabel,
                    member.seesAllRegions ? 'All regions' : 'Scoped',
                  ].where((s) => s != null).join(' · '),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (member.status != null && member.status != 'ACTIVE')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                member.status!.toLowerCase(),
                style: const TextStyle(
                  color: AppColors.orangeDark,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.vehicle, this.onTap});

  final OrgVehicle vehicle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = switch (vehicle.complianceStatus) {
      'VALID' => AppColors.forest700,
      'EXPIRING_SOON' => AppColors.orangeDark,
      'EXPIRED' => AppColors.danger,
      _ => AppColors.muted,
    };
    final content = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.forest50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.directions_car_filled_outlined,
              color: AppColors.forest700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  [
                    if (vehicle.plateNumber != null) vehicle.plateNumber!,
                    if (vehicle.regionName != null) vehicle.regionName!,
                    if (vehicle.driverName != null) vehicle.driverName!,
                  ].join(' · '),
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
          if (vehicle.hasTracker)
            const Icon(
              Icons.sensors_rounded,
              size: 15,
              color: AppColors.forest600,
            ),
          const SizedBox(width: 6),
          if (vehicle.complianceLabel != null)
            Text(
              vehicle.complianceLabel!,
              style: TextStyle(
                color: tone,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.muted),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    ),
  );
}
