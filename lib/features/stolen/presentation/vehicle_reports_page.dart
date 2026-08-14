import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/stolen/data/stolen_repository.dart';
import 'package:travla_customer_app/features/stolen/domain/stolen_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';

enum _ReportsSection { registry, mine }

/// Canonical mobile vehicle-security workspace.
///
/// The page deliberately paints its navigation, hero and core actions before
/// any request resolves. Registry, statistics and personal-report failures are
/// isolated in their own panels, so an API problem can never produce a blank
/// tab again.
class VehicleReportsPage extends ConsumerStatefulWidget {
  const VehicleReportsPage({super.key});

  @override
  ConsumerState<VehicleReportsPage> createState() => _VehicleReportsPageState();
}

class _VehicleReportsPageState extends ConsumerState<VehicleReportsPage> {
  final _plate = TextEditingController();
  final _search = TextEditingController();

  _ReportsSection _section = _ReportsSection.registry;
  StolenDirectoryFilters _filters = const StolenDirectoryFilters();
  late Future<_LoadResult<StolenDirectoryPage>> _directoryFuture;
  late Future<_LoadResult<StolenStats>> _statsFuture;
  late Future<_LoadResult<List<StolenReport>>> _mineFuture;
  bool _checkingPlate = false;
  StolenCheckResult? _plateResult;
  String? _plateError;

  @override
  void initState() {
    super.initState();
    _startRequests();
  }

  @override
  void dispose() {
    _plate.dispose();
    _search.dispose();
    super.dispose();
  }

  void _startRequests() {
    final repository = ref.read(stolenRepositoryProvider);
    _directoryFuture = _screenRequest<StolenDirectoryPage>(
      () => repository.directory(filters: _filters),
    );
    _statsFuture = _screenRequest<StolenStats>(repository.stats);
    _mineFuture = _screenRequest<List<StolenReport>>(repository.mine);
  }

  Future<void> _refresh() async {
    setState(_startRequests);
    await Future.wait<void>([
      _directoryFuture.then<void>((_) {}, onError: (_) {}),
      _statsFuture.then<void>((_) {}, onError: (_) {}),
      _mineFuture.then<void>((_) {}, onError: (_) {}),
    ]);
  }

  void _reloadDirectory() {
    setState(() {
      final repository = ref.read(stolenRepositoryProvider);
      _directoryFuture = _screenRequest<StolenDirectoryPage>(
        () => repository.directory(filters: _filters),
      );
    });
  }

  Future<void> _checkPlate() async {
    FocusScope.of(context).unfocus();
    final value = _plate.text.trim();
    if (value.isEmpty) {
      setState(() => _plateError = 'Enter a plate number to check.');
      return;
    }
    setState(() {
      _checkingPlate = true;
      _plateResult = null;
      _plateError = null;
    });
    try {
      final result = await ref.read(stolenRepositoryProvider).checkPlate(value);
      if (mounted) setState(() => _plateResult = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _plateError = _message(error, 'Plate check failed.'));
    } finally {
      if (mounted) setState(() => _checkingPlate = false);
    }
  }

  void _submitSearch(String value) {
    final query = value.trim();
    _filters = _filters.copyWith(query: query);
    if (query.isEmpty) {
      _filters = StolenDirectoryFilters(
        location: _filters.location,
        make: _filters.make,
        color: _filters.color,
        hasReward: _filters.hasReward,
        reportedWithinDays: _filters.reportedWithinDays,
        sort: _filters.sort,
      );
    }
    _reloadDirectory();
  }

  Future<void> _showFilters() async {
    final filters = await showModalBottomSheet<StolenDirectoryFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (context) => _FilterSheet(initial: _filters),
    );
    if (filters == null || !mounted) return;
    _filters = filters;
    _search.text = filters.query ?? '';
    _reloadDirectory();
  }

  void _clearFilters() {
    _search.clear();
    _filters = const StolenDirectoryFilters();
    _reloadDirectory();
  }

  Future<void> _reportStolen() async {
    GarageSnapshot? garage;
    try {
      garage = await ref.read(garageProvider.future);
    } catch (_) {
      garage = null;
    }
    if (!mounted) return;
    final vehicles = garage?.vehicles ?? const <VehicleSummary>[];
    if (vehicles.isEmpty) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.directions_car_outlined,
                  color: AppColors.forest700,
                  size: 36,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Add the vehicle first',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                const Text(
                  'A theft report must be connected to a vehicle in your Travla garage.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.push('/vehicles/add-existing');
                    },
                    child: const Text('Add a vehicle'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Always confirm the vehicle in a picker — even with a single vehicle —
    // so the reporter can see exactly which vehicle the report is filed for.
    final selected = await showModalBottomSheet<VehicleSummary>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                vehicles.length == 1
                    ? 'Confirm the vehicle'
                    : 'Which vehicle is missing?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'This is the vehicle the theft report will be filed for.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: vehicles.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.forest50,
                      child: Icon(
                        Icons.directions_car_outlined,
                        color: AppColors.forest700,
                      ),
                    ),
                    title: Text(
                      vehicle.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: vehicle.plateNumber?.isNotEmpty == true
                        ? Text(vehicle.plateNumber!)
                        : null,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(sheetContext).pop(vehicle),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      context.push('/more/stolen/report?vehicle=${selected.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('report-stolen-action'),
        onPressed: _reportStolen,
        backgroundColor: AppColors.danger,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Report stolen'),
      ),
      body: ColoredBox(
        key: const ValueKey('vehicle-reports-page'),
        color: AppColors.canvas,
        child: RefreshIndicator(
          color: AppColors.forest700,
          onRefresh: _refresh,
          child: ListView(
            key: const PageStorageKey('vehicle-reports-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            // No horizontal padding here — the "Vehicle Security" hero runs
            // edge-to-edge; the section content below keeps its own inset.
            padding: const EdgeInsets.only(bottom: 104),
            children: [
              _SecurityHero(
                section: _section,
                onSectionChanged: (section) =>
                    setState(() => _section = section),
                plateController: _plate,
                checkingPlate: _checkingPlate,
                plateResult: _plateResult,
                plateError: _plateError,
                onCheckPlate: _checkPlate,
                onOpenReport: (id) => context.push('/more/stolen/$id'),
                onSighting: (id) => context.push('/more/stolen/$id/sighting'),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _section == _ReportsSection.registry
                      ? _registryWidgets()
                      : _personalWidgets(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _registryWidgets() => [
    FutureBuilder<_LoadResult<StolenStats>>(
      future: _statsFuture,
      builder: (context, snapshot) => _StatsPanel(snapshot: snapshot),
    ),
    const SizedBox(height: 22),
    const Text(
      'ACTIVE SECURITY REGISTRY',
      style: TextStyle(
        color: AppColors.danger,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    ),
    const SizedBox(height: 3),
    const Text(
      'Reported stolen vehicles',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
    ),
    const SizedBox(height: 4),
    const Text(
      'Search the active registry or narrow it by location and vehicle details.',
      style: TextStyle(color: AppColors.muted, fontSize: 11.5),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: _submitSearch,
            decoration: const InputDecoration(
              hintText: 'Plate, make, model or place',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Badge(
          isLabelVisible: !_filters.isDefault,
          child: IconButton.filledTonal(
            tooltip: 'Filter reports',
            onPressed: _showFilters,
            style: IconButton.styleFrom(
              minimumSize: const Size(50, 50),
              backgroundColor: AppColors.forest100,
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
        ),
      ],
    ),
    if (!_filters.isDefault)
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _clearFilters,
          child: const Text('Clear all filters'),
        ),
      ),
    const SizedBox(height: 10),
    FutureBuilder<_LoadResult<StolenDirectoryPage>>(
      future: _directoryFuture,
      builder: (context, snapshot) => _DirectoryPanel(
        snapshot: snapshot,
        onRetry: _reloadDirectory,
        onOpen: (id) => context.push('/more/stolen/$id'),
        onSighting: (id) => context.push('/more/stolen/$id/sighting'),
      ),
    ),
    const SizedBox(height: 16),
    const _SafetyNotice(),
  ];

  List<Widget> _personalWidgets() => [
    const Text(
      'Your vehicle reports',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
    ),
    const SizedBox(height: 4),
    const Text(
      'Open a report to review sightings, confirm recovery or close the case.',
      style: TextStyle(color: AppColors.muted, fontSize: 11.5),
    ),
    const SizedBox(height: 12),
    FutureBuilder<_LoadResult<List<StolenReport>>>(
      future: _mineFuture,
      builder: (context, snapshot) => _PersonalReportsPanel(
        snapshot: snapshot,
        onRetry: () => setState(() {
          final repository = ref.read(stolenRepositoryProvider);
          _mineFuture = _screenRequest<List<StolenReport>>(repository.mine);
        }),
        onOpen: (id) => context.push('/more/stolen/$id'),
      ),
    ),
  ];
}

class _SecurityHero extends StatelessWidget {
  const _SecurityHero({
    required this.section,
    required this.onSectionChanged,
    required this.plateController,
    required this.checkingPlate,
    required this.plateResult,
    required this.plateError,
    required this.onCheckPlate,
    required this.onOpenReport,
    required this.onSighting,
  });

  final _ReportsSection section;
  final ValueChanged<_ReportsSection> onSectionChanged;
  final TextEditingController plateController;
  final bool checkingPlate;
  final StolenCheckResult? plateResult;
  final String? plateError;
  final VoidCallback onCheckPlate;
  final ValueChanged<String> onOpenReport;
  final ValueChanged<String> onSighting;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.forest950, AppColors.forest700],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF78DDB7), size: 25),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Vehicle Security',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Check a plate, report a theft and safely share verified sightings.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .68),
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('reports-plate-field'),
                controller: plateController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onCheckPlate(),
                decoration: const InputDecoration(
                  hintText: 'LAG-123-XY',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              height: 50,
              child: FilledButton(
                onPressed: checkingPlate ? null : onCheckPlate,
                child: checkingPlate
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Check'),
              ),
            ),
          ],
        ),
        if (plateError != null) ...[
          const SizedBox(height: 9),
          Text(plateError!, style: const TextStyle(color: Color(0xFFFF9C8C))),
        ],
        if (plateResult != null) ...[
          const SizedBox(height: 9),
          _CheckResult(
            result: plateResult!,
            onOpenReport: onOpenReport,
            onSighting: onSighting,
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SectionButton(
                label: 'Public registry',
                selected: section == _ReportsSection.registry,
                onTap: () => onSectionChanged(_ReportsSection.registry),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SectionButton(
                label: 'My reports',
                selected: section == _ReportsSection.mine,
                onTap: () => onSectionChanged(_ReportsSection.mine),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.orange : Colors.white.withValues(alpha: .08),
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class _CheckResult extends StatelessWidget {
  const _CheckResult({
    required this.result,
    required this.onOpenReport,
    required this.onSighting,
  });

  final StolenCheckResult result;
  final ValueChanged<String> onOpenReport;
  final ValueChanged<String> onSighting;

  @override
  Widget build(BuildContext context) {
    final report = result.report;
    final flagged = result.isStolen && report != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: flagged ? const Color(0xFFFFE5E2) : AppColors.forest50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            flagged
                ? '${result.plate.toUpperCase()} has an active theft report.'
                : 'No active Travla theft report found.',
            style: TextStyle(
              color: flagged ? AppColors.danger : AppColors.forest800,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (report != null) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onOpenReport(report.id),
                    child: const Text('View report'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => onSighting(report.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    child: const Text('I saw it'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.snapshot});

  final AsyncSnapshot<_LoadResult<StolenStats>> snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    final result = snapshot.data;
    if (result?.error != null) {
      return const _InlineNotice(
        icon: Icons.info_outline_rounded,
        text: 'Security totals are temporarily unavailable.',
      );
    }
    final stats = result!.data!;
    return Row(
      children: [
        _Stat(value: '${stats.currentlyStolen}', label: 'Active'),
        const SizedBox(width: 8),
        _Stat(value: '${stats.recovered}', label: 'Recovered'),
        const SizedBox(width: 8),
        _Stat(value: '${stats.totalSightings}', label: 'Sightings'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.forest800,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 9.5),
          ),
        ],
      ),
    ),
  );
}

class _DirectoryPanel extends StatelessWidget {
  const _DirectoryPanel({
    required this.snapshot,
    required this.onRetry,
    required this.onOpen,
    required this.onSighting,
  });

  final AsyncSnapshot<_LoadResult<StolenDirectoryPage>> snapshot;
  final VoidCallback onRetry;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onSighting;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const _LoadingPanel(label: 'Loading active reports…');
    }
    final result = snapshot.data;
    if (result?.error != null) {
      return _ErrorPanel(
        message: _message(
          result!.error!,
          'Active reports could not be loaded.',
        ),
        onRetry: onRetry,
      );
    }
    final records = result?.data?.items ?? const <StolenReport>[];
    if (records.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.verified_user_outlined,
        title: 'No active reports match',
        body: 'There are currently no public theft reports for this search.',
      );
    }
    return Column(
      children: records
          .map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _ReportCard(
                report: report,
                onOpen: () => onOpen(report.id),
                onSighting: () => onSighting(report.id),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onOpen,
    required this.onSighting,
  });

  final StolenReport report;
  final VoidCallback onOpen;
  final VoidCallback onSighting;

  @override
  Widget build(BuildContext context) {
    final vehicle = report.vehicle;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5E2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.directions_car_outlined,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle?.name.isNotEmpty == true
                          ? vehicle!.name
                          : 'Reported vehicle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicle?.plateNumber ?? 'Plate unavailable',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      report.lastKnownLocation ?? 'Last location not provided',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onSighting, child: const Text('I saw it')),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalReportsPanel extends StatelessWidget {
  const _PersonalReportsPanel({
    required this.snapshot,
    required this.onRetry,
    required this.onOpen,
  });

  final AsyncSnapshot<_LoadResult<List<StolenReport>>> snapshot;
  final VoidCallback onRetry;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const _LoadingPanel(label: 'Loading your reports…');
    }
    final result = snapshot.data;
    if (result?.error != null) {
      return _ErrorPanel(
        message: _message(result!.error!, 'Your reports could not be loaded.'),
        onRetry: onRetry,
      );
    }
    final reports = result?.data ?? const <StolenReport>[];
    if (reports.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.shield_outlined,
        title: 'No reports created',
        body: 'Hopefully it stays that way.',
      );
    }
    return Column(
      children: reports
          .map(
            (report) => Card(
              child: ListTile(
                onTap: () => onOpen(report.id),
                leading: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.forest700,
                ),
                title: Text(
                  report.vehicle?.name ?? 'Vehicle report',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(report.statusLabel),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 28),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        const CircularProgressIndicator(strokeWidth: 2),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: AppColors.muted)),
      ],
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.forest600, size: 32),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
        ),
      ],
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE5E2),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.danger),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.danger, fontSize: 11.5),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.muted, size: 18),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ),
    ],
  );
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3D2),
      borderRadius: BorderRadius.circular(15),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.health_and_safety_outlined, color: Color(0xFF795200)),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Never confront or pursue a suspected stolen vehicle. Keep a safe distance and contact the authorities first.',
            style: TextStyle(
              color: Color(0xFF684500),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final StolenDirectoryFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final _location = TextEditingController(text: widget.initial.location);
  late final _make = TextEditingController(text: widget.initial.make);
  late final _color = TextEditingController(text: widget.initial.color);
  late bool _reward = widget.initial.hasReward;
  late String _sort = widget.initial.sort;
  late int? _days = widget.initial.reportedWithinDays;

  @override
  void dispose() {
    _location.dispose();
    _make.dispose();
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      0,
      18,
      18 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Filter active reports',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Last seen near'),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _make,
                  decoration: const InputDecoration(labelText: 'Vehicle make'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _color,
                  decoration: const InputDecoration(labelText: 'Colour'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          DropdownButtonFormField<String>(
            initialValue: _sort,
            decoration: const InputDecoration(labelText: 'Sort records'),
            items: const [
              DropdownMenuItem(value: 'newest', child: Text('Newest first')),
              DropdownMenuItem(
                value: 'sightings',
                child: Text('Most sightings'),
              ),
              DropdownMenuItem(value: 'reward', child: Text('Highest reward')),
            ],
            onChanged: (value) => setState(() => _sort = value ?? 'newest'),
          ),
          const SizedBox(height: 9),
          DropdownButtonFormField<int?>(
            initialValue: _days,
            decoration: const InputDecoration(labelText: 'Date reported'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Any time')),
              DropdownMenuItem(value: 7, child: Text('Last 7 days')),
              DropdownMenuItem(value: 30, child: Text('Last 30 days')),
              DropdownMenuItem(value: 90, child: Text('Last 90 days')),
            ],
            onChanged: (value) => setState(() => _days = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _reward,
            onChanged: (value) => setState(() => _reward = value),
            title: const Text(
              'Only reward offers',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(
                StolenDirectoryFilters(
                  query: widget.initial.query,
                  location: _location.text.trim(),
                  make: _make.text.trim(),
                  color: _color.text.trim(),
                  hasReward: _reward,
                  reportedWithinDays: _days,
                  sort: _sort,
                ),
              ),
              child: const Text('Apply filters'),
            ),
          ),
        ],
      ),
    ),
  );
}

String _message(Object error, String fallback) =>
    error is ApiFailure ? error.message : fallback;

class _LoadResult<T> {
  const _LoadResult.data(this.data) : error = null;
  const _LoadResult.error(this.error) : data = null;

  final T? data;
  final Object? error;
}

Future<_LoadResult<T>> _screenRequest<T>(Future<T> Function() request) async {
  // Let FutureBuilder subscribe before the request starts. This also converts
  // a synchronous repository throw into the Future's error state instead of
  // allowing it to escape during widget initialization.
  await Future<void>.delayed(Duration.zero);
  try {
    return _LoadResult<T>.data(await request());
  } catch (error) {
    return _LoadResult<T>.error(error);
  }
}
