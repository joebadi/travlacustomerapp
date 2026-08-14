import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/stolen/data/stolen_repository.dart';
import 'package:travla_customer_app/features/stolen/domain/stolen_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';

enum _ReportsView { registry, mine }

/// Fresh, phone-first vehicle security page.
///
/// This page is only mounted when Car Talk's Reports section is selected. It
/// has no nested page controller and no dependency on the archived registry
/// implementation in `security_registry_tab.dart`.
class ReportsFeedTab extends ConsumerStatefulWidget {
  const ReportsFeedTab({super.key});

  @override
  ConsumerState<ReportsFeedTab> createState() => _ReportsFeedTabState();
}

class _ReportsFeedTabState extends ConsumerState<ReportsFeedTab> {
  final _plateController = TextEditingController();
  final _searchController = TextEditingController();

  _ReportsView _view = _ReportsView.registry;
  StolenDirectoryFilters _filters = const StolenDirectoryFilters();
  List<StolenReport> _records = const [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _directoryError;

  bool _checkingPlate = false;
  StolenCheckResult? _plateResult;
  String? _plateError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDirectory();
    });
  }

  @override
  void dispose() {
    _plateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory({bool append = false}) async {
    if (mounted) {
      setState(() {
        if (append) {
          _loadingMore = true;
        } else {
          _loading = true;
        }
        _directoryError = null;
      });
    }

    try {
      final requestedPage = append ? _page + 1 : 1;
      final result = await ref
          .read(stolenRepositoryProvider)
          .directory(filters: _filters, page: requestedPage);
      if (!mounted) return;
      setState(() {
        _records = append ? [..._records, ...result.items] : result.items;
        _page = result.page;
        _lastPage = result.lastPage;
        _total = result.total;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _directoryError = error is ApiFailure
            ? error.message
            : 'Vehicle reports could not be loaded. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(stolenStatsProvider);
    ref.invalidate(myStolenReportsProvider);
    await _loadDirectory();
  }

  Future<void> _checkPlate() async {
    FocusScope.of(context).unfocus();
    final plate = _plateController.text.trim();
    if (plate.isEmpty) return;
    setState(() {
      _checkingPlate = true;
      _plateResult = null;
      _plateError = null;
    });
    try {
      final result = await ref.read(stolenRepositoryProvider).checkPlate(plate);
      if (mounted) setState(() => _plateResult = result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _plateError = error is ApiFailure
            ? error.message
            : 'This plate could not be checked. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _checkingPlate = false);
    }
  }

  void _search(String value) {
    final query = value.trim();
    setState(() {
      _filters = StolenDirectoryFilters(
        query: query.isEmpty ? null : query,
        location: _filters.location,
        make: _filters.make,
        color: _filters.color,
        hasReward: _filters.hasReward,
        reportedWithinDays: _filters.reportedWithinDays,
        sort: _filters.sort,
      );
    });
    _loadDirectory();
  }

  Future<void> _openFilters() async {
    final next = await showModalBottomSheet<StolenDirectoryFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _ReportsFilterSheet(initial: _filters),
    );
    if (next == null) return;
    _searchController.text = next.query ?? '';
    setState(() => _filters = next);
    _loadDirectory();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() => _filters = const StolenDirectoryFilters());
    _loadDirectory();
  }

  Future<void> _startTheftReport() async {
    GarageSnapshot? garage;
    try {
      garage = await ref.read(garageProvider.future);
    } catch (_) {
      garage = null;
    }
    if (!mounted) return;
    final vehicles = garage?.vehicles ?? const [];

    if (vehicles.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.directions_car_outlined,
            color: AppColors.forest700,
          ),
          title: const Text('Add the vehicle first'),
          content: const Text(
            'A theft report must be linked to a vehicle in your Travla garage.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push('/vehicles/add-existing');
              },
              child: const Text('Add vehicle'),
            ),
          ],
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select the missing vehicle',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Travla will use its verified vehicle identity in the report.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: vehicles.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final vehicle = vehicles[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.forest50,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.directions_car_filled_rounded,
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
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.push('/more/stolen/report?vehicle=${vehicle.id}');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myStolenReportsProvider);
    return ColoredBox(
      color: AppColors.canvas,
      child: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(15, 4, 15, 96),
          children: [
            _ReportsHeader(
              view: _view,
              personalCount: mine.asData?.value.length,
              onViewChanged: (view) => setState(() => _view = view),
            ),
            const SizedBox(height: 14),
            if (_view == _ReportsView.registry)
              ..._registryContent()
            else
              ..._mineContent(mine),
          ],
        ),
      ),
    );
  }

  List<Widget> _registryContent() {
    final stats = ref.watch(stolenStatsProvider);
    return [
      _PlateCheckCard(
        controller: _plateController,
        loading: _checkingPlate,
        result: _plateResult,
        error: _plateError,
        onCheck: _checkPlate,
        onOpen: (id) => context.push('/more/stolen/$id'),
        onSighting: (id) => context.push('/more/stolen/$id/sighting'),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _startTheftReport,
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('Report stolen'),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _view = _ReportsView.mine),
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('My reports'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      stats.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (_, _) => const SizedBox.shrink(),
        data: (value) => _ReportsStats(stats: value),
      ),
      const SizedBox(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVE REGISTRY',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Reported vehicles',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          Text(
            '$_total active',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: const InputDecoration(
                hintText: 'Plate, make, model or place',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: !_filters.isDefault,
            backgroundColor: AppColors.orange,
            child: IconButton.filledTonal(
              tooltip: 'Filter reports',
              onPressed: _openFilters,
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
          child: TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.close_rounded, size: 15),
            label: const Text('Clear filters'),
          ),
        ),
      const SizedBox(height: 12),
      ..._directoryWidgets(),
      const SizedBox(height: 18),
      const _ReportsSafetyNotice(),
    ];
  }

  List<Widget> _directoryWidgets() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 44),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_directoryError != null) {
      return [
        _ReportsError(message: _directoryError!, onRetry: _loadDirectory),
      ];
    }
    if (_records.isEmpty) {
      return const [
        _ReportsEmpty(
          icon: Icons.search_off_rounded,
          title: 'No matching active report',
          message: 'Try a broader search or clear the current filters.',
        ),
      ];
    }
    return [
      ..._records.map(
        (report) => Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: _ReportVehicleCard(
            report: report,
            onOpen: () => context.push('/more/stolen/${report.id}'),
            onSighting: () =>
                context.push('/more/stolen/${report.id}/sighting'),
          ),
        ),
      ),
      if (_page < _lastPage)
        Center(
          child: OutlinedButton.icon(
            onPressed: _loadingMore ? null : () => _loadDirectory(append: true),
            icon: _loadingMore
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(_loadingMore ? 'Loading…' : 'Show more'),
          ),
        ),
    ];
  }

  List<Widget> _mineContent(AsyncValue<List<StolenReport>> mine) {
    return [
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _view = _ReportsView.registry),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text('Back to registry'),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: FilledButton.icon(
              onPressed: _startTheftReport,
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New report'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      const Text(
        'Your vehicle reports',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      const Text(
        'Review sightings and update recovery status from each report.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 14),
      mine.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 42),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => _ReportsError(
          message: error is ApiFailure
              ? error.message
              : 'Your reports could not be loaded.',
          onRetry: () => ref.invalidate(myStolenReportsProvider),
        ),
        data: (reports) => reports.isEmpty
            ? const _ReportsEmpty(
                icon: Icons.verified_user_outlined,
                title: 'No reports created',
                message: 'Hopefully it stays that way.',
              )
            : Column(
                children: reports
                    .map(
                      (report) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PersonalReportCard(
                          report: report,
                          onTap: () =>
                              context.push('/more/stolen/${report.id}'),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
    ];
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({
    required this.view,
    required this.personalCount,
    required this.onViewChanged,
  });

  final _ReportsView view;
  final int? personalCount;
  final ValueChanged<_ReportsView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              _ReportsShield(),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Check plates. Report theft. Share sightings.',
                      style: TextStyle(color: AppColors.muted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeaderChoice(
                  label: 'Registry',
                  selected: view == _ReportsView.registry,
                  onTap: () => onViewChanged(_ReportsView.registry),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderChoice(
                  label: personalCount == null
                      ? 'My reports'
                      : 'My reports ($personalCount)',
                  selected: view == _ReportsView.mine,
                  onTap: () => onViewChanged(_ReportsView.mine),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportsShield extends StatelessWidget {
  const _ReportsShield();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: AppColors.forest900,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.shield_outlined, color: Colors.white, size: 23),
    );
  }
}

class _HeaderChoice extends StatelessWidget {
  const _HeaderChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.forest900 : AppColors.canvas,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlateCheckCard extends StatelessWidget {
  const _PlateCheckCard({
    required this.controller,
    required this.loading,
    required this.result,
    required this.error,
    required this.onCheck,
    required this.onOpen,
    required this.onSighting,
  });

  final TextEditingController controller;
  final bool loading;
  final StolenCheckResult? result;
  final String? error;
  final VoidCallback onCheck;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onSighting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHECK BEFORE YOU BUY',
            style: TextStyle(
              color: Color(0xFF83DDBB),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Is this vehicle reported?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter a plate number to check Travla’s active registry.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .62),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onCheck(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: 'LAG-123-XY',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: .3),
                    ),
                    fillColor: Colors.black.withValues(alpha: .18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: .16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: loading ? null : onCheck,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.forest950,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Check'),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFFFC3BC), fontSize: 11),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 11),
            _PlateCheckResult(
              result: result!,
              onOpen: onOpen,
              onSighting: onSighting,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlateCheckResult extends StatelessWidget {
  const _PlateCheckResult({
    required this.result,
    required this.onOpen,
    required this.onSighting,
  });

  final StolenCheckResult result;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onSighting;

  @override
  Widget build(BuildContext context) {
    final stolen = result.isStolen && result.report != null;
    final report = result.report;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: stolen
            ? AppColors.danger.withValues(alpha: .18)
            : const Color(0xFF0B684A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stolen
                ? '${result.plate.toUpperCase()} is reported stolen.'
                : 'No active report found for ${result.plate.toUpperCase()}.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stolen
                ? 'Do not approach or transact. Contact the authorities when safe.'
                : 'This does not replace official vehicle verification.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .65),
              fontSize: 10,
            ),
          ),
          if (report != null) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onOpen(report.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .3),
                      ),
                    ),
                    child: const Text('View'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => onSighting(report.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    child: const Text('Report sighting'),
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

class _ReportsStats extends StatelessWidget {
  const _ReportsStats({required this.stats});

  final StolenStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Security overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${stats.recoveryRate}% recovered',
              style: const TextStyle(
                color: AppColors.forest700,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _MiniStat(
              value: '${stats.currentlyStolen}',
              label: 'Active',
              color: AppColors.danger,
            ),
            _MiniStat(
              value: '${stats.recovered}',
              label: 'Recovered',
              color: AppColors.forest700,
            ),
            _MiniStat(
              value: '${stats.totalSightings}',
              label: 'Sightings',
              color: AppColors.orangeDark,
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
              style: TextStyle(
                color: color,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportVehicleCard extends StatelessWidget {
  const _ReportVehicleCard({
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
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  width: 78,
                  height: 82,
                  child: vehicle?.images.isNotEmpty == true
                      ? Image.network(
                          vehicle!.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _VehicleFallback(),
                        )
                      : const _VehicleFallback(),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vehicle?.name ?? 'Reported vehicle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const _StolenBadge(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vehicle?.plateNumber ?? 'Plate unavailable',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Last seen: ${report.lastKnownLocation ?? 'Not provided'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${report.sightingsCount ?? 0} sighting${report.sightingsCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: AppColors.forest700,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onSighting,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            minimumSize: const Size(0, 30),
                          ),
                          child: const Text('I saw it'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalReportCard extends StatelessWidget {
  const _PersonalReportCard({required this.report, required this.onTap});

  final StolenReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          backgroundColor: AppColors.forest50,
          child: Icon(
            Icons.directions_car_outlined,
            color: AppColors.forest700,
          ),
        ),
        title: Text(
          report.vehicle?.name ?? 'Vehicle report',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${report.vehicle?.plateNumber ?? 'No plate'} · ${report.sightingsCount ?? 0} sightings',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _StolenBadge extends StatelessWidget {
  const _StolenBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'STOLEN',
        style: TextStyle(
          color: AppColors.danger,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _VehicleFallback extends StatelessWidget {
  const _VehicleFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE5ECE9),
      child: Icon(Icons.directions_car_outlined, color: AppColors.muted),
    );
  }
}

class _ReportsSafetyNotice extends StatelessWidget {
  const _ReportsSafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined, color: Color(0xFF7A5100)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Never confront or pursue a suspected stolen vehicle. Keep a safe distance, contact the authorities, then submit a sighting when safe.',
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
}

class _ReportsEmpty extends StatelessWidget {
  const _ReportsEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted, size: 31),
          const SizedBox(height: 9),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _ReportsError extends StatelessWidget {
  const _ReportsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E1),
        borderRadius: BorderRadius.circular(14),
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
}

class _ReportsFilterSheet extends StatefulWidget {
  const _ReportsFilterSheet({required this.initial});

  final StolenDirectoryFilters initial;

  @override
  State<_ReportsFilterSheet> createState() => _ReportsFilterSheetState();
}

class _ReportsFilterSheetState extends State<_ReportsFilterSheet> {
  late final _location = TextEditingController(text: widget.initial.location);
  late final _make = TextEditingController(text: widget.initial.make);
  late final _color = TextEditingController(text: widget.initial.color);
  late String _sort = widget.initial.sort;
  late int? _days = widget.initial.reportedWithinDays;
  late bool _reward = widget.initial.hasReward;

  @override
  void dispose() {
    _location.dispose();
    _make.dispose();
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              'Filter vehicle reports',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Last seen near',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _make,
                    decoration: const InputDecoration(labelText: 'Make'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: TextField(
                    controller: _color,
                    decoration: const InputDecoration(labelText: 'Colour'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _sort,
              decoration: const InputDecoration(labelText: 'Sort by'),
              items: const [
                DropdownMenuItem(
                  value: 'newest',
                  child: Text('Newest reports'),
                ),
                DropdownMenuItem(
                  value: 'sightings',
                  child: Text('Most sightings'),
                ),
                DropdownMenuItem(
                  value: 'reward',
                  child: Text('Highest reward'),
                ),
              ],
              onChanged: (value) => setState(() => _sort = value ?? 'newest'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              initialValue: _days,
              decoration: const InputDecoration(labelText: 'Reported within'),
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
              title: const Text(
                'Only show reward offers',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              value: _reward,
              onChanged: (value) => setState(() => _reward = value),
            ),
            const SizedBox(height: 8),
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
}
