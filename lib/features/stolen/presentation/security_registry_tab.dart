import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/stolen/data/stolen_repository.dart';
import 'package:travla_customer_app/features/stolen/domain/stolen_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';

enum _SecurityView { registry, myReports }

/// Mobile-first stolen-vehicle workspace embedded in Car Talk.
///
/// Public discovery and personal case management are deliberately separated
/// so the phone screen never becomes a compressed copy of the web directory.
class StolenFeedTab extends ConsumerStatefulWidget {
  const StolenFeedTab({super.key});

  @override
  ConsumerState<StolenFeedTab> createState() => _StolenFeedTabState();
}

class _StolenFeedTabState extends ConsumerState<StolenFeedTab> {
  final _plateController = TextEditingController();
  final _registrySearchController = TextEditingController();
  final _scrollController = ScrollController();

  _SecurityView _view = _SecurityView.registry;
  bool _checkingPlate = false;
  StolenCheckResult? _plateResult;
  String? _plateError;

  StolenDirectoryFilters _filters = const StolenDirectoryFilters();
  StolenDirectoryPage? _directory;
  bool _directoryLoading = false;
  bool _directoryLoadingMore = false;
  String? _directoryError;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  @override
  void dispose() {
    _plateController.dispose();
    _registrySearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(stolenStatsProvider);
    ref.invalidate(myStolenReportsProvider);
    await Future.wait([
      ref
          .read(stolenStatsProvider.future)
          .catchError(
            (_) => const StolenStats(
              currentlyStolen: 0,
              recovered: 0,
              recoveryRate: 0,
              totalSightings: 0,
              recentSightings: 0,
            ),
          ),
      ref
          .read(myStolenReportsProvider.future)
          .catchError((_) => <StolenReport>[]),
      _loadDirectory(),
    ]);
  }

  void _selectView(_SecurityView view) {
    if (_view == view) return;
    setState(() => _view = view);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _loadDirectory({bool loadMore = false}) async {
    setState(() {
      if (loadMore) {
        _directoryLoadingMore = true;
      } else {
        _directoryLoading = true;
      }
      _directoryError = null;
    });

    try {
      final pageNumber = loadMore ? (_directory?.page ?? 0) + 1 : 1;
      final page = await ref
          .read(stolenRepositoryProvider)
          .directory(filters: _filters, page: pageNumber);
      if (!mounted) return;
      setState(() {
        _directory = loadMore
            ? StolenDirectoryPage(
                items: [...?_directory?.items, ...page.items],
                page: page.page,
                lastPage: page.lastPage,
                total: page.total,
              )
            : page;
      });
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _directoryError = failure.message);
    } finally {
      if (mounted) {
        setState(() {
          _directoryLoading = false;
          _directoryLoadingMore = false;
        });
      }
    }
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
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _plateError = failure.message);
    } finally {
      if (mounted) setState(() => _checkingPlate = false);
    }
  }

  void _searchRegistry(String value) {
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

  void _clearFilters() {
    _registrySearchController.clear();
    setState(() => _filters = const StolenDirectoryFilters());
    _loadDirectory();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<StolenDirectoryFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _RegistryFilterSheet(initial: _filters),
    );
    if (result == null) return;
    _registrySearchController.text = result.query ?? '';
    setState(() => _filters = result);
    _loadDirectory();
  }

  /// Opens a vehicle picker before routing into the full incident form.
  Future<void> reportStolen() async {
    final vehicles = await ref
        .read(garageProvider.future)
        .then((garage) => garage.vehicles)
        .catchError(
          (_) => ref.read(garageProvider).value?.vehicles ?? const [],
        );
    if (!mounted) return;

    if (vehicles.isEmpty) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetIcon(icon: Icons.directions_car_outlined),
                const SizedBox(height: 16),
                const Text(
                  'Add the vehicle first',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                const Text(
                  'A theft report must be tied to a vehicle in your Travla garage so its identity and ownership can be verified.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, height: 1.45),
                ),
                const SizedBox(height: 20),
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Which vehicle is missing?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Select a vehicle to begin a verified theft report.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: vehicles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final vehicle = vehicles[index];
                  return Material(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.push(
                          '/more/stolen/report?vehicle=${vehicle.id}',
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.forest50,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.directions_car_filled_rounded,
                                color: AppColors.forest700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (vehicle.plateNumber?.isNotEmpty == true)
                                    Text(
                                      vehicle.plateNumber!,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 15,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
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
    final stats = ref.watch(stolenStatsProvider);
    final mine = ref.watch(myStolenReportsProvider);
    final mineCount = mine.asData?.value.length;

    return RefreshIndicator(
      color: AppColors.forest700,
      onRefresh: _refresh,
      child: ListView(
        key: PageStorageKey(_view),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          _SecurityHeader(
            selected: _view,
            reportsCount: mineCount,
            onSelected: _selectView,
          ),
          const SizedBox(height: 16),
          if (_view == _SecurityView.registry)
            ..._registryContent(stats)
          else
            ..._myReportsContent(mine),
        ],
      ),
    );
  }

  List<Widget> _registryContent(AsyncValue<StolenStats> stats) {
    return [
      _PlateCheckPanel(
        controller: _plateController,
        checking: _checkingPlate,
        result: _plateResult,
        error: _plateError,
        onCheck: _checkPlate,
        onOpenRecord: (id) => context.push('/more/stolen/$id'),
        onReportSighting: (id) => context.push('/more/stolen/$id/sighting'),
      ),
      const SizedBox(height: 12),
      _QuickActions(
        onReport: reportStolen,
        onManage: () => _selectView(_SecurityView.myReports),
      ),
      const SizedBox(height: 22),
      stats.when(
        loading: () => const _StatsSkeleton(),
        error: (_, _) => const SizedBox.shrink(),
        data: (value) => _SecurityPulse(stats: value),
      ),
      const SizedBox(height: 24),
      _SectionHeading(
        eyebrow: 'ACTIVE REGISTRY',
        title: 'Reported stolen vehicles',
        detail: _directory == null ? null : '${_directory!.total} found',
      ),
      const SizedBox(height: 12),
      _RegistrySearch(
        controller: _registrySearchController,
        filters: _filters,
        onSearch: _searchRegistry,
        onFilter: _openFilters,
        onReset: _clearFilters,
      ),
      const SizedBox(height: 14),
      ..._directoryContent(),
      const SizedBox(height: 18),
      const _SafetyNotice(),
    ];
  }

  List<Widget> _directoryContent() {
    if (_directoryLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_directoryError != null) {
      return [_InlineError(message: _directoryError!, onRetry: _loadDirectory)];
    }
    final reports = _directory?.items ?? const <StolenReport>[];
    if (reports.isEmpty) return const [_EmptyRegistry()];

    return [
      ...reports.map(
        (report) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _MobileRegistryCard(
            report: report,
            onOpen: () => context.push('/more/stolen/${report.id}'),
            onSighting: () =>
                context.push('/more/stolen/${report.id}/sighting'),
          ),
        ),
      ),
      if (_directory?.hasMore == true)
        Center(
          child: OutlinedButton.icon(
            onPressed: _directoryLoadingMore
                ? null
                : () => _loadDirectory(loadMore: true),
            icon: _directoryLoadingMore
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(_directoryLoadingMore ? 'Loading…' : 'Show more'),
          ),
        ),
    ];
  }

  List<Widget> _myReportsContent(AsyncValue<List<StolenReport>> mine) {
    return [
      mine.when(
        loading: () => const _MyReportsSummary(active: null, total: null),
        error: (_, _) => const _MyReportsSummary(active: null, total: null),
        data: (reports) => _MyReportsSummary(
          active: reports.where((report) => report.isStolen).length,
          total: reports.length,
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: reportStolen,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            minimumSize: const Size.fromHeight(50),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Report another vehicle'),
        ),
      ),
      const SizedBox(height: 24),
      const _SectionHeading(
        eyebrow: 'MY CASES',
        title: 'Theft reports and sightings',
      ),
      const SizedBox(height: 12),
      mine.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => _InlineError(
          message: error is ApiFailure
              ? error.message
              : 'Your reports could not be loaded.',
          onRetry: () => ref.invalidate(myStolenReportsProvider),
        ),
        data: (reports) => reports.isEmpty
            ? const _EmptyMine()
            : Column(
                children: reports
                    .map(
                      (report) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MyReportCard(
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

class _SecurityHeader extends StatelessWidget {
  const _SecurityHeader({
    required this.selected,
    required this.reportsCount,
    required this.onSelected,
  });

  final _SecurityView selected;
  final int? reportsCount;
  final ValueChanged<_SecurityView> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.forest900,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle Security',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Search, report and help recover.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Container(
          height: 46,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EFEC),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              _ViewButton(
                label: 'Registry',
                icon: Icons.search_rounded,
                selected: selected == _SecurityView.registry,
                onTap: () => onSelected(_SecurityView.registry),
              ),
              _ViewButton(
                label: reportsCount == null
                    ? 'My reports'
                    : 'My reports  $reportsCount',
                icon: Icons.folder_copy_outlined,
                selected: selected == _SecurityView.myReports,
                onTap: () => onSelected(_SecurityView.myReports),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        elevation: selected ? 1 : 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppColors.forest700 : AppColors.muted,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.forest900 : AppColors.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlateCheckPanel extends StatelessWidget {
  const _PlateCheckPanel({
    required this.controller,
    required this.checking,
    required this.result,
    required this.error,
    required this.onCheck,
    required this.onOpenRecord,
    required this.onReportSighting,
  });

  final TextEditingController controller;
  final bool checking;
  final StolenCheckResult? result;
  final String? error;
  final VoidCallback onCheck;
  final ValueChanged<String> onOpenRecord;
  final ValueChanged<String> onReportSighting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, Color(0xFF07523B)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26021B13),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_search_rounded, color: Color(0xFF71E2B8)),
              SizedBox(width: 8),
              Text(
                'INSTANT PLATE CHECK',
                style: TextStyle(
                  color: Color(0xFF9ED6C0),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Verify before you transact.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Check a plate against Travla’s active theft registry.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .62),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
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
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                  decoration: InputDecoration(
                    hintText: 'LAG-123-XY',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: .32),
                    ),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: .18),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: .14),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: .14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: checking ? null : onCheck,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.forest950,
                    disabledBackgroundColor: Colors.white.withValues(alpha: .7),
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                  ),
                  child: checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Check',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFFFC2BC), fontSize: 12),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            _PlateResult(
              result: result!,
              onOpenRecord: onOpenRecord,
              onReportSighting: onReportSighting,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlateResult extends StatelessWidget {
  const _PlateResult({
    required this.result,
    required this.onOpenRecord,
    required this.onReportSighting,
  });

  final StolenCheckResult result;
  final ValueChanged<String> onOpenRecord;
  final ValueChanged<String> onReportSighting;

  @override
  Widget build(BuildContext context) {
    final stolen = result.isStolen && result.report != null;
    final report = result.report;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: stolen
            ? AppColors.danger.withValues(alpha: .18)
            : const Color(0xFF0A6949),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: stolen
              ? const Color(0xFFFF8E83).withValues(alpha: .5)
              : const Color(0xFF71E2B8).withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                stolen ? Icons.gpp_bad_rounded : Icons.verified_user_outlined,
                color: stolen
                    ? const Color(0xFFFF8E83)
                    : const Color(0xFF71E2B8),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  stolen
                      ? '${result.plate.toUpperCase()} is actively reported stolen.'
                      : 'No active Travla report was found for ${result.plate.toUpperCase()}.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            stolen
                ? 'Do not approach, pursue or transact. Contact the appropriate authorities when safe.'
                : 'This community check is not a substitute for official vehicle verification.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .65),
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
          if (report != null) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onOpenRecord(report.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .3),
                      ),
                    ),
                    child: const Text('View record'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => onReportSighting(report.id),
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onReport, required this.onManage});

  final VoidCallback onReport;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.campaign_outlined,
            title: 'Report stolen',
            subtitle: 'Alert Travla',
            foreground: AppColors.danger,
            background: const Color(0xFFFFEEEC),
            onTap: onReport,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: Icons.fact_check_outlined,
            title: 'My reports',
            subtitle: 'Review sightings',
            foreground: AppColors.forest700,
            background: AppColors.forest50,
            onTap: onManage,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityPulse extends StatelessWidget {
  const _SecurityPulse({required this.stats});

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
                'Registry pulse',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${stats.recoveryRate}% recovery rate',
              style: const TextStyle(
                color: AppColors.forest700,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _PulseCard(
                value: '${stats.currentlyStolen}',
                label: 'Active reports',
                icon: Icons.gpp_bad_outlined,
                color: AppColors.danger,
              ),
              _PulseCard(
                value: '${stats.recovered}',
                label: 'Recovered',
                icon: Icons.task_alt_rounded,
                color: AppColors.forest700,
              ),
              _PulseCard(
                value: '${stats.totalSightings}',
                label: 'Verified sightings',
                icon: Icons.visibility_outlined,
                color: AppColors.orangeDark,
              ),
              _PulseCard(
                value: '${stats.recentSightings}',
                label: 'Sightings this week',
                icon: Icons.today_outlined,
                color: const Color(0xFF2855A6),
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulseCard extends StatelessWidget {
  const _PulseCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.last = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      margin: EdgeInsets.only(right: last ? 0 : 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 11),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EFEC),
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    this.detail,
  });

  final String eyebrow;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (detail != null)
          Text(
            detail!,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
      ],
    );
  }
}

class _RegistrySearch extends StatelessWidget {
  const _RegistrySearch({
    required this.controller,
    required this.filters,
    required this.onSearch,
    required this.onFilter,
    required this.onReset,
  });

  final TextEditingController controller;
  final StolenDirectoryFilters filters;
  final ValueChanged<String> onSearch;
  final VoidCallback onFilter;
  final VoidCallback onReset;

  int get filterCount => [
    filters.location?.isNotEmpty == true,
    filters.make?.isNotEmpty == true,
    filters.color?.isNotEmpty == true,
    filters.hasReward,
    filters.reportedWithinDays != null,
    filters.sort != 'newest',
  ].where((active) => active).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                onSubmitted: onSearch,
                decoration: InputDecoration(
                  hintText: 'Plate, make, model or place',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            controller.clear();
                            onSearch('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              backgroundColor: AppColors.orange,
              child: IconButton.filledTonal(
                tooltip: 'Filter registry',
                onPressed: onFilter,
                style: IconButton.styleFrom(
                  minimumSize: const Size(50, 50),
                  backgroundColor: filterCount > 0
                      ? AppColors.forest100
                      : const Color(0xFFE8EFEC),
                  foregroundColor: AppColors.forest800,
                ),
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ],
        ),
        if (!filters.isDefault) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size: 15,
                color: AppColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _filterSummary(filters),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
              TextButton(onPressed: onReset, child: const Text('Clear all')),
            ],
          ),
        ],
      ],
    );
  }

  String _filterSummary(StolenDirectoryFilters value) {
    final parts = <String>[
      if (value.location?.isNotEmpty == true) value.location!,
      if (value.make?.isNotEmpty == true) value.make!,
      if (value.color?.isNotEmpty == true) value.color!,
      if (value.hasReward) 'Rewards',
      if (value.reportedWithinDays != null)
        'Last ${value.reportedWithinDays} days',
      if (value.sort == 'sightings') 'Most sightings',
      if (value.sort == 'reward') 'Highest reward',
    ];
    return parts.isEmpty ? 'Search active' : parts.join(' · ');
  }
}

class _MobileRegistryCard extends StatelessWidget {
  const _MobileRegistryCard({
    required this.report,
    required this.onOpen,
    required this.onSighting,
  });

  final StolenReport report;
  final VoidCallback onOpen;
  final VoidCallback onSighting;

  bool get hasReward =>
      report.rewardNaira != null && report.rewardNaira != '0.00';

  @override
  Widget build(BuildContext context) {
    final vehicle = report.vehicle;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 154,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (vehicle?.images.isNotEmpty == true)
                    Image.network(
                      vehicle!.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _VehiclePlaceholder(),
                    )
                  else
                    const _VehiclePlaceholder(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xC9000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _StatusPill(label: report.statusLabel),
                  ),
                  if (hasReward)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '₦${report.rewardNaira} reward',
                          style: const TextStyle(
                            color: AppColors.forest800,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              if (vehicle?.year != null) '${vehicle!.year}',
                              if (vehicle?.name.isNotEmpty == true)
                                vehicle!.name,
                            ].join(' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (vehicle?.plateNumber?.isNotEmpty == true)
                          _PlateTag(plate: vehicle!.plateNumber!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _RecordDetail(
                          icon: Icons.location_on_outlined,
                          label: 'Last seen',
                          value: report.lastKnownLocation ?? 'Not provided',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _RecordDetail(
                          icon: Icons.visibility_outlined,
                          label: 'Community',
                          value:
                              '${report.sightingsCount ?? 0} verified sighting${report.sightingsCount == 1 ? '' : 's'}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onOpen,
                          child: const Text('View details'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onSighting,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.danger,
                          ),
                          icon: const Icon(
                            Icons.add_location_alt_outlined,
                            size: 17,
                          ),
                          label: const Text('I saw it'),
                        ),
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

class _VehiclePlaceholder extends StatelessWidget {
  const _VehiclePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFCEDBD6), Color(0xFF9FB4AC)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car_outlined,
          size: 44,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlateTag extends StatelessWidget {
  const _PlateTag({required this.plate});
  final String plate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Text(
        plate.toUpperCase(),
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    );
  }
}

class _RecordDetail extends StatelessWidget {
  const _RecordDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.forest700),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyReportsSummary extends StatelessWidget {
  const _MyReportsSummary({required this.active, required this.total});

  final int? active;
  final int? total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forest900, AppColors.forest700],
        ),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.folder_shared_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your security cases',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active == null
                      ? 'Loading case activity…'
                      : '$active active · $total total reports',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .65),
                    fontSize: 11.5,
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

class _MyReportCard extends StatelessWidget {
  const _MyReportCard({required this.report, required this.onTap});

  final StolenReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vehicle = report.vehicle;
    final active = report.isStolen;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: vehicle?.images.isNotEmpty == true
                      ? Image.network(
                          vehicle!.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const _VehiclePlaceholder(),
                        )
                      : const _VehiclePlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vehicle?.name ?? 'Vehicle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFFFE3E1)
                                : AppColors.forest50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            report.statusLabel,
                            style: TextStyle(
                              color: active
                                  ? AppColors.danger
                                  : AppColors.forest700,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vehicle?.plateNumber ?? 'Plate not available',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: AppColors.orangeDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${report.sightingsCount ?? 0} sighting${report.sightingsCount == 1 ? '' : 's'} to review',
                          style: const TextStyle(
                            color: AppColors.orangeDark,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5D9),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFF0D48B)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined, color: Color(0xFF8A5A00)),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'See a reported vehicle? Keep a safe distance. Do not confront or pursue anyone. Contact the appropriate authorities, then submit a precise sighting when safe.',
              style: TextStyle(
                color: Color(0xFF684500),
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRegistry extends StatelessWidget {
  const _EmptyRegistry();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No matching active report',
      message: 'Try a broader search or clear the current filters.',
    );
  }
}

class _EmptyMine extends StatelessWidget {
  const _EmptyMine();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.verified_user_outlined,
      title: 'No theft reports',
      message:
          'Hopefully it stays that way. Any report you create will appear here.',
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _RegistryFilterSheet extends StatefulWidget {
  const _RegistryFilterSheet({required this.initial});

  final StolenDirectoryFilters initial;

  @override
  State<_RegistryFilterSheet> createState() => _RegistryFilterSheetState();
}

class _RegistryFilterSheetState extends State<_RegistryFilterSheet> {
  late final _locationController = TextEditingController(
    text: widget.initial.location,
  );
  late final _makeController = TextEditingController(text: widget.initial.make);
  late final _colorController = TextEditingController(
    text: widget.initial.color,
  );
  late bool _hasReward = widget.initial.hasReward;
  late int? _reportedWithin = widget.initial.reportedWithinDays;
  late String _sort = widget.initial.sort;

  @override
  void dispose() {
    _locationController.dispose();
    _makeController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _reset() {
    _locationController.clear();
    _makeController.clear();
    _colorController.clear();
    setState(() {
      _hasReward = false;
      _reportedWithin = null;
      _sort = 'newest';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refine registry',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Narrow active reports without losing your search.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Last seen near',
                hintText: 'e.g. Lekki, Abuja',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _makeController,
                    decoration: const InputDecoration(
                      labelText: 'Make',
                      hintText: 'Toyota',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _colorController,
                    decoration: const InputDecoration(
                      labelText: 'Colour',
                      hintText: 'Black',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sort,
              decoration: const InputDecoration(
                labelText: 'Sort records',
                prefixIcon: Icon(Icons.sort_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'newest',
                  child: Text('Recently reported'),
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
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _reportedWithin,
              decoration: const InputDecoration(
                labelText: 'Date reported',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Any time')),
                DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                DropdownMenuItem(value: 90, child: Text('Last 90 days')),
              ],
              onChanged: (value) => setState(() => _reportedWithin = value),
            ),
            const SizedBox(height: 7),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.danger,
              title: const Text(
                'Only show reward offers',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              value: _hasReward,
              onChanged: (value) => setState(() => _hasReward = value),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  StolenDirectoryFilters(
                    query: widget.initial.query,
                    location: _locationController.text.trim(),
                    make: _makeController.text.trim(),
                    color: _colorController.text.trim(),
                    hasReward: _hasReward,
                    reportedWithinDays: _reportedWithin,
                    sort: _sort,
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.forest700,
                ),
                child: const Text('Show matching vehicles'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetIcon extends StatelessWidget {
  const _SheetIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: AppColors.forest700, size: 28),
    );
  }
}
