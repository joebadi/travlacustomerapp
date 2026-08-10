import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/home/presentation/dashboard_header_actions.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

/// Premium garage — a branded hero header with a readiness summary, quick filters
/// and edge-to-edge vehicle cards. Candidate pattern for the wider app.
class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  String _filter = 'ALL';

  Future<void> _refresh() async {
    ref.invalidate(garageProvider);
    await ref.read(garageProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final garage = ref.watch(garageProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _Header()),
            garage.when(
              loading: () => const SliverToBoxAdapter(child: _GarageLoading()),
              error: (error, _) => SliverToBoxAdapter(
                child: _GarageError(
                  message: error is ApiFailure
                      ? error.message
                      : 'Your vehicle workspace could not be loaded.',
                  onRetry: () => ref.invalidate(garageProvider),
                ),
              ),
              data: (snapshot) => _content(context, snapshot),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, GarageSnapshot snapshot) {
    final hasAny =
        snapshot.vehicles.isNotEmpty || snapshot.incomingVehicles.isNotEmpty;
    if (!hasAny && snapshot.pendingTransfers.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyGarage());
    }

    final filtered = _applyFilter(snapshot.vehicles);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
      sliver: SliverList.list(
        children: [
          _GarageActionBar(
            snapshot: snapshot,
            value: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 16),
          if (snapshot.pendingTransfers.isNotEmpty) ...[
            ...snapshot.pendingTransfers.map(_PendingTransferBanner.new),
            const SizedBox(height: 8),
          ],
          if (snapshot.incomingVehicles.isNotEmpty && _filter == 'ALL') ...[
            const _GroupLabel('Incoming ownership'),
            ...snapshot.incomingVehicles.map(_IncomingVehicleCard.new),
            const SizedBox(height: 10),
          ],
          if (snapshot.vehicles.isNotEmpty) const _GroupLabel('Your vehicles'),
          if (filtered.isEmpty && snapshot.vehicles.isNotEmpty)
            const _NoMatch()
          else
            ...filtered.map((v) => _VehicleCard(vehicle: v)),
        ],
      ),
    );
  }

  List<VehicleSummary> _applyFilter(List<VehicleSummary> vehicles) {
    return switch (_filter) {
      'VALID' => vehicles.where((v) => v.status == 'VALID').toList(),
      'EXPIRING_SOON' =>
        vehicles.where((v) => v.status == 'EXPIRING_SOON').toList(),
      'EXPIRED' => vehicles.where((v) => v.status == 'EXPIRED').toList(),
      'NONE' => vehicles.where((v) => v.status == null).toList(),
      _ => vehicles,
    };
  }
}

// ── Header (slim, brand only) ───────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 14,
        20,
        18,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: const [
          TravlaLogo(onDark: true, width: 116),
          Spacer(),
          DashboardHeaderActions(),
        ],
      ),
    );
  }
}

// ── Action bar: collapsible filters (left) + tap-to-reveal actions (right) ───
class _GarageActionBar extends StatefulWidget {
  const _GarageActionBar({
    required this.snapshot,
    required this.value,
    required this.onChanged,
  });

  final GarageSnapshot snapshot;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_GarageActionBar> createState() => _GarageActionBarState();
}

class _GarageActionBarState extends State<_GarageActionBar> {
  bool _filtersOpen = false;

  /// Which action pill is currently expanded to reveal its label. A second tap
  /// on the expanded pill runs its action; tapping a collapsed one expands it.
  String? _openAction;

  static const _duration = Duration(milliseconds: 200);
  static const _curve = Curves.easeOutCubic;

  List<({String key, String label, int count})> get _chips {
    final s = widget.snapshot;
    final noneCount = s.vehicles.where((v) => v.status == null).length;
    return [
      (key: 'ALL', label: 'All', count: s.vehicles.length),
      (key: 'VALID', label: 'Valid', count: s.validCount),
      (key: 'EXPIRING_SOON', label: 'Expiring', count: s.expiringCount),
      (key: 'EXPIRED', label: 'Expired', count: s.expiredCount),
      (key: 'NONE', label: 'No papers', count: noneCount),
    ];
  }

  void _tapAction(String key, VoidCallback run) {
    if (_openAction == key) {
      run();
      setState(() => _openAction = null);
    } else {
      setState(() {
        _openAction = key;
        _filtersOpen = false;
      });
    }
  }

  void _openFilters() => setState(() {
    _filtersOpen = true;
    _openAction = null;
  });

  void _pickFilter(String key) {
    widget.onChanged(key);
    setState(() => _filtersOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasVehicles = widget.snapshot.vehicles.isNotEmpty;

    return SizedBox(
      height: 46,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasVehicles)
            Expanded(
              child: AnimatedSwitcher(
                duration: _duration,
                switchInCurve: _curve,
                switchOutCurve: _curve,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    axis: Axis.horizontal,
                    axisAlignment: -1,
                    sizeFactor: animation,
                    child: child,
                  ),
                ),
                child: _filtersOpen
                    ? _expandedFilters()
                    : _collapsedFilter(),
              ),
            )
          else
            const Spacer(),
          _actionCluster(context),
        ],
      ),
    );
  }

  // — Filters —
  Widget _collapsedFilter() {
    final active = _chips.firstWhere(
      (c) => c.key == widget.value,
      orElse: () => _chips.first,
    );
    final isAll = active.key == 'ALL';
    return Align(
      key: const ValueKey('filters-collapsed'),
      alignment: Alignment.centerLeft,
      child: Material(
        color: isAll ? AppColors.white : AppColors.forest700,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _openFilters,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isAll ? AppColors.border : AppColors.forest700,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: isAll ? AppColors.forest700 : AppColors.white,
                ),
                const SizedBox(width: 7),
                Text(
                  active.label,
                  style: TextStyle(
                    color: isAll ? AppColors.ink : AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${active.count}',
                  style: TextStyle(
                    color: isAll
                        ? AppColors.muted
                        : Colors.white.withValues(alpha: .82),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expandedFilters() {
    final chips = _chips;
    return SizedBox(
      key: const ValueKey('filters-expanded'),
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final active = chip.key == widget.value;
          return GestureDetector(
            onTap: () => _pickFilter(chip.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.forest700 : AppColors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: active ? AppColors.forest700 : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    chip.label,
                    style: TextStyle(
                      color: active ? AppColors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${chip.count}',
                    style: TextStyle(
                      color: active
                          ? Colors.white.withValues(alpha: .8)
                          : AppColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // — Actions —
  Widget _actionCluster(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionPill(
          icon: Icons.verified_user_outlined,
          label: 'Claim',
          open: _openAction == 'claim',
          duration: _duration,
          curve: _curve,
          onTap: () => _tapAction('claim', () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Vehicle claiming is coming to the app soon.'),
                ),
              );
          }),
        ),
        const SizedBox(width: 8),
        _ActionPill(
          icon: Icons.note_add_outlined,
          label: 'Register new',
          open: _openAction == 'register',
          duration: _duration,
          curve: _curve,
          onTap: () => _tapAction(
            'register',
            () => context.go('/vehicles/register-new'),
          ),
        ),
        const SizedBox(width: 8),
        _ActionPill(
          icon: Icons.add_rounded,
          label: 'Add vehicle',
          accent: true,
          open: _openAction == 'add',
          duration: _duration,
          curve: _curve,
          onTap: () => _tapAction(
            'add',
            () => context.go('/vehicles/add-existing'),
          ),
        ),
      ],
    );
  }
}

/// A circular icon button that grows into a labelled pill on first tap; the
/// second tap (while open) runs [onTap]'s action.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.open,
    required this.onTap,
    required this.duration,
    required this.curve,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final bool open;
  final VoidCallback onTap;
  final Duration duration;
  final Curve curve;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final bg = accent ? AppColors.orange : AppColors.white;
    final fg = accent ? AppColors.white : AppColors.forest800;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: curve,
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: open ? 15 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: accent
                ? null
                : Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fg),
              AnimatedSize(
                duration: duration,
                curve: curve,
                child: open
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 11),
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

// ── Vehicle card ────────────────────────────────────────────────────────────
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final VehicleSummary vehicle;

  @override
  Widget build(BuildContext context) {
    final status = _StatusStyle.from(vehicle.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest950.withValues(alpha: .06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/vehicles/${vehicle.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 172,
                  width: double.infinity,
                  child: vehicle.images.isEmpty
                      ? const _VehicleImageFallback()
                      : Image.network(
                          vehicle.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const _VehicleImageFallback(),
                        ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.forest950.withValues(alpha: .72),
                        ],
                        stops: const [0.45, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _StatusPill(
                    label: vehicle.statusLabel ?? 'Papers not added',
                    style: status,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.displayName.isEmpty
                            ? 'Vehicle'
                            : vehicle.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (vehicle.year != null) vehicle.year.toString(),
                          if (vehicle.color.isNotEmpty) vehicle.color,
                        ].join('  ·  '),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .82),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
              child: Row(
                children: [
                  _PlateChip(plate: vehicle.plateNumber),
                  const Spacer(),
                  _Readiness(vehicle: vehicle),
                  const SizedBox(width: 10),
                  _ManageButton(
                    onTap: () => _showVehicleActions(context, vehicle),
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

class _PlateChip extends StatelessWidget {
  const _PlateChip({required this.plate});

  final String? plate;

  @override
  Widget build(BuildContext context) {
    final hasPlate = plate?.isNotEmpty == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.ink.withValues(alpha: .35),
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 4, height: 15, color: AppColors.forest700),
          const SizedBox(width: 8),
          Text(
            hasPlate ? plate!.toUpperCase() : 'NO PLATE',
            style: TextStyle(
              color: hasPlate ? AppColors.ink : AppColors.muted,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.5,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _Readiness extends StatelessWidget {
  const _Readiness({required this.vehicle});

  final VehicleSummary vehicle;

  @override
  Widget build(BuildContext context) {
    if (vehicle.documentsCount == 0) {
      return const Text(
        'No papers',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (vehicle.expiredDocumentsCount > 0) {
      return _Pill(
        color: AppColors.danger,
        text: '${vehicle.expiredDocumentsCount} expired',
      );
    }
    if (vehicle.expiringSoonCount > 0) {
      return _Pill(
        color: AppColors.orangeDark,
        text: '${vehicle.expiringSoonCount} expiring',
      );
    }
    return _Pill(
      color: AppColors.forest700,
      text: '${vehicle.documentsCount} valid',
      icon: Icons.check_circle_rounded,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.text, this.icon});

  final Color color;
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon ?? Icons.circle, size: icon == null ? 8 : 15, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ManageButton extends StatelessWidget {
  const _ManageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forest50,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.forest100),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Manage',
                style: TextStyle(
                  color: AppColors.forest800,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.forest700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-vehicle action menu — mirrors the web vehicle actions (open, papers,
/// renew, sell, transfer). Surfaced from the card's "Manage" affordance.
Future<void> _showVehicleActions(
  BuildContext context,
  VehicleSummary vehicle,
) {
  final id = vehicle.id;
  final name = vehicle.displayName.isEmpty ? 'this vehicle' : vehicle.displayName;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      void go(String location) {
        Navigator.of(sheetContext).pop();
        context.push(location);
      }

      void goTab(String location) {
        Navigator.of(sheetContext).pop();
        context.go(location);
      }

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              _ActionRow(
                icon: Icons.dashboard_customize_outlined,
                label: 'Open vehicle',
                subtitle: 'Overview, papers, tracking',
                onTap: () => go('/vehicles/$id'),
              ),
              _ActionRow(
                icon: Icons.folder_copy_outlined,
                label: 'Documents & papers',
                subtitle: 'View and upload vehicle papers',
                onTap: () => go('/vehicles/$id?tab=documents'),
              ),
              _ActionRow(
                icon: Icons.autorenew_rounded,
                label: 'Renew papers',
                subtitle: 'Renew or register vehicle documents',
                onTap: () => goTab('/more/renewals/new?vehicle=$id'),
              ),
              _ActionRow(
                icon: Icons.sell_outlined,
                label: 'Sell on marketplace',
                subtitle: 'List this vehicle for sale',
                onTap: () => goTab('/more/marketplace/list-new?vehicle=$id'),
              ),
              _ActionRow(
                icon: Icons.swap_horiz_rounded,
                label: 'Transfer ownership',
                subtitle: 'Hand this vehicle to another owner',
                onTap: () => goTab('/more/transfers/new?vehicle=$id'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.forest50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.forest700),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.style});

  final String label;
  final _StatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: style.foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _VehicleImageFallback extends StatelessWidget {
  const _VehicleImageFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest800, AppColors.forest600],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car_filled_rounded,
          size: 64,
          color: Colors.white24,
        ),
      ),
    );
  }
}

// ── Incoming ────────────────────────────────────────────────────────────────
class _PendingTransferBanner extends StatelessWidget {
  const _PendingTransferBanner(this.transfer);

  final IncomingTransferSummary transfer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC9B7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/more/transfers/${transfer.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Incoming ownership transfer',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${transfer.currentOwnerName} is transferring ${transfer.vehicleName.isEmpty ? 'a vehicle' : transfer.vehicleName} to you.',
                      style: const TextStyle(
                        color: AppColors.orangeDark,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.orangeDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomingVehicleCard extends StatelessWidget {
  const _IncomingVehicleCard(this.transfer);

  final IncomingTransferSummary transfer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/more/transfers/${transfer.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE2E0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_car_outlined,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transfer.vehicleName.isEmpty
                          ? 'Incoming vehicle'
                          : transfer.vehicleName,
                      style: const TextStyle(
                        color: Color(0xFF53615B),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      transfer.plateNumber?.isNotEmpty == true
                          ? transfer.plateNumber!
                          : 'Plate not assigned',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orangeSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        transfer.reviewStatusLabel.isEmpty
                            ? 'Transfer in progress'
                            : transfer.reviewStatusLabel,
                        style: const TextStyle(
                          color: AppColors.orangeDark,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── States ──────────────────────────────────────────────────────────────────
class _EmptyGarage extends StatelessWidget {
  const _EmptyGarage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.forest100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_road_rounded,
                size: 34,
                color: AppColors.forest700,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Start with your first vehicle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a vehicle that already has a plate number. New or imported vehicles use the separate registration process.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go('/vehicles/add-existing'),
                icon: const Icon(Icons.add_road_rounded),
                label: const Text('Add existing vehicle'),
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/vehicles/register-new'),
                icon: const Icon(Icons.assignment_add),
                label: const Text('Register a new vehicle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'No vehicles match this filter.',
        style: TextStyle(color: AppColors.muted),
      ),
    );
  }
}

class _GarageLoading extends StatelessWidget {
  const _GarageLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        children: List.generate(
          2,
          (index) => Container(
            height: 236,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
      ),
    );
  }
}

class _GarageError extends StatelessWidget {
  const _GarageError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 44,
            color: AppColors.muted,
          ),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.foreground, this.background);

  final Color foreground;
  final Color background;

  factory _StatusStyle.from(String? status) {
    return switch (status) {
      'VALID' => const _StatusStyle(AppColors.forest700, Color(0xFFDDF2E8)),
      'EXPIRING_SOON' => const _StatusStyle(
        AppColors.orangeDark,
        Color(0xFFFFE9E1),
      ),
      'EXPIRED' => const _StatusStyle(AppColors.danger, Color(0xFFFFE3E1)),
      _ => const _StatusStyle(Color(0xFF53615B), Color(0xFFEDF0EF)),
    };
  }
}
