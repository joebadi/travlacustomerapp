import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/stolen/data/stolen_repository.dart';
import 'package:travla_customer_app/features/stolen/domain/stolen_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';

/// The "Stolen" tab inside Car Talk. Headless (no Scaffold/AppBar/FAB of its
/// own) so it can live inside CarTalkScreen's TabBarView. "Report stolen"
/// needs this tab's own vehicle-picker sheet, so CarTalkScreen reaches it
/// through a `GlobalKey<StolenFeedTabState>` calling [reportStolen].
class StolenFeedTab extends ConsumerStatefulWidget {
  const StolenFeedTab({super.key});

  @override
  ConsumerState<StolenFeedTab> createState() => StolenFeedTabState();
}

class StolenFeedTabState extends ConsumerState<StolenFeedTab> {
  final _plateCtrl = TextEditingController();
  final _registryQueryCtrl = TextEditingController();
  bool _checking = false;
  StolenCheckResult? _result;
  String? _searchError;

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
    _plateCtrl.dispose();
    _registryQueryCtrl.dispose();
    super.dispose();
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
      final nextPage = loadMore ? (_directory?.page ?? 0) + 1 : 1;
      final page = await ref
          .read(stolenRepositoryProvider)
          .directory(filters: _filters, page: nextPage);
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

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<StolenDirectoryFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RegistryFilterSheet(initial: _filters),
    );
    if (result != null) {
      setState(() => _filters = result);
      _loadDirectory();
    }
  }

  Future<void> _check() async {
    final plate = _plateCtrl.text.trim();
    if (plate.isEmpty) return;
    setState(() {
      _checking = true;
      _searchError = null;
      _result = null;
    });
    try {
      final result = await ref.read(stolenRepositoryProvider).checkPlate(plate);
      if (mounted) setState(() => _result = result);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _searchError = failure.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// Opens the vehicle-picker sheet to report a theft — called by
  /// CarTalkScreen's FAB when the Stolen tab is active.
  void reportStolen() {
    final vehicles = ref.read(garageProvider).value?.vehicles ?? const [];
    if (vehicles.isEmpty) {
      _snack('Add a vehicle first, then you can report it stolen.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Text(
                'Which vehicle was stolen?',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: vehicles
                    .map(
                      (v) => ListTile(
                        leading: const Icon(
                          Icons.directions_car_outlined,
                          color: AppColors.forest700,
                        ),
                        title: Text(
                          v.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: v.plateNumber?.isNotEmpty == true
                            ? Text(v.plateNumber!)
                            : null,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          context.push('/more/stolen/report?vehicle=${v.id}');
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myStolenReportsProvider);
    final stats = ref.watch(stolenStatsProvider);

    return RefreshIndicator(
      color: AppColors.forest700,
      onRefresh: () async {
        ref.invalidate(myStolenReportsProvider);
        ref.invalidate(stolenStatsProvider);
        await Future.wait([
          ref
              .read(myStolenReportsProvider.future)
              .catchError((_) => <StolenReport>[]),
          _loadDirectory(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _SearchCard(
            controller: _plateCtrl,
            checking: _checking,
            onCheck: _check,
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 10),
            Text(
              _searchError!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            _CheckResultCard(
              result: _result!,
              onSighting: (id) => context.push('/more/stolen/$id/sighting'),
            ),
          ],
          const SizedBox(height: 22),
          const _Label('Community registry'),
          stats.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (value) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RegistryStatsRow(stats: value),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _registryQueryCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    setState(
                      () => _filters = _filters.copyWith(query: v.trim()),
                    );
                    _loadDirectory();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search plate, make, model or place',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: _filters.isDefault
                    ? AppColors.canvas
                    : AppColors.forest50,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _openFilters,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: _filters.isDefault
                          ? AppColors.muted
                          : AppColors.forest700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_directoryLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_directoryError != null)
            Text(
              _directoryError!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
            )
          else if ((_directory?.items ?? const []).isEmpty)
            const _EmptyRegistry()
          else ...[
            Text(
              '${_directory!.total} active record${_directory!.total == 1 ? '' : 's'} found',
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
            ),
            const SizedBox(height: 10),
            ..._directory!.items.map(
              (r) => _RegistryCard(
                report: r,
                onTap: () => context.push('/more/stolen/${r.id}'),
              ),
            ),
            if (_directory!.hasMore) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: _directoryLoadingMore
                      ? null
                      : () => _loadDirectory(loadMore: true),
                  child: _directoryLoadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load more'),
                ),
              ),
            ],
          ],
          const SizedBox(height: 22),
          const _Label('Your reports'),
          mine.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              error is ApiFailure
                  ? error.message
                  : 'Your reports could not be loaded.',
              style: const TextStyle(color: AppColors.muted),
            ),
            data: (reports) => reports.isEmpty
                ? const _EmptyMine()
                : Column(
                    children: reports
                        .map((r) => _ReportRow(report: r))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.checking,
    required this.onCheck,
  });

  final TextEditingController controller;
  final bool checking;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Check a plate',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 2),
          const Text(
            'Buying used? Check if a vehicle is flagged stolen.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onCheck(),
                  decoration: const InputDecoration(
                    hintText: 'Plate number',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: checking ? null : onCheck,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest700,
                  ),
                  child: checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
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
        ],
      ),
    );
  }
}

class _CheckResultCard extends StatelessWidget {
  const _CheckResultCard({required this.result, required this.onSighting});

  final StolenCheckResult result;
  final void Function(String reportId) onSighting;

  @override
  Widget build(BuildContext context) {
    if (!result.isStolen || result.report == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFDDF2E8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.forest700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${result.plate.toUpperCase()} is not flagged stolen in the registry.',
                style: const TextStyle(
                  color: AppColors.forest800,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final report = result.report!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5BBB5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_maybe_rounded, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Flagged STOLEN',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${report.vehicle?.name ?? 'Vehicle'} · ${report.vehicle?.plateNumber ?? result.plate}',
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          if (report.lastKnownLocation != null) ...[
            const SizedBox(height: 3),
            Text(
              'Last seen: ${report.lastKnownLocation}',
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          if (report.rewardNaira != null && report.rewardNaira != '0.00') ...[
            const SizedBox(height: 3),
            Text(
              'Reward: ₦${report.rewardNaira}',
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onSighting(report.id),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
              label: const Text('I have seen this vehicle'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});

  final StolenReport report;

  @override
  Widget build(BuildContext context) {
    final tone = switch (report.status) {
      'RECOVERED' => (const Color(0xFF075B40), const Color(0xFFDDF2E8)),
      'CLOSED' => (const Color(0xFF53615B), const Color(0xFFEDF0EF)),
      _ => (AppColors.danger, const Color(0xFFFFE3E1)),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => context.push('/more/stolen/${report.id}'),
        title: Text(
          report.vehicle?.name ?? 'Vehicle',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            if (report.vehicle?.plateNumber != null)
              report.vehicle!.plateNumber!,
            if (report.sightingsCount != null)
              '${report.sightingsCount} sighting${report.sightingsCount == 1 ? '' : 's'}',
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: tone.$2,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            report.statusLabel,
            style: TextStyle(
              color: tone.$1,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMine extends StatelessWidget {
  const _EmptyMine();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'You have no stolen reports. If a vehicle is stolen, report it here to alert the community.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
    );
  }
}

/// Compact strip of registry-wide counters — the mobile equivalent of the
/// web directory's 5-stat row, condensed to fit a phone width.
class _RegistryStatsRow extends StatelessWidget {
  const _RegistryStatsRow({required this.stats});

  final StolenStats stats;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatChip(
            label: 'Active reports',
            value: '${stats.currentlyStolen}',
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Recovered',
            value: '${stats.recovered}',
            color: AppColors.forest700,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Recovery rate',
            value: '${stats.recoveryRate}%',
            color: AppColors.orangeDark,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Sightings',
            value: '${stats.totalSightings}',
            color: AppColors.ink,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A browsable registry entry — mirrors the web directory's VehicleCard:
/// plate, last-seen location, sightings count, reward badge.
class _RegistryCard extends StatelessWidget {
  const _RegistryCard({required this.report, required this.onTap});

  final StolenReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vehicle = report.vehicle;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: vehicle != null && vehicle.images.isNotEmpty
                    ? Image.network(
                        vehicle.images.first,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _photoPlaceholder(),
                      )
                    : _photoPlaceholder(),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        if (vehicle?.plateNumber != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3D6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.ink),
                            ),
                            child: Text(
                              vehicle!.plateNumber!,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (report.lastKnownLocation != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last seen: ${report.lastKnownLocation}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _pill(
                          '${report.sightingsCount ?? 0} sighting${(report.sightingsCount ?? 0) == 1 ? '' : 's'}',
                          AppColors.forest700,
                          AppColors.forest50,
                        ),
                        if (report.rewardNaira != null &&
                            report.rewardNaira != '0.00')
                          _pill(
                            '₦${report.rewardNaira} reward',
                            AppColors.orangeDark,
                            const Color(0xFFFFE9E1),
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

  Widget _photoPlaceholder() => Container(
    width: 64,
    height: 64,
    color: AppColors.canvas,
    child: const Icon(Icons.directions_car_outlined, color: AppColors.muted),
  );

  Widget _pill(String label, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.w800),
    ),
  );
}

class _EmptyRegistry extends StatelessWidget {
  const _EmptyRegistry();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'No active report matches those details. Try a broader search or clear the filters.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
    );
  }
}

/// Bottom-sheet filter form for the public registry — mirrors the web
/// directory's filter card (location, make, colour, reward, recency, sort).
class _RegistryFilterSheet extends StatefulWidget {
  const _RegistryFilterSheet({required this.initial});

  final StolenDirectoryFilters initial;

  @override
  State<_RegistryFilterSheet> createState() => _RegistryFilterSheetState();
}

class _RegistryFilterSheetState extends State<_RegistryFilterSheet> {
  late final _locationCtrl = TextEditingController(
    text: widget.initial.location,
  );
  late final _makeCtrl = TextEditingController(text: widget.initial.make);
  late final _colorCtrl = TextEditingController(text: widget.initial.color);
  late bool _hasReward = widget.initial.hasReward;
  late int? _reportedWithin = widget.initial.reportedWithinDays;
  late String _sort = widget.initial.sort;

  @override
  void dispose() {
    _locationCtrl.dispose();
    _makeCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter the registry',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const StolenDirectoryFilters()),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Last seen near',
                  hintText: 'e.g. Lekki, Abuja',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _makeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vehicle make',
                  hintText: 'e.g. Toyota',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _colorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Colour',
                  hintText: 'e.g. Black',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _sort,
                decoration: const InputDecoration(labelText: 'Sort by'),
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
                onChanged: (v) => setState(() => _sort = v ?? 'newest'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _reportedWithin,
                decoration: const InputDecoration(labelText: 'Date reported'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any time')),
                  DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                  DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                  DropdownMenuItem(value: 90, child: Text('Last 90 days')),
                ],
                onChanged: (v) => setState(() => _reportedWithin = v),
              ),
              const SizedBox(height: 6),
              CheckboxListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _hasReward,
                onChanged: (v) => setState(() => _hasReward = v ?? false),
                title: const Text(
                  'Only show reward offers',
                  style: TextStyle(fontSize: 13.5),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest700,
                  ),
                  onPressed: () => Navigator.of(context).pop(
                    StolenDirectoryFilters(
                      query: widget.initial.query,
                      location: _locationCtrl.text.trim(),
                      make: _makeCtrl.text.trim(),
                      color: _colorCtrl.text.trim(),
                      hasReward: _hasReward,
                      reportedWithinDays: _reportedWithin,
                      sort: _sort,
                    ),
                  ),
                  child: const Text('Apply filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
}
